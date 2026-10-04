//
//  DeviceChangeDetector.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

/// Compares successive device lists and reports devices that came or went.
///
/// - The first list only sets the baseline, so nothing is reported for devices that were already there.
/// - A device counts as gone only after it was missing from `missesBeforeDisconnect` lists in a row. An adb server
///   restart or a flaky Wi-Fi link makes a device vanish for one poll; that must not look like an unplug.
/// - State changes of a known device (for example offline → device) are not reported.
struct DeviceChangeDetector {

    private let missesBeforeDisconnect: Int
    private var known: [String: ADBDevice] = [:]
    private var misses: [String: Int] = [:]
    private var hasBaseline = false

    init(missesBeforeDisconnect: Int = 2) {
        self.missesBeforeDisconnect = max(1, missesBeforeDisconnect)
    }

    /// Takes the newest list and returns what changed since the previous one, in a stable order
    /// (disconnects first, then connects, each sorted by serial).
    mutating func update(with devices: [ADBDevice]) -> [DeviceChange] {
        let current = Dictionary(devices.map { ($0.serial, $0) }, uniquingKeysWith: { first, _ in first })
        defer { hasBaseline = true }

        guard hasBaseline else {
            known = current
            return []
        }

        var disconnected: [ADBDevice] = []
        for (serial, device) in known where current[serial] == nil {
            let count = (misses[serial] ?? 0) + 1
            if count >= missesBeforeDisconnect {
                disconnected.append(device)
                known[serial] = nil
                misses[serial] = nil
            } else {
                misses[serial] = count
            }
        }

        var connected: [ADBDevice] = []
        for (serial, device) in current {
            misses[serial] = nil
            if known[serial] == nil { connected.append(device) }
            known[serial] = device   // keeps the newest model name and state for a later "disconnected"
        }

        let bySerial: (ADBDevice, ADBDevice) -> Bool = { $0.serial < $1.serial }
        return disconnected.sorted(by: bySerial).map(DeviceChange.disconnected)
            + connected.sorted(by: bySerial).map(DeviceChange.connected)
    }
}
