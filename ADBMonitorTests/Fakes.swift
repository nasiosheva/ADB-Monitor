//
//  Fakes.swift
//  ADBMonitorTests
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation
@testable import ADBMonitor

/// Mencatat urutan panggilan lintas fake, untuk memeriksa urutan kejadian.
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

/// `ADBServicing` yang hasilnya dikendalikan tes. `listDevices` baru selesai saat tes memanggil `completeList`.
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
}

struct StubInterval: RefreshIntervalProviding {
    var refreshInterval: TimeInterval
}

struct StubLanguage: LanguageProviding {
    var languagePreference: LanguagePreference
}

// MARK: - App layer (semua @MainActor, mengikuti protokolnya)

@MainActor
final class FakeMonitor: DeviceMonitoring {
    var onStatusChange: ((ADBStatus) -> Void)?
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
}

@MainActor
final class FakeStatusBar: StatusBarRendering {
    private(set) var rendered: [ADBStatus?] = []
    func render(_ status: ADBStatus?) { rendered.append(status) }
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
}

// MARK: - Contoh data

enum Sample {
    static func device(_ serial: String = "SER1",
                       state: ADBDevice.State = .device,
                       model: String? = "Pixel 3a",
                       usbPath: String? = "1-1") -> ADBDevice {
        ADBDevice(serial: serial, state: state, model: model, product: "sargo", deviceName: "sargo",
                  transportID: "2", usbPath: usbPath)
    }
}
