//
//  Localizer.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

extension Notification.Name {
    /// Posted after the effective language changed, so the UI that is on screen refreshes its text.
    static let languageDidChange = Notification.Name("ADBMonitor.LanguageDidChange")
}

/// Provides interface text in the language that is currently selected.
@MainActor
protocol Localizing: AnyObject {
    /// Effective language (already accounts for the "follow system" choice).
    var language: AppLanguage { get }
    func text(_ key: L10nKey, arguments: [String]) -> String
}

extension Localizing {
    func text(_ key: L10nKey, _ arguments: String...) -> String {
        text(key, arguments: arguments)
    }

    func label(for state: ADBDevice.State) -> String {
        guard let key = state.labelKey else {
            if case .unknown(let raw) = state { return raw.capitalized }
            return ""
        }
        return text(key)
    }

    func name(of connection: ADBDevice.Connection) -> String {
        text(connection.labelKey)
    }

    func message(for error: ADBError) -> String {
        switch error {
        case .notFound: return text(.errorAdbNotFound)
        case .toolNotFound(let tool): return text(.errorToolNotFound, tool, tool)
        case .timedOut: return text(.errorTimedOut)
        case .launchFailed(let reason): return text(.errorLaunchFailed, reason)
        case .noWiFiAddress: return text(.errorNoWiFiAddress)
        case .invalidAddress: return text(.errorInvalidAddress)
        case .invalidPairingCode: return text(.errorInvalidPairingCode)
        case .qrPairingTimedOut: return text(.errorQRTimedOut)
        case .commandFailed(let output): return output  // raw adb output, not translated
        }
    }
}

/// Translates via the `Translations` tables. The effective language is recomputed on every preferences save.
@MainActor
final class Localizer: Localizing {

    private(set) var language: AppLanguage

    private let provider: LanguageProviding
    private let preferredLanguages: () -> [String]
    private let notificationCenter: NotificationCenter

    init(provider: LanguageProviding,
         preferredLanguages: @escaping () -> [String] = { Locale.preferredLanguages },
         notificationCenter: NotificationCenter = .default) {
        self.provider = provider
        self.preferredLanguages = preferredLanguages
        self.notificationCenter = notificationCenter
        self.language = Self.resolve(provider.languagePreference, preferred: preferredLanguages())

        notificationCenter.addObserver(self,
                                       selector: #selector(preferencesDidChange),
                                       name: .preferencesDidChange,
                                       object: nil)
    }

    deinit {
        notificationCenter.removeObserver(self)
    }

    func text(_ key: L10nKey, arguments: [String]) -> String {
        let template = Translations.table(for: language)[key] ?? Translations.english[key] ?? key.rawValue
        guard !arguments.isEmpty else { return template }
        return String(format: template, arguments: arguments.map { $0 as CVarArg })
    }

    static func resolve(_ preference: LanguagePreference, preferred: [String]) -> AppLanguage {
        switch preference {
        case .explicit(let language): return language
        case .system: return AppLanguage.matching(preferredLanguages: preferred)
        }
    }

    @objc private func preferencesDidChange() {
        let resolved = Self.resolve(provider.languagePreference, preferred: preferredLanguages())
        guard resolved != language else { return }
        language = resolved
        notificationCenter.post(name: .languageDidChange, object: self)
    }
}
