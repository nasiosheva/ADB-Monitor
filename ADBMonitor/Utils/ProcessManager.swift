//
//  ProcessManager.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

struct ProcessOutput: Equatable {
    let stdout: String
    let stderr: String
    let exitCode: Int32
}

enum ProcessError: Error, Equatable {
    case executableNotFound(String)
    case launchFailed(String)
    case timedOut
}

/// Abstraction of command execution so consumers do not depend on `Process`.
protocol ProcessRunning {
    func run(executable: String,
             arguments: [String],
             timeout: TimeInterval,
             completion: @escaping (Result<ProcessOutput, ProcessError>) -> Void)
}

/// Runs a command on a background queue and delivers the result to `completionQueue`.
///
/// No state is kept between calls: every `Process`, `Pipe`, and handler is created per run
/// and released before the completion is called.
final class ProcessManager: ProcessRunning, @unchecked Sendable {  // only `let` properties; the queue is thread-safe

    /// Limit for waiting on EOF after the process exits; `adb` can leave a daemon child that holds the pipe.
    private static let drainTimeout: TimeInterval = 1

    private let workQueue = DispatchQueue(label: "ADBMonitor.ProcessManager", qos: .utility, attributes: .concurrent)
    private let completionQueue: DispatchQueue
    private let fileManager: FileManager

    init(completionQueue: DispatchQueue = .main, fileManager: FileManager = .default) {
        self.completionQueue = completionQueue
        self.fileManager = fileManager
    }

    func run(executable: String,
             arguments: [String],
             timeout: TimeInterval,
             completion: @escaping (Result<ProcessOutput, ProcessError>) -> Void) {
        // `completion` is called once and not used from other threads, so it is safe to carry across the queue.
        let completion = UncheckedSendable(completion)
        workQueue.async { [self] in
            let result = execute(executable: executable, arguments: arguments, timeout: timeout)
            completionQueue.async { completion.value(result) }
        }
    }

    // MARK: - Execution

    private func execute(executable: String,
                         arguments: [String],
                         timeout: TimeInterval) -> Result<ProcessOutput, ProcessError> {
        guard fileManager.isRunnableFile(atPath: executable) else {
            return .failure(.executableNotFound(executable))
        }

        let outPipe = Pipe()
        let errPipe = Pipe()
        let process = makeProcess(executable: executable, arguments: arguments, stdout: outPipe, stderr: errPipe)

        // Pipes are read asynchronously so large output cannot deadlock the process.
        let outCollector = ProcessStreamCollector(handle: outPipe.fileHandleForReading)
        let errCollector = ProcessStreamCollector(handle: errPipe.fileHandleForReading)

        do {
            try process.run()
        } catch {
            _ = outCollector.finish(until: .now())
            _ = errCollector.finish(until: .now())
            return .failure(.launchFailed(error.localizedDescription))
        }

        let timeoutGuard = ProcessTimeout(process: process, after: timeout, on: workQueue)
        process.waitUntilExit()
        timeoutGuard.cancel()

        let drainDeadline = DispatchTime.now() + Self.drainTimeout  // one shared deadline for both streams
        let stdout = outCollector.finish(until: drainDeadline)
        let stderr = errCollector.finish(until: drainDeadline)

        if timeoutGuard.didFire { return .failure(.timedOut) }
        return .success(ProcessOutput(stdout: stdout, stderr: stderr, exitCode: process.terminationStatus))
    }

    private func makeProcess(executable: String, arguments: [String], stdout: Pipe, stderr: Pipe) -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.environment = LaunchEnvironment.make()
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = stdout
        process.standardError = stderr
        return process
    }
}
