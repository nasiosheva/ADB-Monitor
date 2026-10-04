//
//  DeviceDetailsTracker.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

@MainActor
protocol DeviceDetailsTracking: AnyObject {
    /// Called when the known details change (a device got details, or a device with details went away).
    var onChange: (([String: DeviceDetails]) -> Void)? { get set }
    /// Reads the details of devices that need it. Called after every poll with the devices adb listed.
    func track(devices: [ADBDevice])
}

/// Keeps the details (Android version, battery) of connected devices, keyed by serial.
///
/// A device is read when it first appears in the `device` state and then at most once per `refreshInterval`,
/// so the battery level stays reasonably fresh without adding an adb command to every poll. A failed read is
/// not retried before the interval passes either, so a device that cannot answer is not asked every 3 seconds.
@MainActor
final class DeviceDetailsTracker: DeviceDetailsTracking {

    var onChange: (([String: DeviceDetails]) -> Void)?

    private let reader: DeviceDetailsReading
    private let refreshInterval: TimeInterval
    private let now: () -> Date

    private var details: [String: DeviceDetails] = [:]
    private var lastAttempt: [String: Date] = [:]
    private var inFlight: Set<String> = []

    init(reader: DeviceDetailsReading, refreshInterval: TimeInterval = 60, now: @escaping () -> Date = Date.init) {
        self.reader = reader
        self.refreshInterval = refreshInterval
        self.now = now
    }

    func track(devices: [ADBDevice]) {
        let ready = devices.filter { $0.state == .device }
        forgetDevices(notIn: Set(ready.map(\.serial)))
        for device in ready where needsRead(device.serial) {
            read(device.serial)
        }
    }

    private func needsRead(_ serial: String) -> Bool {
        guard !inFlight.contains(serial) else { return false }
        guard let last = lastAttempt[serial] else { return true }
        return now().timeIntervalSince(last) >= refreshInterval
    }

    private func read(_ serial: String) {
        inFlight.insert(serial)
        reader.readDetails(of: serial) { [weak self] result in
            guard let self = self else { return }
            self.inFlight.remove(serial)
            // A device that went away while this ran is forgotten by the next `track`, which also drops this answer.
            self.lastAttempt[serial] = self.now()
            guard case .success(let read) = result, !read.isEmpty, self.details[serial] != read else { return }
            self.details[serial] = read
            self.onChange?(self.details)
        }
    }

    /// Drops everything about devices that are gone, so they are read again when they come back.
    private func forgetDevices(notIn serials: Set<String>) {
        let gone = Set(lastAttempt.keys).union(details.keys).subtracting(serials).subtracting(inFlight)
        guard !gone.isEmpty else { return }
        let hadDetails = !gone.isDisjoint(with: details.keys)
        gone.forEach {
            details[$0] = nil
            lastAttempt[$0] = nil
        }
        if hadDetails {
            onChange?(details)
        }
    }
}
