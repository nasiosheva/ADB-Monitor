//
//  LocalizationTests.swift
//  ADBMonitorTests
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import XCTest
@testable import ADBMonitor

/// Kelengkapan tabel tidak dijaga compiler (kamus Swift), jadi diperiksa di sini.
final class TranslationTableTests: XCTestCase {

    private func placeholders(_ text: String) -> [String] {
        let regex = try! NSRegularExpression(pattern: "%(\\d+\\$)?@")
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            .map { (text as NSString).substring(with: $0.range) }
            .sorted()
    }

    func testEveryLanguageDefinesEveryKeyAndNothingElse() {
        for language in AppLanguage.allCases {
            let table = Translations.table(for: language)
            let missing = L10nKey.allCases.filter { table[$0] == nil }
            XCTAssertTrue(missing.isEmpty, "\(language.rawValue) kekurangan: \(missing)")
            XCTAssertEqual(table.count, L10nKey.allCases.count, "\(language.rawValue) punya kunci berlebih")
        }
    }

    func testPlaceholdersMatchEnglish() {
        for language in AppLanguage.allCases where language != .english {
            for key in L10nKey.allCases {
                XCTAssertEqual(placeholders(Translations.table(for: language)[key] ?? ""),
                               placeholders(Translations.english[key] ?? ""),
                               "\(language.rawValue).\(key) placeholder berbeda")
            }
        }
    }

    func testNoEmptyStrings() {
        for language in AppLanguage.allCases {
            for (key, value) in Translations.table(for: language) {
                XCTAssertFalse(value.trimmed.isEmpty, "\(language.rawValue).\(key) kosong")
            }
        }
    }

    func testLongSentencesAreActuallyTranslated() {
        for language in AppLanguage.allCases where language != .english {
            for key in L10nKey.allCases {
                let english = Translations.english[key] ?? ""
                // Hanya kalimat (mengandung spasi); contoh teknis seperti "192.168.1.5:5555" sama di semua bahasa.
                guard english.count > 12, english.contains(" "), !english.contains("brew") else { continue }
                XCTAssertNotEqual(Translations.table(for: language)[key], english,
                                  "\(language.rawValue).\(key) masih berbahasa Inggris")
            }
        }
    }

    func testEveryLanguageHasAnAutonym() {
        for language in AppLanguage.allCases { XCTAssertFalse(language.autonym.isEmpty) }
        XCTAssertEqual(Set(AppLanguage.allCases.map(\.autonym)).count, AppLanguage.allCases.count)
    }
}

final class LanguageResolutionTests: XCTestCase {

    func testMatchingSystemLanguages() {
        XCTAssertEqual(AppLanguage.matching(preferredLanguages: ["id-ID", "en-US"]), .indonesian)
        XCTAssertEqual(AppLanguage.matching(preferredLanguages: ["en-GB"]), .english)
        XCTAssertEqual(AppLanguage.matching(preferredLanguages: ["zh-Hant-TW"]), .chinese)
        XCTAssertEqual(AppLanguage.matching(preferredLanguages: ["zh-Hans-CN"]), .chinese)
        XCTAssertEqual(AppLanguage.matching(preferredLanguages: ["yue-Hant-HK"]), .cantonese)
        XCTAssertEqual(AppLanguage.matching(preferredLanguages: ["bbc"]), .batak)
    }

    func testCantoneseIsCheckedBeforeChinese() {
        XCTAssertEqual(AppLanguage.matching(preferredLanguages: ["yue"]), .cantonese)
    }

    func testUnsupportedLanguagesAreSkippedThenFallBackToEnglish() {
        XCTAssertEqual(AppLanguage.matching(preferredLanguages: ["fr-FR", "id"]), .indonesian)
        XCTAssertEqual(AppLanguage.matching(preferredLanguages: ["fr-FR"]), .english)
        XCTAssertEqual(AppLanguage.matching(preferredLanguages: []), .english)
    }

