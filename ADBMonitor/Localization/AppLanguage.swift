//
//  AppLanguage.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

/// Interface languages that are available.
enum AppLanguage: String, CaseIterable, Equatable {
    case english = "en"
    case indonesian = "id"
    /// Mandarin in Traditional script (Taiwan style).
    case chinese = "zh-Hant"
    /// Written Cantonese (Traditional characters, everyday Hong Kong register).
    case cantonese = "yue"
    /// Batak Toba (ISO 639-3: `bbc`).
    case batak = "bbc"

    /// The language's name in that language itself; never translated so its speakers can always recognize it.
    var autonym: String {
        switch self {
        case .english: return "English"
        case .indonesian: return "Bahasa Indonesia"
        case .chinese: return "繁體中文"
        case .cantonese: return "粵語（廣東話）"
        case .batak: return "Batak Toba"
        }
    }

    /// Picks a language from the system preference list (for example `["id-ID", "en-US"]`).
    /// English is used when nothing matches.
    static func matching(preferredLanguages: [String]) -> AppLanguage {
        for identifier in preferredLanguages {
            let code = identifier.lowercased()
            if code.hasPrefix("yue") { return .cantonese }
            if code.hasPrefix("zh") { return .chinese }
            if code.hasPrefix("bbc") { return .batak }
            if code.hasPrefix("id") || code.hasPrefix("in") { return .indonesian }
            if code.hasPrefix("en") { return .english }
        }
        return .english
    }
}

/// The user's choice: follow the system language, or a specific language.
enum LanguagePreference: Equatable {
    case system
    case explicit(AppLanguage)

    /// Value stored in `UserDefaults`; `nil` means follow the system.
    var storedValue: String? {
        switch self {
        case .system: return nil
        case .explicit(let language): return language.rawValue
        }
    }

    init(storedValue: String?) {
        if let storedValue = storedValue, let language = AppLanguage(rawValue: storedValue) {
            self = .explicit(language)
        } else {
            self = .system
        }
    }
}
