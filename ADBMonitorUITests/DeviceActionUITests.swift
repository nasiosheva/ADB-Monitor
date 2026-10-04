//
//  DeviceActionUITests.swift
//  ADBMonitorUITests
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import XCTest

/// Device submenu: details, restart, shut down, Developer options, and the Wi-Fi switch.
final class DeviceActionUITests: ADBMonitorUITestCase {

    // MARK: Submenu

    func testUSBDeviceSubmenuShowsDetailsThenActions() {
        launch()
        openMenu()
        let device = openSubmenu(of: "PIXEL3A001")
        for title in ["Status: Connected", "Serial: PIXEL3A001", "Connection: USB", "Model: Pixel 3a",
                      "Product: sargo", "Device: sargo", "Copy Serial Number", "Switch to Wi-Fi",
                      "Open Developer Options", "Restart Device…", "Shut Down Device…"] {
            XCTAssertTrue(submenuItem(title, of: device).waitForExistence(timeout: 3), title)
        }
        XCTAssertFalse(submenuItem("Disconnect", of: device).exists, "device USB tidak punya Disconnect")
    }

    func testWifiDeviceSubmenuOffersDisconnectInsteadOfSwitch() {
        launch()
        openMenu()
        let device = openSubmenu(of: "192.168.1.7:5555")
        XCTAssertTrue(submenuItem("Connection: Wi-Fi", of: device).waitForExistence(timeout: 3))
        XCTAssertTrue(submenuItem("Disconnect", of: device).exists)
        XCTAssertFalse(submenuItem("Switch to Wi-Fi", of: device).exists)
    }

    func testUnauthorizedDeviceHasActionsDisabledAndShowsAHint() {
        launch()
        openMenu()
        let device = openSubmenu(of: "SAMSUNG0001")
        XCTAssertTrue(submenuItem("Accept the USB debugging prompt on the device.", of: device)
                        .waitForExistence(timeout: 3))
        for title in ["Restart Device…", "Shut Down Device…", "Open Developer Options"] {
            let item = submenuItem(title, of: device)
            XCTAssertTrue(item.exists, title)
            XCTAssertFalse(item.isEnabled, "\(title) harus nonaktif untuk device yang belum diotorisasi")
        }
    }

    // MARK: Restart and Shut Down

    func testRestartAsksForConfirmationThenRunsOnTheSelectedDevice() {
        launch()
        chooseDeviceAction("Restart Device…", device: "PIXEL3A001")
        waitForDialog()
        XCTAssertTrue(dialogTexts().contains("Restart Pixel 3a?"), "teks dialog: \(dialogTexts())")
        XCTAssertTrue(dialogTexts().contains {
            $0.contains("PIXEL3A001") && $0.contains("will reboot immediately")
        })
        assertNoCommand("reboot", waiting: 0.5)   // not confirmed yet

        clickDialogButton("Restart")
        waitForCommand("-s PIXEL3A001 reboot")
        XCTAssertFalse(hasCommand("-s 192.168.1.7:5555 reboot"), "tidak boleh mengenai device lain")
    }

    func testCancellingRestartRunsNothing() {
        launch()
        chooseDeviceAction("Restart Device…", device: "PIXEL3A001")
        waitForDialog()
        clickDialogButton("Cancel")
        waitForNoDialog()
        assertNoCommand("reboot")
    }

    func testShutDownAsksForConfirmationThenRuns() {
        launch()
        chooseDeviceAction("Shut Down Device…", device: "PIXEL3A001")
        waitForDialog()
        XCTAssertTrue(dialogTexts().contains("Shut Down Pixel 3a?"))
        XCTAssertTrue(dialogTexts().contains { $0.contains("cannot be turned back on from this Mac") })
        clickDialogButton("Shut Down")
        waitForCommand("-s PIXEL3A001 shell reboot -p")
    }

    func testCancellingShutDownRunsNothing() {
        launch()
        chooseDeviceAction("Shut Down Device…", device: "PIXEL3A001")
        waitForDialog()
        clickDialogButton("Cancel")
        waitForNoDialog()
        assertNoCommand("reboot -p")
    }

    // MARK: Developer options

    func testOpenDeveloperOptionsRunsWithoutConfirmation() {
        launch()
        chooseDeviceAction("Open Developer Options", device: "PIXEL3A001")
        waitForCommand("-s PIXEL3A001 shell am start -a android.settings.APPLICATION_DEVELOPMENT_SETTINGS")
        XCTAssertEqual(app.dialogs.count, 0, "tidak ada dialog konfirmasi")
    }

    // MARK: USB -> Wi-Fi and Disconnect

    func testSwitchToWifiRunsTheWholeSequenceAndTheDeviceAppears() {
        launch()
        waitForStatusTitle(" 3")
        chooseDeviceAction("Switch to Wi-Fi", device: "PIXEL3A001")
        waitForCommand("-s PIXEL3A001 shell ip route get 1.1.1.1")
        waitForCommand("-s PIXEL3A001 tcpip 5555")
        waitForCommand("connect 192.168.1.50:5555")

        waitForStatusTitle(" 4")
        openMenu()
        XCTAssertTrue(menuItem("● Wi-Fi Device (192.168.1.50:5555) — Connected").waitForExistence(timeout: 5))
    }

    func testDisconnectRemovesTheWifiDevice() {
        launch()
        waitForStatusTitle(" 3")
        chooseDeviceAction("Disconnect", device: "192.168.1.7:5555")
        waitForCommand("disconnect 192.168.1.7:5555")
        waitForStatusTitle(" 2")
        openMenu()
        XCTAssertFalse(menuItem(containing: "192.168.1.7:5555").exists)
    }
}
