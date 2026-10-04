//
//  Scheduler.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

protocol ScheduledTask {
    func cancel()
}

/// Abstraksi penjadwalan satu kali eksekusi, supaya `DeviceMonitor` tidak bergantung pada `Timer`.
protocol Scheduling {
    func schedule(after interval: TimeInterval, _ action: @escaping () -> Void) -> ScheduledTask
}

extension Timer: ScheduledTask {
    func cancel() { invalidate() }
}

/// Menjadwalkan lewat `Timer` di main run loop.
struct RunLoopScheduler: Scheduling {
    func schedule(after interval: TimeInterval, _ action: @escaping () -> Void) -> ScheduledTask {
        // Timer ditambahkan ke `RunLoop.main`, sehingga `action` selalu berjalan di main thread.
        let action = UncheckedSendable(action)
        let timer = Timer(timeInterval: interval, repeats: false) { _ in action.value() }
        // `.common` supaya timer tetap jalan ketika menu sedang terbuka (event tracking mode).
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }
}
