//
//  Translations.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

/// Kumpulan tabel terjemahan, satu file per bahasa (`Translations+<Bahasa>.swift`).
///
/// Format: placeholder `%@` diisi berurutan, atau `%1$@`, `%2$@` bila urutan argumen berbeda antar bahasa.
/// Semua tabel harus memuat seluruh `L10nKey` dengan jumlah placeholder yang sama seperti bahasa Inggris.
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
