//
//  WirelessUITests.swift
//  ADBMonitorUITests
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import XCTest

/// Wi-Fi section: the discovered services list, the "Connect to IP Address…" dialog, and the pairing dialog.
final class WirelessUITests: ADBMonitorUITestCase {

    private let tablet = "Connect to TABLET9 (192.168.1.20:37899)"
    private let phone = "Pair with PHONE77 (192.168.1.21:41223)…"

    // MARK: List

    func testWifiSectionListsDiscoveredServicesAndManualCommands() {
        launch()
        openMenu()
        XCTAssertTrue(menuItem("Available over Wi-Fi (2)").exists)
        XCTAssertTrue(menuItem(tablet).exists)
        XCTAssertTrue(menuItem(phone).exists)
        XCTAssertTrue(app.menuItems["connectByAddressSelected"].exists)
        XCTAssertEqual(app.menuItems["connectByAddressSelected"].title, "Connect to IP Address…")
        XCTAssertEqual(app.menuItems["pairDeviceSelected"].title, "Pair Device…")
    }

    func testManualCommandsStayAvailableWithoutAnyDiscoveredService() {
        launch(scenario: "empty")
        openMenu()
        XCTAssertFalse(menuItem(containing: "Available over Wi-Fi").exists)
        XCTAssertTrue(app.menuItems["connectByAddressSelected"].exists)
        XCTAssertTrue(app.menuItems["pairDeviceSelected"].exists)
    }

    func testClickingADiscoveredServiceConnects() {
        launch()
        waitForStatusTitle(" 3")
        openMenu()
        menuItem(tablet).click()
        waitForCommand("connect 192.168.1.20:37899")
        waitForStatusTitle(" 4")
    }

    // MARK: Connect to IP Address…

    private func openConnectDialog() {
        openMenu()
        app.menuItems["connectByAddressSelected"].click()
        waitForDialog()
    }

    /// Regression: the text field once collapsed to width 0, so this dialog could not be typed into.
    func testConnectDialogHasAVisibleAndUsableTextField() {
        launch()
        openConnectDialog()
        XCTAssertTrue(dialogTexts().contains("Connect over Wi-Fi"))
        XCTAssertEqual(dialog.textFields.count, 1)

        let field = dialog.textFields.firstMatch
        XCTAssertTrue(field.exists)
        XCTAssertGreaterThan(field.frame.width, 200, "kolom alamat harus terlihat dengan lebar yang wajar")
        XCTAssertGreaterThan(field.frame.height, 15)
        XCTAssertEqual(field.placeholderValue, "192.168.1.5:5555")
        XCTAssertTrue(dialog.buttons["Connect"].exists)
        XCTAssertTrue(dialog.buttons["Cancel"].exists)
    }

    func testTypedAddressIsConnectedWithTheDefaultPort() {
        launch()
        waitForStatusTitle(" 3")
        openConnectDialog()
        let field = dialog.textFields.firstMatch
        field.click()
        field.typeText("192.168.1.30")
        XCTAssertEqual(field.value as? String, "192.168.1.30", "teks yang diketik harus masuk ke kolom")
        clickDialogButton("Connect")
        waitForCommand("connect 192.168.1.30:5555")
        waitForStatusTitle(" 4")
    }

    func testTypedAddressWithPortIsKept() {
        launch()
        openConnectDialog()
        let field = dialog.textFields.firstMatch
        field.click()
        field.typeText("192.168.1.30:40123")
        clickDialogButton("Connect")
        waitForCommand("connect 192.168.1.30:40123")
    }

    func testCancellingTheConnectDialogRunsNothing() {
        launch()
        openConnectDialog()
        dialog.textFields.firstMatch.click()
        dialog.textFields.firstMatch.typeText("192.168.1.30")
        clickDialogButton("Cancel")
        waitForNoDialog()
        assertNoCommand("connect 192.168.1.30")
    }

    func testInvalidAddressShowsAnErrorAndRunsNothing() {
        launch()
        openConnectDialog()
        let field = dialog.textFields.firstMatch
        field.click()
        field.typeText("bad host")
        clickDialogButton("Connect")

        waitForDialog()
        XCTAssertTrue(dialogTexts().contains("Could not connect to bad host"), "\(dialogTexts())")
        XCTAssertTrue(dialogTexts().contains {
            $0.hasPrefix("Enter a valid IP address, optionally followed by a port")
        })
        assertNoCommand("connect bad")
        clickDialogButton("OK")
        waitForNoDialog()
    }

