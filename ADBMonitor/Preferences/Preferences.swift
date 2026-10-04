//
//  Preferences.swift
//  ADBMonitor
//

import Foundation

// Protokol dipecah per kebutuhan (ISP): tiap konsumen hanya bergantung pada nilai yang ia pakai.

protocol ADBPathProviding {
    /// Path ADB kustom; `nil` berarti deteksi otomatis.
    var adbPath: String? { get }
}

protocol RefreshIntervalProviding {
    var refreshInterval: TimeInterval { get }
}

protocol PreferencesStoring: ADBPathProviding, RefreshIntervalProviding {
    /// Menyimpan pengaturan lalu memposting `.preferencesDidChange`.
    func save(adbPath: String?, refreshInterval: TimeInterval)
}

enum RefreshIntervalLimits {
    static let `default`: TimeInterval = 3
    static let range: ClosedRange<TimeInterval> = 1...60
}

extension Notification.Name {
    static let preferencesDidChange = Notification.Name("ADBMonitor.PreferencesDidChange")
}
