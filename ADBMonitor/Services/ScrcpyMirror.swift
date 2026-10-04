//
//  ScrcpyMirror.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

/// Opens a live view of a device screen.
@MainActor
protocol ScreenMirroring: AnyObject {
    /// Starts mirroring. The result is the outcome of the first moments: a failure when the tool is missing or
    /// quits right away (for example the device refuses), a success once it has stayed up for a short while.
    /// A device that is already being mirrored is left alone and reported as a success.
    func mirror(serial: String, completion: @escaping (Result<Void, ADBError>) -> Void)
}

/// Finds `scrcpy` and the `adb` it must use. `scrcpy` finds `adb` through the `ADB` environment variable, because a
/// GUI app does not have the shell `PATH` that would lead to it.
struct ScrcpyResolver {
    let scrcpyLocator: ADBLocating
    let adbLocator: ADBLocating
    let pathProvider: ADBPathProviding

    struct Tool {
        let executable: String
        let environment: [String: String]
    }

    func resolve() -> Result<Tool, ADBError> {
        guard let scrcpy = scrcpyLocator.locate(customPath: nil) else { return .failure(.toolNotFound("scrcpy")) }
        let customPath = pathProvider.adbPath
        guard let adb = adbLocator.locate(customPath: customPath) else {
            return .failure(.notFound(customPath: customPath))
        }
        return .success(Tool(executable: scrcpy, environment: ["ADB": adb]))
    }

    /// What a failed `ProcessLaunching.launch` means for the user.
    static func error(forLaunchFailure error: Error) -> ADBError {
        switch error {
        case ProcessError.executableNotFound: return .toolNotFound("scrcpy")
        case ProcessError.launchFailed(let reason): return .launchFailed(reason)
        default: return .launchFailed(error.localizedDescription)
        }
    }
}

/// Mirrors with `scrcpy`, which draws its own window. `scrcpy` finds `adb` through the `ADB` environment
/// variable, because a GUI app does not have the shell `PATH` that would lead to it.
@MainActor
final class ScrcpyMirror: ScreenMirroring {

    private let resolver: ScrcpyResolver
    private let launcher: ProcessLaunching
    private let scheduler: Scheduling
    private let startupGrace: TimeInterval
    private var active: Set<String> = []

    init(scrcpyLocator: ADBLocating,
         adbLocator: ADBLocating,
         pathProvider: ADBPathProviding,
         launcher: ProcessLaunching,
         scheduler: Scheduling,
         startupGrace: TimeInterval = 3) {
        self.resolver = ScrcpyResolver(scrcpyLocator: scrcpyLocator, adbLocator: adbLocator,
                                       pathProvider: pathProvider)
        self.launcher = launcher
        self.scheduler = scheduler
        self.startupGrace = startupGrace
    }

    func mirror(serial: String, completion: @escaping (Result<Void, ADBError>) -> Void) {
        guard !serial.trimmed.isEmpty else {
            completion(.failure(.commandFailed("Missing serial number.")))
            return
        }
        guard !active.contains(serial) else {
            completion(.success(()))
            return
        }
        let tool: ScrcpyResolver.Tool
        switch resolver.resolve() {
        case .success(let resolved): tool = resolved
        case .failure(let error):
            completion(.failure(error))
            return
        }

        let report = StartupReport(completion)
        do {
            try launcher.launch(executable: tool.executable, arguments: ["-s", serial],
                                environment: tool.environment) {
                [weak self] exitCode, errorOutput in
                self?.active.remove(serial)
                report.finish(exitCode == 0 ? .success(()) : .failure(Self.failure(exitCode, errorOutput)))
            }
        } catch {
            completion(.failure(ScrcpyResolver.error(forLaunchFailure: error)))
            return
        }
        active.insert(serial)
        report.timer = scheduler.schedule(after: startupGrace) { report.finish(.success(())) }
    }

    /// `scrcpy` prints its problems as `ERROR: …` lines on stderr, and one problem can span several lines (for
    /// example "Could not find ADB device X:" followed by the devices it did find), so the first few are all kept.
    static func failure(_ exitCode: Int32, _ errorOutput: String) -> ADBError {
        let lines = errorOutput.split(whereSeparator: \.isNewline).map { $0.trimmed }.filter { !$0.isEmpty }
        let errors = lines.filter { $0.hasPrefix("ERROR") }.prefix(5)
        let message = errors.isEmpty ? lines.last : errors.joined(separator: "\n")
        return .commandFailed(message ?? "scrcpy exited with code \(exitCode).")
    }

    /// Reports the outcome once: either the process ended early, or the startup time passed without it ending.
    @MainActor
    private final class StartupReport {
        private var completion: ((Result<Void, ADBError>) -> Void)?
        var timer: ScheduledTask?

        init(_ completion: @escaping (Result<Void, ADBError>) -> Void) {
            self.completion = completion
        }

        func finish(_ result: Result<Void, ADBError>) {
            guard let completion = completion else { return }
            self.completion = nil
            timer?.cancel()
            timer = nil
            completion(result)
        }
    }
}
