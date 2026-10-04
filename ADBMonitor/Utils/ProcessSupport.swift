//
//  ProcessSupport.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

/// Collects data from a `FileHandle` through `readabilityHandler`.
/// The handler only holds a weak reference to the collector, so there is no retain cycle.
/// With `keepingLast`, only the newest bytes are kept, so a process that writes for hours cannot grow the buffer.
final class ProcessStreamCollector: @unchecked Sendable {  // all mutable state is protected by `lock`
    private let lock = NSLock()
    private var buffer = Data()
    private let eof = DispatchSemaphore(value: 0)
    private let handle: FileHandle
    private let limit: Int?

    init(handle: FileHandle, keepingLast limit: Int? = nil) {
        self.handle = handle
        self.limit = limit
        handle.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            if chunk.isEmpty {
                handle.readabilityHandler = nil
                self?.eof.signal()
            } else {
                self?.append(chunk)
            }
        }
    }

    /// Waits for EOF until `deadline`, then removes the handler, whatever the outcome.
    func finish(until deadline: DispatchTime) -> String {
        _ = eof.wait(timeout: deadline)
        handle.readabilityHandler = nil
        lock.lock(); defer { lock.unlock() }
        return String(decoding: buffer, as: UTF8.self)
    }

    private func append(_ chunk: Data) {
        lock.lock(); defer { lock.unlock() }
        buffer.append(chunk)
        if let limit = limit, buffer.count > limit {
            buffer.removeFirst(buffer.count - limit)
        }
    }
}

/// The environment for child processes. A GUI app does not inherit the `PATH` of the shell, so common
/// install directories are appended.
enum LaunchEnvironment {
    static let extraSearchPaths = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"]

    static func make(adding extra: [String: String] = [:]) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let inheritedPath = environment["PATH"].map { [$0] } ?? []
        environment["PATH"] = (inheritedPath + extraSearchPaths).joined(separator: ":")
        return environment.merging(extra) { _, new in new }
    }
}

/// Stops a `Process` that exceeds its time limit. Only holds a weak reference to the process.
final class ProcessTimeout {
    private let lock = NSLock()
    private var fired = false
    private var workItem: DispatchWorkItem?

    init(process: Process, after seconds: TimeInterval, on queue: DispatchQueue) {
        let item = DispatchWorkItem { [weak self, weak process] in
            guard let process = process, process.isRunning else { return }
            self?.markFired()
            process.terminate()
        }
        workItem = item
        queue.asyncAfter(deadline: .now() + seconds, execute: item)
    }

    var didFire: Bool {
        lock.lock(); defer { lock.unlock() }
        return fired
    }

    func cancel() {
        workItem?.cancel()
        workItem = nil
    }

    private func markFired() {
        lock.lock(); defer { lock.unlock() }
        fired = true
    }
}
