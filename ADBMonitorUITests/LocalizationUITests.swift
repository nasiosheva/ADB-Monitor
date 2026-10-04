//
//  LocalizationUITests.swift
//  ADBMonitorUITests
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import XCTest

/// Every language shows up in the dropdown and in the dialogs derived from it.
final class LocalizationUITests: ADBMonitorUITestCase {

    private func assertMenu(language: String, header: String, connectItem: String, refresh: String,
                            file: StaticString = #filePath, line: UInt = #line) {
        launch(language: language)
        openMenu(file: file, line: line)
        XCTAssertTrue(menuItem(header).exists, "[\(language)] header \(header)", file: file, line: line)
        XCTAssertEqual(app.menuItems["connectByAddressSelected"].title, connectItem, file: file, line: line)
        XCTAssertEqual(app.menuItems["refreshSelected"].title, refresh, file: file, line: line)
    }

    func testEnglish() {
        assertMenu(language: "en", header: "Android Devices (3)", connectItem: "Connect to IP Address…", refresh: "Refresh")
    }

    func testIndonesian() {
        assertMenu(language: "id", header: "Perangkat Android (3)", connectItem: "Hubungkan ke Alamat IP…", refresh: "Segarkan")
    }

    func testTraditionalChinese() {
        assertMenu(language: "zh-Hant", header: "Android 裝置（3）", connectItem: "連線至 IP 位址…", refresh: "重新整理")
    }

    func testCantonese() {
        assertMenu(language: "yue", header: "Android 裝置（3）", connectItem: "連接去 IP 位址…", refresh: "重新整理")
    }

    func testBatakToba() {
        assertMenu(language: "bbc", header: "Alat Android (3)", connectItem: "Sambung tu Alamat IP…", refresh: "Pabaru")
    }

    func testConnectDialogIsLocalizedAndUsableInEveryLanguage() {
        let expected: [(code: String, title: String, button: String)] = [
            ("id", "Hubungkan lewat Wi-Fi", "Hubungkan"),
            ("zh-Hant", "透過 Wi-Fi 連線", "連線"),
            ("yue", "經 Wi-Fi 連接", "連接"),
            ("bbc", "Sambung lewat Wi-Fi", "Sambung"),
        ]
        for entry in expected {
            launch(language: entry.code)
            openMenu()
            app.menuItems["connectByAddressSelected"].click()
            waitForDialog()
            XCTAssertTrue(dialogTexts().contains(entry.title), "[\(entry.code)] \(dialogTexts())")
            XCTAssertTrue(dialog.buttons[entry.button].exists, "[\(entry.code)] tombol \(entry.button)")
            XCTAssertGreaterThan(dialog.textFields.firstMatch.frame.width, 200, "[\(entry.code)] kolom isian")
            app.terminate()
        }
    }
}
