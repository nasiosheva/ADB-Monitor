//
//  Fakes.swift
//  ADBMonitorTests
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation
@testable import ADBMonitor

/// Records call order across fakes, to check the order of events.
final class CallLog {
    private(set) var entries: [String] = []
    func record(_ entry: String) { entries.append(entry) }
}

// MARK: - Services

struct StubPathProvider: ADBPathProviding {
    var adbPath: String?
}

final class StubLocator: ADBLocating {
    var result: String?
    private(set) var receivedCustomPaths: [String?] = []

    init(result: String?) { self.result = result }

    func locate(customPath: String?) -> String? {
        receivedCustomPaths.append(customPath)
        return result
    }
}

final class FakeProcessRunner: ProcessRunning {
    var result: Result<ProcessOutput, ProcessError>
    private(set) var calls: [(executable: String, arguments: [String], timeout: TimeInterval)] = []

    init(_ result: Result<ProcessOutput, ProcessError>) { self.result = result }

    func run(executable: String,
             arguments: [String],
             timeout: TimeInterval,
             completion: @escaping (Result<ProcessOutput, ProcessError>) -> Void) {
        calls.append((executable, arguments, timeout))
        completion(result)
    }
}

func output(_ stdout: String = "", stderr: String = "", exit: Int32 = 0) -> ProcessOutput {
    ProcessOutput(stdout: stdout, stderr: stderr, exitCode: exit)
}

/// An `ADBServicing` whose results the test controls. `listDevices` only finishes when the test calls `completeList`.
final class FakeADBService: ADBServicing {
    private(set) var pendingLists: [(Result<[ADBDevice], ADBError>) -> Void] = []
    private(set) var performCalls: [(action: PowerAction, serial: String)] = []
    var performResult: Result<Void, ADBError> = .success(())
    var log: CallLog?

    func listDevices(completion: @escaping (Result<[ADBDevice], ADBError>) -> Void) {
        pendingLists.append(completion)
    }

    func completeList(_ result: Result<[ADBDevice], ADBError>) {
        pendingLists.removeFirst()(result)
    }

    func perform(_ action: PowerAction, on serial: String, completion: @escaping (Result<Void, ADBError>) -> Void) {
        performCalls.append((action, serial))
        log?.record("perform")
        completion(performResult)
    }
}

final class FakeScheduledTask: ScheduledTask {
    private(set) var isCancelled = false
    func cancel() { isCancelled = true }
}

final class FakeScheduler: Scheduling {
    private(set) var scheduled: [(interval: TimeInterval, action: () -> Void, task: FakeScheduledTask)] = []

    func schedule(after interval: TimeInterval, _ action: @escaping () -> Void) -> ScheduledTask {
        let task = FakeScheduledTask()
        scheduled.append((interval, action, task))
        return task
    }

    /// Drops all stored closures, like a `Timer` that releases its closure after it has run.
    func reset() { scheduled.removeAll() }
}

struct StubInterval: RefreshIntervalProviding {
    var refreshInterval: TimeInterval
}

struct StubLanguage: LanguageProviding {
    var languagePreference: LanguagePreference
}

// MARK: - App layer (all @MainActor, following their protocols)

@MainActor
final class FakeMonitor: DeviceMonitoring {
    var onStatusChange: ((ADBStatus) -> Void)?
    var onWirelessChange: (([WirelessService]) -> Void)?
    var onFastbootChange: (([FastbootDevice]) -> Void)?
    var onPoll: (([ADBDevice]) -> Void)?
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var refreshCount = 0
    var log: CallLog?

    func start() { startCount += 1 }
    func stop() { stopCount += 1 }
    func refresh() {
        refreshCount += 1
        log?.record("refresh")
    }
}

@MainActor
final class FakeAlerts: AlertPresenting {
    var confirmAnswer = true
    private(set) var confirmations: [(action: PowerAction, device: ADBDevice)] = []
    private(set) var failures: [(action: PowerAction, device: ADBDevice, error: ADBError)] = []
    /// Answer for the general confirmation `confirm(title:message:button:)`.
    var generalConfirmAnswer = true
    private(set) var generalConfirmations: [(title: String, message: String, button: String)] = []
    private(set) var errors: [(title: String, message: String)] = []
    private(set) var infos: [(title: String, message: String)] = []
    var log: CallLog?

    func confirm(_ action: PowerAction, on device: ADBDevice) -> Bool {
        confirmations.append((action, device))
        log?.record("confirm")
        return confirmAnswer
    }

