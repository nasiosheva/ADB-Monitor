//
//  PreferencesUITests.swift
//  ADBMonitorUITests
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import XCTest

/// The Preferences window and its effect on the menu.
final class PreferencesUITests: ADBMonitorUITestCase {

    private var window: XCUIElement { app.windows.firstMatch }

    @discardableResult
    private func openPreferences(file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        openMenu(file: file, line: line)
        app.menuItems["preferencesSelected"].click()
        XCTAssertTrue(window.waitForExistence(timeout: 8), "jendela Preferences tidak muncul", file: file, line: line)
        return window
    }

    private func checkbox(_ title: String) -> XCUIElement { window.checkBoxes[title] }

    private func isChecked(_ element: XCUIElement) -> Bool { (element.value as? Int) == 1 || (element.value as? String) == "1" }

    // MARK: Window content

    func testWindowShowsEveryControl() {
        launch()
        openPreferences()
        XCTAssertEqual(window.title, "ADB Monitor Preferences")
        let texts = window.staticTexts.allElementsBoundByIndex.compactMap { $0.value as? String }
        for label in ["ADB path:", "Refresh interval:", "Language:", "Startup:", "Wi-Fi:", "3 s"] {
            XCTAssertTrue(texts.contains(label), "label \(label) tidak ada. Ada: \(texts)")
        }
        XCTAssertTrue(texts.contains("Using: /fake/adb"), "path ADB terdeteksi harus tampil. Ada: \(texts)")
        XCTAssertTrue(window.buttons["Choose…"].exists)
        XCTAssertTrue(window.buttons["Save"].exists)
        XCTAssertTrue(window.buttons["Cancel"].exists)
        XCTAssertTrue(checkbox("Launch at login").exists)
        XCTAssertTrue(checkbox("Detect devices on Wi-Fi").exists)
        XCTAssertEqual(window.steppers.count, 1)
        XCTAssertEqual(window.popUpButtons.count, 1)
    }

    func testPathFieldIsWideEnoughToType() {
        launch()
        openPreferences()
        let field = window.textFields.firstMatch
        XCTAssertGreaterThan(field.frame.width, 200, "kolom path ADB tidak boleh menyempit")
        XCTAssertEqual(field.placeholderValue, "Auto-detect (leave empty)")
    }

    func testDefaults() {
        launch()
        openPreferences()
        XCTAssertTrue(isChecked(checkbox("Detect devices on Wi-Fi")), "deteksi Wi-Fi aktif secara bawaan")
        XCTAssertFalse(isChecked(checkbox("Launch at login")))
        XCTAssertEqual(window.popUpButtons.firstMatch.value as? String, "English")
    }

    func testLanguageMenuListsEverySupportedLanguage() {
        launch()
        openPreferences()
        window.popUpButtons.firstMatch.click()
        for title in ["System default", "English", "Bahasa Indonesia", "繁體中文", "粵語（廣東話）", "Batak Toba"] {
            XCTAssertTrue(app.menuItems[title].waitForExistence(timeout: 3), title)
        }
        app.typeKey(.escape, modifierFlags: [])
    }

    // MARK: Changes

    func testChangingTheLanguageUpdatesTheMenuAndThePreferencesWindow() {
        launch()
        openPreferences()
        window.popUpButtons.firstMatch.click()
        app.menuItems["Bahasa Indonesia"].click()
        window.buttons["Save"].click()
        XCTAssertTrue(window.waitForNonExistence(timeout: 5), "jendela menutup setelah Save")

        openMenu()
        XCTAssertTrue(menuItem("Perangkat Android (3)").waitForExistence(timeout: 5))
        XCTAssertTrue(app.menuItems["refreshSelected"].title == "Segarkan")
        app.menuItems["preferencesSelected"].click()
        XCTAssertTrue(window.waitForExistence(timeout: 8))
        XCTAssertEqual(window.title, "Preferensi ADB Monitor")
        XCTAssertEqual(window.popUpButtons.firstMatch.value as? String, "Bahasa Indonesia")
    }

    func testCancelDiscardsTheChanges() {
        launch()
        openPreferences()
        window.popUpButtons.firstMatch.click()
        app.menuItems["Bahasa Indonesia"].click()
        window.buttons["Cancel"].click()
        XCTAssertTrue(window.waitForNonExistence(timeout: 5))

        openMenu()
        XCTAssertTrue(menuItem("Android Devices (3)").exists, "bahasa tidak boleh berubah setelah Cancel")
    }

    func testTurningOffWifiDiscoveryHidesTheDiscoveredServices() {
        launch()
        openMenu()
        XCTAssertTrue(menuItem("Available over Wi-Fi (2)").exists)
        closeMenu()

        openPreferences()
        checkbox("Detect devices on Wi-Fi").click()
        XCTAssertFalse(isChecked(checkbox("Detect devices on Wi-Fi")))
        window.buttons["Save"].click()
        XCTAssertTrue(window.waitForNonExistence(timeout: 5))

        let deadline = Date().addingTimeInterval(8)
        while Date() < deadline {
            openMenu()
            if !menuItem(containing: "Available over Wi-Fi").exists { break }
            closeMenu()
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
        XCTAssertFalse(menuItem(containing: "Available over Wi-Fi").exists)
        XCTAssertTrue(app.menuItems["connectByAddressSelected"].exists, "koneksi manual tetap tersedia")
    }

    func testLaunchAtLoginCheckboxCanBeToggledAndIsRemembered() {
        launch()
        openPreferences()
        checkbox("Launch at login").click()
        XCTAssertTrue(isChecked(checkbox("Launch at login")))
        window.buttons["Save"].click()
        XCTAssertTrue(window.waitForNonExistence(timeout: 5))

        openPreferences()
        XCTAssertTrue(isChecked(checkbox("Launch at login")), "status login item dibaca ulang dari (palsu) sistem")
    }

    func testRefreshIntervalStepperUpdatesTheLabel() {
        launch()
        openPreferences()
        XCTAssertTrue(window.staticTexts["3 s"].exists || window.staticTexts.matching(NSPredicate(format: "value == '3 s'")).count == 1)
        window.steppers.firstMatch.incrementArrows.firstMatch.click()
        let updated = window.staticTexts.matching(NSPredicate(format: "value == '4 s'")).firstMatch
        XCTAssertTrue(updated.waitForExistence(timeout: 3), "label interval harus menjadi 4 s")
        window.buttons["Cancel"].click()
    }
}
