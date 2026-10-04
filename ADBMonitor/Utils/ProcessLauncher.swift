//
//  ProcessLauncher.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

/// A process started by `ProcessLaunching`, so its owner can ask it to stop.
@MainActor
protocol RunningProcess: AnyObject {
    /// Sends SIGINT, like Ctrl+C: tools such as `scrcpy` finish their file and exit.
    func interrupt()
    /// Sends SIGTERM; for a process that did not react to `interrupt`.
    func terminate()
}

/// Starts a process that keeps running (for example a `scrcpy` window) and reports when it ends.
/// `ProcessRunning` is for commands that finish; this is for tools that stay open.
@MainActor
protocol ProcessLaunching: AnyObject {
    /// Starts the process and returns right away. `onExit` is called on the main actor when it ends,
    /// with the exit code and the last part of its error output.
    @discardableResult
    func launch(executable: String,
                arguments: [String],
                environment: [String: String],
                onExit: @escaping @MainActor @Sendable (_ exitCode: Int32, _ errorOutput: String) -> Void)
        throws -> RunningProcess
}

@MainActor
final class SystemRunningProcess: RunningProcess {
    private let process: Process

    init(_ process: Process) { self.process = process }

    func interrupt() {
        if process.isRunning { process.interrupt() }
    }

    func terminate() {
        if process.isRunning { process.terminate() }
    }
}

@MainActor
final class ProcessLauncher: ProcessLaunching {

    /// Only the newest bytes of the error output are kept.
    private static let errorOutputLimit = 4096
    /// A child that inherited the pipe (for example an adb server started by the tool) can keep it open.
    private static let drainTimeout: TimeInterval = 1

    private let fileManager: FileManager
    /// A running `Process` is held here until it ends.
    private var running: [ObjectIdentifier: Process] = [:]

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    @discardableResult
    func launch(executable: String,
                arguments: [String],
                environment: [String: String],
                onExit: @escaping @MainActor @Sendable (_ exitCode: Int32, _ errorOutput: String) -> Void)
        throws -> RunningProcess {
        guard fileManager.isRunnableFile(atPath: executable) else {
            throw ProcessError.executableNotFound(executable)
        }

        let outPipe = Pipe()
        let errPipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.environment = LaunchEnvironment.make(adding: environment)
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = outPipe
        process.standardError = errPipe

        // Both pipes must be read, or a chatty tool would block on a full pipe. Standard output is discarded.
        let outHandle = outPipe.fileHandleForReading
        outHandle.readabilityHandler = { handle in
            if handle.availableData.isEmpty { handle.readabilityHandler = nil }
        }
        let errors = ProcessStreamCollector(handle: errPipe.fileHandleForReading, keepingLast: Self.errorOutputLimit)

        let id = ObjectIdentifier(process)
        let drainTimeout = Self.drainTimeout   // read here: a static of this main-actor class cannot be read below
        process.terminationHandler = { [weak self] finished in
            let status = finished.terminationStatus
            // Waiting for the pipes to close can take a moment, so it is not done on this thread, which runs at
            // the quality of service of the launching (main) thread.
            DispatchQueue.global(qos: .utility).async { [weak self] in
                let text = errors.finish(until: .now() + drainTimeout)
                outHandle.readabilityHandler = nil
                Task { @MainActor in
                    self?.running[id] = nil
                    onExit(status, text)
                }
            }
        }

        do {
            try process.run()
        } catch {
            outHandle.readabilityHandler = nil
            _ = errors.finish(until: .now())
            throw ProcessError.launchFailed(error.localizedDescription)
        }
        running[id] = process
        return SystemRunningProcess(process)
    }
}