    func confirm(title: String, message: String, button: String) -> Bool {
        generalConfirmations.append((title, message, button))
        log?.record("confirm")
        return generalConfirmAnswer
    }

    func showFailure(of action: PowerAction, on device: ADBDevice, error: ADBError) {
        failures.append((action, device, error))
        log?.record("failure")
    }

    func showError(title: String, message: String) {
        errors.append((title, message))
        log?.record("error")
    }

    func showInfo(title: String, message: String) {
        infos.append((title, message))
        log?.record("info")
    }
}

@MainActor
final class FakeStatusBar: StatusBarRendering {
    private(set) var rendered: [ADBStatus?] = []
    private(set) var renderedWireless: [[WirelessService]] = []
    func render(_ status: ADBStatus?) { rendered.append(status) }
    func renderWireless(_ services: [WirelessService]) { renderedWireless.append(services) }
    private(set) var renderedFastboot: [[FastbootDevice]] = []
    private(set) var renderedDetails: [[String: DeviceDetails]] = []
    func renderFastboot(_ devices: [FastbootDevice]) { renderedFastboot.append(devices) }
    func renderDetails(_ details: [String: DeviceDetails]) { renderedDetails.append(details) }
    private(set) var renderedRecording: [Set<String>] = []
    func renderRecording(_ serials: Set<String>) { renderedRecording.append(serials) }
}

@MainActor
final class FakePreferencesWindow: PreferencesPresenting {
    private(set) var presentCount = 0
    func present() { presentCount += 1 }
}

@MainActor
final class RecordingMenuHandler: StatusMenuActionHandling, RecordingStateReporting {
    private(set) var refreshCount = 0
    private(set) var preferencesCount = 0
    private(set) var quitCount = 0
    private(set) var powerRequests: [(action: PowerAction, device: ADBDevice)] = []

    func statusMenuDidRequestRefresh() { refreshCount += 1 }
    func statusMenuDidRequestPreferences() { preferencesCount += 1 }
    func statusMenuDidRequestQuit() { quitCount += 1 }
    func statusMenu(didRequest action: PowerAction, on device: ADBDevice) { powerRequests.append((action, device)) }

    private(set) var developerOptionsRequests: [ADBDevice] = []
    func statusMenu(didRequestOpenDeveloperOptionsOn device: ADBDevice) { developerOptionsRequests.append(device) }

    // Screen
    var onRecordingChange: ((Set<String>) -> Void)?
    private(set) var recordingToggles: [ADBDevice] = []
    func statusMenu(didRequestToggleRecordingOf device: ADBDevice) { recordingToggles.append(device) }
    private(set) var screenshotRequests: [ADBDevice] = []
    private(set) var mirrorRequests: [ADBDevice] = []
    func statusMenu(didRequestScreenshotOf device: ADBDevice) { screenshotRequests.append(device) }
    func statusMenu(didRequestMirror device: ADBDevice) { mirrorRequests.append(device) }

    // Tools
    private(set) var restartServerCount = 0
    private(set) var fastbootReboots: [FastbootDevice] = []
    func statusMenuDidRequestRestartServer() { restartServerCount += 1 }
    func statusMenu(didRequestRebootFastbootDevice device: FastbootDevice) { fastbootReboots.append(device) }

    // Wi-Fi
    private(set) var connectAddresses: [String] = []
    private(set) var connectByAddressCount = 0
    private(set) var pairingRequests: [String?] = []
    private(set) var qrPairingRequestCount = 0
    private(set) var disconnects: [ADBDevice] = []
    private(set) var switches: [ADBDevice] = []

    func statusMenu(didRequestConnectTo address: String) { connectAddresses.append(address) }
    func statusMenuDidRequestConnectByAddress() { connectByAddressCount += 1 }
    func statusMenu(didRequestPairingWith address: String?) { pairingRequests.append(address) }
    func statusMenuDidRequestPairWithQR() { qrPairingRequestCount += 1 }
    func statusMenu(didRequestDisconnect device: ADBDevice) { disconnects.append(device) }
    func statusMenu(didRequestSwitchToWireless device: ADBDevice) { switches.append(device) }
}

// MARK: - Device settings

final class FakeSettingsOpener: DeviceSettingsOpening {
    var result: Result<Void, ADBError> = .success(())
    private(set) var serials: [String] = []
    var log: CallLog?

    func openDeveloperOptions(on serial: String, completion: @escaping (Result<Void, ADBError>) -> Void) {
        serials.append(serial)
        log?.record("developerOptions")
        completion(result)
    }
}

