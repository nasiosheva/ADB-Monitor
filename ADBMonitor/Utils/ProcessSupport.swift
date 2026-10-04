//
//  ProcessSupport.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

/// Mengumpulkan data dari `FileHandle` lewat `readabilityHandler`.
/// Handler hanya memegang referensi weak ke collector sehingga tidak ada retain cycle.
final class ProcessStreamCollector: @unchecked Sendable {  // seluruh state mutable dilindungi `lock`
    private let lock = NSLock()
    private var buffer = Data()
    private let eof = DispatchSemaphore(value: 0)
    private let handle: FileHandle

    init(handle: FileHandle) {
        self.handle = handle
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

    /// Menunggu EOF sampai `deadline` lalu melepas handler, apa pun hasilnya.
    func finish(until deadline: DispatchTime) -> String {
        _ = eof.wait(timeout: deadline)
        handle.readabilityHandler = nil
        lock.lock(); defer { lock.unlock() }
        return String(decoding: buffer, as: UTF8.self)
    }

    private func append(_ chunk: Data) {
        lock.lock(); defer { lock.unlock() }
        buffer.append(chunk)
    }
}

/// Menghentikan `Process` yang melewati batas waktu. Hanya memegang referensi weak ke proses.
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
