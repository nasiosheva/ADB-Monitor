//
//  Preferences.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

// Protocols are split by need (ISP): each consumer only depends on the values it uses.

protocol ADBPathProviding {
    /// Custom ADB path; `nil` means auto-detect.
    var adbPath: String? { get }
}

protocol RefreshIntervalProviding {
    var refreshInterval: TimeInterval { get }
}

protocol LanguageProviding {
    var languagePreference: LanguagePreference { get }
}

protocol WirelessDiscoveryProviding {
    /// Whether devices on the Wi-Fi network are looked up through mDNS on every poll. Default: on.
    var wirelessDiscoveryEnabled: Bool { get }
}

protocol DeviceNotificationProviding {
    /// Whether the user wants a notification when a device connects or disconnects. Default: off, so the app
    /// does not ask for notification permission before the user has asked for notifications.
    var deviceNotificationsEnabled: Bool { get }
}

protocol PreferencesStoring: ADBPathProviding, RefreshIntervalProviding, LanguageProviding,
                             WirelessDiscoveryProviding, DeviceNotificationProviding {
    /// Saves the settings, then posts `.preferencesDidChange`.
    func save(adbPath: String?, refreshInterval: TimeInterval, language: LanguagePreference,
              wirelessDiscovery: Bool, deviceNotifications: Bool)
}

enum RefreshIntervalLimits {
    static let `default`: TimeInterval = 3
    static let range: ClosedRange<TimeInterval> = 1...60
}

extension Notification.Name {
    static let preferencesDidChange = Notification.Name("ADBMonitor.PreferencesDidChange")
}