// MARK: - Wi-Fi

struct StubDiscoverySettings: WirelessDiscoveryProviding {
    var wirelessDiscoveryEnabled: Bool
}

final class MutableDiscoverySettings: WirelessDiscoveryProviding {
    var wirelessDiscoveryEnabled: Bool
    init(_ enabled: Bool) { wirelessDiscoveryEnabled = enabled }
}

/// `discoverWireless` only finishes when the test calls `complete`.
final class FakeWirelessDiscovery: WirelessDiscovering {
    private(set) var pending: [(Result<[WirelessService], ADBError>) -> Void] = []

    func discoverWireless(completion: @escaping (Result<[WirelessService], ADBError>) -> Void) {
        pending.append(completion)
    }

    func complete(_ result: Result<[WirelessService], ADBError>) {
        pending.removeFirst()(result)
    }
}

final class FakeWirelessController: WirelessControlling {
    var connectResults: [Result<Void, ADBError>] = []   // used in order; empty = success
    var pairResult: Result<Void, ADBError> = .success(())
    var disconnectResult: Result<Void, ADBError> = .success(())
    var wifiResult: Result<String, ADBError> = .success("192.168.1.23")
    var tcpipResult: Result<Void, ADBError> = .success(())
    var log: CallLog?

    private(set) var connectCalls: [String] = []
    private(set) var pairCalls: [(address: String, code: String)] = []
    private(set) var disconnectCalls: [String] = []
    private(set) var wifiCalls: [String] = []
    private(set) var tcpipCalls: [(serial: String, port: Int)] = []

    func connect(to address: String, completion: @escaping (Result<Void, ADBError>) -> Void) {
        connectCalls.append(address)
        log?.record("connect")
        completion(connectResults.isEmpty ? .success(()) : connectResults.removeFirst())
    }

    func disconnect(serial: String, completion: @escaping (Result<Void, ADBError>) -> Void) {
        disconnectCalls.append(serial)
        log?.record("disconnect")
        completion(disconnectResult)
    }

    private(set) var qrPairCalls: [(address: String, password: String)] = []

    func pairWithQR(address: String, password: String, completion: @escaping (Result<Void, ADBError>) -> Void) {
        qrPairCalls.append((address, password))
        log?.record("pairWithQR")
        completion(pairResult)
    }

    func pair(address: String, code: String, completion: @escaping (Result<Void, ADBError>) -> Void) {
        pairCalls.append((address, code))
        log?.record("pair")
        completion(pairResult)
    }

    func wifiAddress(of serial: String, completion: @escaping (Result<String, ADBError>) -> Void) {
        wifiCalls.append(serial)
        log?.record("wifiAddress")
        completion(wifiResult)
    }

    func enableTCPIP(on serial: String, port: Int, completion: @escaping (Result<Void, ADBError>) -> Void) {
        tcpipCalls.append((serial, port))
        log?.record("tcpip")
        completion(tcpipResult)
    }
}

@MainActor
final class FakeWirelessSwitcher: WirelessSwitching {
    var result: Result<String, ADBError> = .success("192.168.1.23:5555")
    private(set) var serials: [String] = []
    var log: CallLog?

    func switchToWireless(serial: String, completion: @escaping (Result<String, ADBError>) -> Void) {
        serials.append(serial)
        log?.record("switch")
        completion(result)
    }
}

@MainActor
final class FakeWirelessPrompter: WirelessPrompting {
    var connectAnswer: String?
    var pairAnswer: (address: String, code: String)?
    private(set) var connectAsked = 0
    private(set) var pairingPrefills: [String?] = []

    func askConnectAddress() -> String? {
        connectAsked += 1
        return connectAnswer
    }

    func askPairing(prefilledAddress: String?) -> (address: String, code: String)? {
        pairingPrefills.append(prefilledAddress)
        return pairAnswer
    }
}

/// Records calls made through `WirelessActionHandling`, to check forwarding from `AppCoordinator`.
@MainActor
final class RecordingWirelessHandler: WirelessActionHandling {
    private(set) var calls: [String] = []

    func statusMenu(didRequestConnectTo address: String) { calls.append("connect:\(address)") }
    func statusMenuDidRequestConnectByAddress() { calls.append("connectByAddress") }
    func statusMenu(didRequestPairingWith address: String?) { calls.append("pair:\(address ?? "nil")") }
    func statusMenuDidRequestPairWithQR() { calls.append("pairWithQR") }
    func statusMenu(didRequestDisconnect device: ADBDevice) { calls.append("disconnect:\(device.serial)") }
    func statusMenu(didRequestSwitchToWireless device: ADBDevice) { calls.append("switch:\(device.serial)") }
}