    func testLanguagePreferenceStorage() {
        XCTAssertEqual(LanguagePreference(storedValue: nil), .system)
        XCTAssertEqual(LanguagePreference(storedValue: "bbc"), .explicit(.batak))
        XCTAssertEqual(LanguagePreference(storedValue: "klingon"), .system)
        XCTAssertNil(LanguagePreference.system.storedValue)
        for language in AppLanguage.allCases {
            XCTAssertEqual(LanguagePreference(storedValue: LanguagePreference.explicit(language).storedValue),
                           .explicit(language))
        }
    }
}

@MainActor
final class LocalizerTests: XCTestCase {

    private var center: NotificationCenter!
    private var preferred: [String] = []
    private var current: LanguagePreference = .system
    private var localizer: Localizer!

    private struct MutableLanguage: LanguageProviding {
        let read: () -> LanguagePreference
        var languagePreference: LanguagePreference { read() }
    }

    override func setUp() {
        super.setUp()
        center = NotificationCenter()
        preferred = ["id-ID"]
        current = .system
        localizer = Localizer(provider: MutableLanguage(read: { [unowned self] in current }),
                              preferredLanguages: { [unowned self] in preferred },
                              notificationCenter: center)
    }

    private func changePreference(_ preference: LanguagePreference) {
        current = preference
        center.post(name: .preferencesDidChange, object: nil)
    }

    func testStartsWithSystemLanguage() {
        XCTAssertEqual(localizer.language, .indonesian)
        XCTAssertEqual(localizer.text(.menuRefresh), "Segarkan")
    }

    func testArgumentsAreSubstituted() {
        XCTAssertEqual(localizer.text(.menuDevicesHeader, "3"), "Perangkat Android (3)")
        XCTAssertEqual(localizer.text(.labelValue, "Serial", "ABC"), "Serial: ABC")
    }

    func testChineseUsesFullWidthColon() {
        changePreference(.explicit(.chinese))
        XCTAssertEqual(localizer.text(.labelValue, "序號", "ABC"), "序號：ABC")
    }

    func testExplicitChoiceOverridesSystemAndNotifiesOnce() {
        var changes = 0
        let token = center.addObserver(forName: .languageDidChange, object: nil, queue: nil) { _ in changes += 1 }
        defer { center.removeObserver(token) }

        changePreference(.explicit(.chinese))
        XCTAssertEqual(localizer.language, .chinese)
        XCTAssertEqual(changes, 1)
    }

    func testSavingWithoutChangingLanguageDoesNotNotify() {
        changePreference(.explicit(.chinese))
        var changes = 0
        let token = center.addObserver(forName: .languageDidChange, object: nil, queue: nil) { _ in changes += 1 }
        defer { center.removeObserver(token) }

        changePreference(.explicit(.chinese))
        XCTAssertEqual(changes, 0)
    }

    func testFollowsSystemLanguageChangesWhenSetToSystem() {
        preferred = ["bbc"]
        changePreference(.system)
        XCTAssertEqual(localizer.language, .batak)
    }

    func testErrorMessages() {
        XCTAssertEqual(localizer.message(for: .timedOut), Translations.indonesian[.errorTimedOut])
        XCTAssertEqual(localizer.message(for: .notFound(customPath: nil)), Translations.indonesian[.errorAdbNotFound])
        XCTAssertEqual(localizer.message(for: .launchFailed("x")), "Gagal menjalankan adb: x")
        XCTAssertEqual(localizer.message(for: .commandFailed("raw adb text")), "raw adb text",
                       "keluaran mentah adb tidak boleh diterjemahkan")
    }

    func testStateAndConnectionLabels() {
        XCTAssertEqual(localizer.label(for: .device), Translations.indonesian[.stateConnected])
        XCTAssertEqual(localizer.label(for: .unknown("weird")), "Weird")
        XCTAssertEqual(localizer.name(of: .network), "Wi-Fi")
    }

    func testPowerActionBodiesContainTheSerial() {
        for action in PowerAction.allCases {
            XCTAssertTrue(localizer.text(action.confirmBodyKey, "SER-1").contains("SER-1"))
            XCTAssertTrue(localizer.text(action.confirmTitleKey, "Pixel").contains("Pixel"))
        }
    }
}
