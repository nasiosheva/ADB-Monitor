//
//  Translations.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

/// The set of translation tables, one file per language (`Translations+<Language>.swift`).
///
/// Format: `%@` placeholders are filled in order, or `%1$@`, `%2$@` when argument order differs by language.
/// Every table must contain all `L10nKey`s with the same number of placeholders as English.
enum Translations {
    static func table(for language: AppLanguage) -> [L10nKey: String] {
        switch language {
        case .english: return english
        case .indonesian: return indonesian
        case .chinese: return chinese
        case .cantonese: return cantonese
        case .batak: return batak
        }
    }
}
