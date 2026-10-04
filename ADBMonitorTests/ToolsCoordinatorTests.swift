//
//  ToolsCoordinatorTests.swift
//  ADBMonitorTests
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import XCTest
@testable import ADBMonitor

@MainActor
final class ToolsCoordinatorTests: XCTestCase {

    private var server: FakeServerController!
    private var fastboot: FakeFastbootService!
    private var alerts: FakeAlerts!
    private var monitor: FakeMonitor!
    private var log: CallLog!
    private var coordinator: ToolsCoordinator!

    private let device = FastbootDevice(serial: "ZY22", mode: "fastboot")

    override func setUp() {
        super.setUp()
        log = CallLog()
        server = FakeServerController()
        server.log = log
        fastboot = FakeFastbootService()
        fastboot.log = log
        alerts = FakeAlerts()
        alerts.log = log
        monitor = FakeMonitor()
        monitor.log = log
        let localizer = Localizer(provider: StubLanguage(languagePreference: .explicit(.english)),
                                  notificationCenter: NotificationCenter())
        coordinator = ToolsCoordinator(server: server, fastboot: fastboot, alerts: alerts, monitor: monitor,
                                       localizer: localizer)
    }

    // MARK: Restart ADB server

    func testRestartServerAsksFirstAndDoesNothingWhenDeclined() {
        alerts.generalConfirmAnswer = false
        coordinator.statusMenuDidRequestRestartServer()
        XCTAssertEqual(alerts.generalConfirmations.count, 1)
        XCTAssertEqual(server.restartCount, 0)
        XCTAssertEqual(monitor.refreshCount, 0)
    }

    func testRestartServerConfirmationExplainsTheSharedServer() {
        coordinator.statusMenuDidRequestRestartServer()
        XCTAssertEqual(alerts.generalConfirmations.first?.title, "Restart the ADB server?")
        XCTAssertEqual(alerts.generalConfirmations.first?.button, "Restart")
        XCTAssertTrue(alerts.generalConfirmations.first?.message.contains("other tools") == true,
                      "the user must be told that other tools share this server")
    }

    func testRestartServerThenRefreshesInThatOrder() {
        coordinator.statusMenuDidRequestRestartServer()
        XCTAssertEqual(log.entries, ["confirm", "restartServer", "refresh"])
        XCTAssertTrue(alerts.errors.isEmpty)
    }

    func testRestartServerFailureStillRefreshesAndShowsTheError() {
        server.result = .failure(.commandFailed("cannot bind"))
        coordinator.statusMenuDidRequestRestartServer()
        XCTAssertEqual(log.entries, ["confirm", "restartServer", "refresh", "error"])
        XCTAssertEqual(alerts.errors.first?.title, "Could not restart the ADB server")
        XCTAssertEqual(alerts.errors.first?.message, "cannot bind")
    }

    // MARK: Fastboot reboot

    func testFastbootRebootAsksFirstAndDoesNothingWhenDeclined() {
        alerts.generalConfirmAnswer = false
        coordinator.statusMenu(didRequestRebootFastbootDevice: device)
        XCTAssertEqual(alerts.generalConfirmations.count, 1)
        XCTAssertTrue(fastboot.rebootedSerials.isEmpty)
        XCTAssertEqual(monitor.refreshCount, 0)
    }

    func testFastbootConfirmationNamesTheSerial() {
        coordinator.statusMenu(didRequestRebootFastbootDevice: device)
        let confirmation = alerts.generalConfirmations.first
        XCTAssertTrue(confirmation?.title.contains("ZY22") == true)
        XCTAssertTrue(confirmation?.message.contains("ZY22") == true)
    }

    func testFastbootRebootRunsOnTheSerialThenRefreshes() {
        coordinator.statusMenu(didRequestRebootFastbootDevice: device)
        XCTAssertEqual(fastboot.rebootedSerials, ["ZY22"])
        XCTAssertEqual(log.entries, ["confirm", "fastbootReboot", "refresh"])
        XCTAssertTrue(alerts.errors.isEmpty)
    }

    func testFastbootRebootFailureShowsTheErrorAfterRefreshing() {
        fastboot.rebootResult = .failure(.notFound(customPath: nil))
        coordinator.statusMenu(didRequestRebootFastbootDevice: device)
        XCTAssertEqual(log.entries, ["confirm", "fastbootReboot", "refresh", "error"])
        XCTAssertTrue(alerts.errors.first?.title.contains("ZY22") == true)
    }
}