/// A `ProcessRunning` that returns results in sequence (one per call) and records its arguments.
final class SequencedProcessRunner: ProcessRunning {
    private var results: [Result<ProcessOutput, ProcessError>]
    private(set) var calls: [[String]] = []

    init(_ results: [Result<ProcessOutput, ProcessError>]) { self.results = results }

    func run(executable: String,
             arguments: [String],
             timeout: TimeInterval,
             completion: @escaping (Result<ProcessOutput, ProcessError>) -> Void) {
        calls.append(arguments)
        let empty: Result<ProcessOutput, ProcessError> = .success(ProcessOutput(stdout: "", stderr: "", exitCode: 0))
        completion(results.isEmpty ? empty : results.removeFirst())
    }
}

// MARK: - Sample data

enum Sample {
    static func device(_ serial: String = "SER1",
                       state: ADBDevice.State = .device,
                       model: String? = "Pixel 3a",
                       usbPath: String? = "1-1") -> ADBDevice {
        ADBDevice(serial: serial, state: state, model: model, product: "sargo", deviceName: "sargo",
                  transportID: "2", usbPath: usbPath)
    }
}

/// Holds the callbacks of `start` so a test decides when (and how) the QR wait ends.
@MainActor
final class FakeQRPairer: WirelessQRPairing {
    private(set) var started: [PairingQRCredentials] = []
    private(set) var cancelCount = 0
    private var onPairing: (() -> Void)?
    private var completion: ((Result<String, ADBError>) -> Void)?

    func start(credentials: PairingQRCredentials,
               onPairing: @escaping () -> Void,
               completion: @escaping (Result<String, ADBError>) -> Void) {
        started.append(credentials)
        self.onPairing = onPairing
        self.completion = completion
    }

    func cancel() { cancelCount += 1 }

    func simulatePhoneFound() { onPairing?() }
    func finish(_ result: Result<String, ADBError>) { completion?(result) }
}

@MainActor
final class FakePairingQRWindow: PairingQRPresenting {
    private(set) var shownPayloads: [String] = []
    private(set) var pairingInProgressCount = 0
    private(set) var bringToFrontCount = 0
    private(set) var dismissCount = 0
    var log: CallLog?
    private var onCancel: (() -> Void)?

    func show(payload: String, onCancel: @escaping () -> Void) {
        shownPayloads.append(payload)
        self.onCancel = onCancel
    }

    func bringToFront() { bringToFrontCount += 1 }
    func showPairingInProgress() { pairingInProgressCount += 1 }

    func dismiss() {
        dismissCount += 1
        log?.record("dismiss")
        onCancel = nil
    }

    /// The user closed the window or pressed Cancel.
    func simulateUserCancel() {
        let cancel = onCancel
        onCancel = nil
        cancel?()
    }
}

// MARK: - Tools, fastboot, and device details

/// Records what would be copied, so tests never touch the real clipboard of the user.
@MainActor
final class RecordingClipboard: ClipboardWriting {
    private(set) var copied: [String] = []
    func copy(_ text: String) { copied.append(text) }
}

final class FakeServerController: ADBServerControlling {
    var result: Result<Void, ADBError> = .success(())
    private(set) var restartCount = 0
    var log: CallLog?

    func restartServer(completion: @escaping (Result<Void, ADBError>) -> Void) {
        restartCount += 1
        log?.record("restartServer")
        completion(result)
    }
}

final class FakeFastbootService: FastbootListing, FastbootControlling {
    var listResult: Result<[FastbootDevice], ADBError> = .success([])
    var rebootResult: Result<Void, ADBError> = .success(())
    private(set) var listCount = 0
    private(set) var rebootedSerials: [String] = []
    var log: CallLog?

    func listFastboot(completion: @escaping (Result<[FastbootDevice], ADBError>) -> Void) {
        listCount += 1
        completion(listResult)
    }

    func reboot(serial: String, completion: @escaping (Result<Void, ADBError>) -> Void) {
        rebootedSerials.append(serial)
        log?.record("fastbootReboot")
        completion(rebootResult)
    }
}