    func testUnreachableAddressShowsTheMessageFromAdb() {
        launch()
        openConnectDialog()
        let field = dialog.textFields.firstMatch
        field.click()
        field.typeText("10.0.0.99")
        clickDialogButton("Connect")

        waitForDialog()
        XCTAssertTrue(dialogTexts().contains("Could not connect to 10.0.0.99:5555"), "\(dialogTexts())")
        XCTAssertTrue(dialogTexts().contains { $0.contains("Connection refused") })
        clickDialogButton("OK")
    }

    // MARK: Pairing

    private func openPairingDialog(fromDiscovered: Bool) {
        openMenu()
        if fromDiscovered {
            menuItem(phone).click()
        } else {
            app.menuItems["pairDeviceSelected"].click()
        }
        waitForDialog()
    }

    func testPairingDialogFromADiscoveredServiceIsPrefilled() {
        launch()
        openPairingDialog(fromDiscovered: true)
        XCTAssertTrue(dialogTexts().contains("Pair a device"))
        XCTAssertEqual(dialog.textFields.count, 2)
        for index in 0..<2 {
            XCTAssertGreaterThan(dialog.textFields.element(boundBy: index).frame.width, 200, "kolom \(index)")
        }
        XCTAssertEqual(dialog.textFields.element(boundBy: 0).value as? String, "192.168.1.21:41223")
        XCTAssertEqual(dialog.textFields.element(boundBy: 1).placeholderValue, "6-digit pairing code")
        XCTAssertTrue(dialog.buttons["Pair"].exists)
    }

    func testManualPairingDialogStartsEmpty() {
        launch()
        openPairingDialog(fromDiscovered: false)
        XCTAssertEqual(dialog.textFields.count, 2)
        XCTAssertEqual(dialog.textFields.element(boundBy: 0).placeholderValue, "IP address and port (192.168.1.5:41223)")
        XCTAssertTrue((dialog.textFields.element(boundBy: 0).value as? String ?? "").isEmpty
                      || dialog.textFields.element(boundBy: 0).value as? String == "IP address and port (192.168.1.5:41223)")
    }

    func testPairingWithTheRightCodeSucceedsAndOffersTheDeviceToConnect() {
        launch()
        openPairingDialog(fromDiscovered: true)
        let code = dialog.textFields.element(boundBy: 1)
        code.click()
        code.typeText("123456")
        clickDialogButton("Pair")

        waitForCommand("pair 192.168.1.21:41223 123456")
        waitForDialog()
        XCTAssertTrue(dialogTexts().contains("Paired"), "\(dialogTexts())")
        XCTAssertTrue(dialogTexts().contains { $0.contains("192.168.1.21:41223 is paired") })
        clickDialogButton("OK")
        waitForNoDialog()

        openMenu()
        XCTAssertTrue(menuItem("Connect to PHONE77 (192.168.1.21:37001)").waitForExistence(timeout: 8),
                      "setelah pairing, device muncul sebagai siap disambungkan")
        XCTAssertFalse(menuItem(phone).exists, "layanan pairing hilang setelah berhasil")
    }

    func testPairingWithAWrongCodeShowsTheMessageFromAdb() {
        launch()
        openPairingDialog(fromDiscovered: true)
        let code = dialog.textFields.element(boundBy: 1)
        code.click()
        code.typeText("000000")
        clickDialogButton("Pair")

        waitForDialog()
        XCTAssertTrue(dialogTexts().contains("Could not pair with 192.168.1.21:41223"), "\(dialogTexts())")
        XCTAssertTrue(dialogTexts().contains { $0.contains("Failed: Wrong password") })
        clickDialogButton("OK")
    }

    func testPairingWithAMalformedCodeIsRejectedBeforeRunningAdb() {
        launch()
        openPairingDialog(fromDiscovered: true)
        let code = dialog.textFields.element(boundBy: 1)
        code.click()
        code.typeText("12")
        clickDialogButton("Pair")

        waitForDialog()
        XCTAssertTrue(dialogTexts().contains { $0.contains("Enter the 6-digit pairing code") }, "\(dialogTexts())")
        assertNoCommand("pair 192.168.1.21")
        clickDialogButton("OK")
    }

    func testManualPairingTypesBothFields() {
        launch()
        openPairingDialog(fromDiscovered: false)
        let address = dialog.textFields.element(boundBy: 0)
        address.click()
        address.typeText("192.168.1.21:41223")
        let code = dialog.textFields.element(boundBy: 1)
        code.click()
        code.typeText("123456")
        clickDialogButton("Pair")
        waitForCommand("pair 192.168.1.21:41223 123456")
    }

    func testCancellingThePairingDialogRunsNothing() {
        launch()
        openPairingDialog(fromDiscovered: true)
        clickDialogButton("Cancel")
        waitForNoDialog()
        assertNoCommand("pair ")
    }
}
