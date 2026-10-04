//
//  UserDefaultsPreferences.swift
//  ADBMonitor
//

import Foundation

/// Implementasi `PreferencesStoring` berbasis `UserDefaults`.
final class UserDefaultsPreferences: PreferencesStoring {

    private enum Key {
        static let adbPath = "adbPath"
        static let refreshInterval = "refreshInterval"
    }

    private let defaults: UserDefaults
    private let notificationCenter: NotificationCenter

    init(defaults: UserDefaults = .standard, notificationCenter: NotificationCenter = .default) {
        self.defaults = defaults
        self.notificationCenter = notificationCenter
    }

    var adbPath: String? {
        guard let value = defaults.string(forKey: Key.adbPath)?.trimmed, !value.isEmpty else { return nil }
        return value
    }

    var refreshInterval: TimeInterval {
        let stored = defaults.object(forKey: Key.refreshInterval) as? Double ?? RefreshIntervalLimits.default
        let range = RefreshIntervalLimits.range
        return min(max(stored, range.lowerBound), range.upperBound)
    }

    func save(adbPath: String?, refreshInterval: TimeInterval) {
        if let path = adbPath?.trimmed, !path.isEmpty {
            defaults.set(path, forKey: Key.adbPath)
        } else {
            defaults.removeObject(forKey: Key.adbPath)
        }
        defaults.set(refreshInterval, forKey: Key.refreshInterval)
        notificationCenter.post(name: .preferencesDidChange, object: self)
    }
}