/// `readDetails` only finishes when the test calls `complete`, so tests can check the in-flight state.
final class FakeDetailsReader: DeviceDetailsReading {
    private(set) var requested: [String] = []
    private var pending: [(Result<DeviceDetails, ADBError>) -> Void] = []

    func readDetails(of serial: String, completion: @escaping (Result<DeviceDetails, ADBError>) -> Void) {
        requested.append(serial)
        pending.append(completion)
    }

    func complete(_ result: Result<DeviceDetails, ADBError>) {
        pending.removeFirst()(result)
    }
}

@MainActor
final class FakeDetailsTracker: DeviceDetailsTracking {
    var onChange: (([String: DeviceDetails]) -> Void)?
    private(set) var tracked: [[ADBDevice]] = []
    func track(devices: [ADBDevice]) { tracked.append(devices) }
}

// MARK: - Screen tools and notifications

final class FakeScreenshotService: ScreenshotTaking {
    private(set) var requests: [(serial: String, destination: URL)] = []
    private var pending: [(Result<Void, ADBError>) -> Void] = []

    func takeScreenshot(of serial: String,
                        to destination: URL,
                        completion: @escaping (Result<Void, ADBError>) -> Void) {
        requests.append((serial, destination))
        pending.append(completion)
    }

    func complete(_ result: Result<Void, ADBError>) { pending.removeFirst()(result) }
}

@MainActor
final class FakeMirror: ScreenMirroring {
    var result: Result<Void, ADBError> = .success(())
    private(set) var serials: [String] = []

    func mirror(serial: String, completion: @escaping (Result<Void, ADBError>) -> Void) {
        serials.append(serial)
        completion(result)
    }
}

@MainActor
final class FakeFileRevealer: FileRevealing {
    private(set) var revealed: [URL] = []
    func reveal(_ url: URL) { revealed.append(url) }
}

@MainActor
final class FakeRunningProcess: RunningProcess {
    private(set) var interrupts = 0
    private(set) var terminations = 0
    func interrupt() { interrupts += 1 }
    func terminate() { terminations += 1 }
}

@MainActor
final class FakeProcessLauncher: ProcessLaunching {
    struct Launch {
        let executable: String
        let arguments: [String]
        let environment: [String: String]
        let process: FakeRunningProcess
        let onExit: @MainActor @Sendable (Int32, String) -> Void
    }

    private(set) var launches: [Launch] = []
    /// When set, `launch` throws it instead of starting anything.
    var error: Error?

    func launch(executable: String,
                arguments: [String],
                environment: [String: String],
                onExit: @escaping @MainActor @Sendable (Int32, String) -> Void) throws -> RunningProcess {
        if let error = error { throw error }
        let process = FakeRunningProcess()
        launches.append(Launch(executable: executable, arguments: arguments, environment: environment,
                               process: process, onExit: onExit))
        return process
    }
}

struct StubNotificationSettings: DeviceNotificationProviding {
    var deviceNotificationsEnabled: Bool
}

@MainActor
final class MutableNotificationSettings: DeviceNotificationProviding {
    var deviceNotificationsEnabled: Bool
    init(_ enabled: Bool) { deviceNotificationsEnabled = enabled }
}

@MainActor
final class FakeDeviceNotifier: DeviceNotifying {
    private(set) var prepareCount = 0
    private(set) var notified: [DeviceChange] = []
    func prepare() { prepareCount += 1 }
    func notify(_ change: DeviceChange) { notified.append(change) }
}

@MainActor
final class FakeChangeTracker: DeviceChangeTracking {
    private(set) var tracked: [[ADBDevice]] = []
    func track(devices: [ADBDevice]) { tracked.append(devices) }
}

@MainActor
final class FakeRecorder: ScreenRecording {
    private(set) var started: [(serial: String, destination: URL)] = []
    private(set) var stopped: [String] = []
    private var completions: [String: (Result<Void, ADBError>) -> Void] = [:]
    /// When set, `start` fails right away with this error.
    var startError: ADBError?

    func isRecording(serial: String) -> Bool { completions[serial] != nil }

    func start(serial: String, to destination: URL, completion: @escaping (Result<Void, ADBError>) -> Void) {
        if let error = startError {
            completion(.failure(error))
            return
        }
        started.append((serial, destination))
        completions[serial] = completion
    }

    func stop(serial: String) { stopped.append(serial) }

    /// Ends the recording like `ScrcpyRecorder` does when the process exits.
    func finish(serial: String, _ result: Result<Void, ADBError>) {
        completions.removeValue(forKey: serial)?(result)
    }
}
