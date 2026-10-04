//
//  AppLanguage.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

/// Bahasa antarmuka yang tersedia.
enum AppLanguage: String, CaseIterable, Equatable {
    case english = "en"
    case indonesian = "id"
    /// Mandarin tulisan Tradisional (gaya Taiwan).
    case chinese = "zh-Hant"
    /// Kanton tulisan (aksara Tradisional, ragam sehari-hari Hong Kong).
    case cantonese = "yue"
    /// Batak Toba (ISO 639-3: `bbc`).
    case batak = "bbc"

    /// Nama bahasa dalam bahasa itu sendiri; tidak diterjemahkan agar selalu bisa dikenali pemakainya.
    var autonym: String {
        switch self {
        case .english: return "English"
        case .indonesian: return "Bahasa Indonesia"
        case .chinese: return "繁體中文"
        case .cantonese: return "粵語（廣東話）"
        case .batak: return "Batak Toba"
        }
    }

    /// Memilih bahasa dari daftar preferensi sistem (mis. `["id-ID", "en-US"]`).
    /// Bahasa Inggris dipakai jika tidak ada yang cocok.
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

/// Pilihan pengguna: mengikuti bahasa sistem, atau bahasa tertentu.
enum LanguagePreference: Equatable {
    case system
    case explicit(AppLanguage)

    /// Nilai yang disimpan di `UserDefaults`; `nil` berarti mengikuti sistem.
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
