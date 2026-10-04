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
    private(set) var errors: [(title: String, message: String)] = []
    private(set) var infos: [(title: String, message: String)] = []
    var log: CallLog?

    func confirm(_ action: PowerAction, on device: ADBDevice) -> Bool {
        confirmations.append((action, device))
        log?.record("confirm")
        return confirmAnswer
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
}

@MainActor
final class FakePreferencesWindow: PreferencesPresenting {
    private(set) var presentCount = 0
    func present() { presentCount += 1 }
}

@MainActor
final class RecordingMenuHandler: StatusMenuActionHandling {
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

    // Wi-Fi
    private(set) var connectAddresses: [String] = []
    private(set) var connectByAddressCount = 0
    private(set) var pairingRequests: [String?] = []
    private(set) var disconnects: [ADBDevice] = []
    private(set) var switches: [ADBDevice] = []

    func statusMenu(didRequestConnectTo address: String) { connectAddresses.append(address) }
    func statusMenuDidRequestConnectByAddress() { connectByAddressCount += 1 }
    func statusMenu(didRequestPairingWith address: String?) { pairingRequests.append(address) }
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
