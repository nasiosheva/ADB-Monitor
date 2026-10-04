//
//  Preferences.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
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

protocol LanguageProviding {
    var languagePreference: LanguagePreference { get }
}

protocol WirelessDiscoveryProviding {
    /// Apakah device di jaringan Wi-Fi dicari lewat mDNS pada setiap polling. Bawaan: aktif.
    var wirelessDiscoveryEnabled: Bool { get }
}

protocol PreferencesStoring: ADBPathProviding, RefreshIntervalProviding, LanguageProviding,
                             WirelessDiscoveryProviding {
    /// Menyimpan pengaturan lalu memposting `.preferencesDidChange`.
    func save(adbPath: String?, refreshInterval: TimeInterval, language: LanguagePreference,
              wirelessDiscovery: Bool)
}

enum RefreshIntervalLimits {
    static let `default`: TimeInterval = 3
    static let range: ClosedRange<TimeInterval> = 1...60
}

extension Notification.Name {
    static let preferencesDidChange = Notification.Name("ADBMonitor.PreferencesDidChange")
}
