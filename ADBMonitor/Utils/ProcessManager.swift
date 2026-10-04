//
//  ProcessManager.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

struct ProcessOutput {
    let stdout: String
    let stderr: String
    let exitCode: Int32
}

enum ProcessError: Error, Equatable {
    case executableNotFound(String)
    case launchFailed(String)
    case timedOut
}

/// Abstraksi eksekusi command supaya konsumen tidak bergantung pada `Process`.
protocol ProcessRunning {
    func run(executable: String,
             arguments: [String],
             timeout: TimeInterval,
             completion: @escaping (Result<ProcessOutput, ProcessError>) -> Void)
}

/// Menjalankan command di background queue dan mengirim hasilnya ke `completionQueue`.
///
/// Tidak ada state yang dipertahankan antar pemanggilan: setiap `Process`, `Pipe`, dan handler dibuat
/// per-run lalu dilepas sebelum completion dipanggil.
final class ProcessManager: ProcessRunning, @unchecked Sendable {  // properti hanya `let`; queue thread-safe

    /// Batas menunggu EOF setelah proses keluar; `adb` bisa meninggalkan daemon child yang memegang pipe.
    private static let drainTimeout: TimeInterval = 1

    /// Direktori tambahan untuk PATH karena aplikasi GUI tidak mewarisi PATH dari shell.
    private static let extraSearchPaths = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"]

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
        // `completion` dipanggil tepat sekali dan tidak diakses dari thread lain, jadi aman dibawa lewat queue.
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

        // Pipe dibaca secara asynchronous supaya output besar tidak membuat proses deadlock.
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

        let drainDeadline = DispatchTime.now() + Self.drainTimeout  // satu batas bersama untuk kedua stream
        let stdout = outCollector.finish(until: drainDeadline)
        let stderr = errCollector.finish(until: drainDeadline)

        if timeoutGuard.didFire { return .failure(.timedOut) }
        return .success(ProcessOutput(stdout: stdout, stderr: stderr, exitCode: process.terminationStatus))
    }

    private func makeProcess(executable: String, arguments: [String], stdout: Pipe, stderr: Pipe) -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.environment = launchEnvironment()
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = stdout
        process.standardError = stderr
        return process
    }

    private func launchEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let inheritedPath = environment["PATH"].map { [$0] } ?? []
        environment["PATH"] = (inheritedPath + Self.extraSearchPaths).joined(separator: ":")
        return environment
    }
}
