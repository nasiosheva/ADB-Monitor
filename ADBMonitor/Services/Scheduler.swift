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

/// Abstraction for scheduling a one-shot execution, so `DeviceMonitor` does not depend on `Timer`.
protocol Scheduling {
    func schedule(after interval: TimeInterval, _ action: @escaping () -> Void) -> ScheduledTask
}

extension Timer: ScheduledTask {
    func cancel() { invalidate() }
}

/// Schedules through a `Timer` on the main run loop.
struct RunLoopScheduler: Scheduling {
    func schedule(after interval: TimeInterval, _ action: @escaping () -> Void) -> ScheduledTask {
        // The timer is added to `RunLoop.main`, so `action` always runs on the main thread.
        let action = UncheckedSendable(action)
        let timer = Timer(timeInterval: interval, repeats: false) { _ in action.value() }
        // `.common` so the timer keeps firing while a menu is open (event tracking mode).
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }
}
