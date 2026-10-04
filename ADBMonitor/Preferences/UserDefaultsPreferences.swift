//
//  UserDefaultsPreferences.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

/// Implementasi `PreferencesStoring` berbasis `UserDefaults`.
final class UserDefaultsPreferences: PreferencesStoring {

    private enum Key {
        static let adbPath = "adbPath"
        static let refreshInterval = "refreshInterval"
        static let language = "language"
        static let wirelessDiscovery = "wirelessDiscovery"
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

    var languagePreference: LanguagePreference {
        LanguagePreference(storedValue: defaults.string(forKey: Key.language))
    }

    var wirelessDiscoveryEnabled: Bool {
        defaults.object(forKey: Key.wirelessDiscovery) as? Bool ?? true
    }

    func save(adbPath: String?, refreshInterval: TimeInterval, language: LanguagePreference,
              wirelessDiscovery: Bool) {
        if let path = adbPath?.trimmed, !path.isEmpty {
            defaults.set(path, forKey: Key.adbPath)
        } else {
            defaults.removeObject(forKey: Key.adbPath)
        }
        defaults.set(refreshInterval, forKey: Key.refreshInterval)
        if let stored = language.storedValue {
            defaults.set(stored, forKey: Key.language)
        } else {
            defaults.removeObject(forKey: Key.language)
        }
        defaults.set(wirelessDiscovery, forKey: Key.wirelessDiscovery)
        notificationCenter.post(name: .preferencesDidChange, object: self)
    }
}
