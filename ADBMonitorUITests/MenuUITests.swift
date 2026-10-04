//
//  MenuUITests.swift
//  ADBMonitorUITests
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import XCTest

/// The menu bar item and the dropdown content for every app state.
final class MenuUITests: ADBMonitorUITestCase {

    func testStatusItemShowsTheDeviceCount() {
        launch()
        waitForStatusTitle(" 3")
        XCTAssertEqual(statusItem.label, "ADB Monitor")
    }

    func testDropdownListsHeaderAndEveryDevice() {
        launch()
        openMenu()
        XCTAssertTrue(menuItem("Android Devices (3)").exists)
        XCTAssertTrue(menuItem("● Pixel 3a (PIXEL3A001) — Connected").exists)
        // adb does not list a model for an unauthorized device, so the name falls back to the serial.
        XCTAssertTrue(menuItem("● SAMSUNG0001 (SAMSUNG0001) — Unauthorized").exists)
        XCTAssertTrue(menuItem("● Galaxy Tab (192.168.1.7:5555) — Connected").exists)
    }

    func testDropdownHasTheCommandItems() {
        launch()
        openMenu()
        for identifier in ["refreshSelected", "preferencesSelected", "quitSelected"] {
            XCTAssertTrue(app.menuItems[identifier].exists, identifier)
        }
        XCTAssertEqual(app.menuItems["refreshSelected"].title, "Refresh")
        XCTAssertEqual(app.menuItems["preferencesSelected"].title, "Preferences…")
        XCTAssertEqual(app.menuItems["quitSelected"].title, "Quit ADB Monitor")
    }

    func testEmptyScenarioShowsNoDevices() {
        launch(scenario: "empty")
        waitForStatusTitle(" 0")
        openMenu()
        XCTAssertTrue(menuItem("No devices connected").exists)
        XCTAssertFalse(menuItem(containing: "Android Devices").exists)
    }

    func testMissingAdbShowsInstallInstructions() {
        launch(scenario: "adb-missing")
        openMenu()
        XCTAssertTrue(menuItem("ADB is not installed").exists)
        XCTAssertTrue(menuItem("Install it (brew install android-platform-tools)").exists)
        XCTAssertTrue(menuItem("or set its path in Preferences.").exists)
        XCTAssertEqual(statusItem.title, " ADB", "ikon peringatan dengan teks ADB")
    }

    func testAdbErrorShowsTheMessageFromAdb() {
        launch(scenario: "adb-error")
        openMenu()
        XCTAssertTrue(menuItem("ADB error").exists)
        XCTAssertTrue(menuItem("adb server version (40) doesn't match this client (41)").exists)
    }

    func testRefreshRunsAdbAgain() {
        launch()
        waitForCommand("devices -l")
        let before = commands().filter { $0.contains("devices -l") }.count
        openMenu()
        app.menuItems["refreshSelected"].click()
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline, commands().filter({ $0.contains("devices -l") }).count <= before {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        XCTAssertGreaterThan(commands().filter { $0.contains("devices -l") }.count, before)
    }

    func testQuitTerminatesTheApp() {
        launch()
        openMenu()
        app.menuItems["quitSelected"].click()
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 8), "aplikasi harus berhenti setelah Quit")
    }

    func testUsesSimulatedAdbOnly() {
        launch()
        waitForCommand("devices -l")
        XCTAssertTrue(commands().allSatisfy { $0.hasPrefix("adb ") }, "semua perintah lewat adb tiruan")
    }
}
