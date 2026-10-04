//
//  AppCoordinatorTests.swift
//  ADBMonitorTests
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import XCTest
@testable import ADBMonitor

@MainActor
final class AppCoordinatorTests: XCTestCase {

    private var monitor: FakeMonitor!
    private var service: FakeADBService!
    private var alerts: FakeAlerts!
    private var statusBar: FakeStatusBar!
    private var preferencesWindow: FakePreferencesWindow!
    private var wirelessHandler: RecordingWirelessHandler!
    private var settings: FakeSettingsOpener!
    private var toolsHandler: RecordingMenuHandler!
    private var detailsTracker: FakeDetailsTracker!
    private var log: CallLog!
    private var statusBarFactoryCalls = 0
    private var preferencesFactoryCalls = 0
    private var coordinator: AppCoordinator!

    override func setUp() {
        super.setUp()
        log = CallLog()
        monitor = FakeMonitor()
        monitor.log = log
        service = FakeADBService()
        service.log = log
        alerts = FakeAlerts()
        alerts.log = log
        statusBar = FakeStatusBar()
        preferencesWindow = FakePreferencesWindow()
        wirelessHandler = RecordingWirelessHandler()
        settings = FakeSettingsOpener()
        toolsHandler = RecordingMenuHandler()
        detailsTracker = FakeDetailsTracker()
        settings.log = log
        statusBarFactoryCalls = 0
        preferencesFactoryCalls = 0

        let statusBar = statusBar!
        let preferencesWindow = preferencesWindow!
        let english = Localizer(provider: StubLanguage(languagePreference: .explicit(.english)),
                                notificationCenter: NotificationCenter())
        coordinator = AppCoordinator(monitor: monitor,
                                     service: service,
                                     alerts: alerts,
                                     wireless: wirelessHandler,
                                     tools: toolsHandler,
                                     settings: settings,
                                     localizer: english,
                                     detailsTracker: detailsTracker,
                                     makeStatusBar: { [unowned self] _ in
                                         statusBarFactoryCalls += 1
                                         return statusBar
                                     },
                                     makePreferencesWindow: { [unowned self] in
                                         preferencesFactoryCalls += 1
                                         return preferencesWindow
                                     })
    }

    // MARK: Lifecycle

    func testStartCreatesTheStatusBarAndStartsTheMonitor() {
        coordinator.start()
        XCTAssertEqual(statusBarFactoryCalls, 1)
        XCTAssertEqual(monitor.startCount, 1)
    }

    func testStatusChangesFromTheMonitorAreRenderedOnTheStatusBar() throws {
        coordinator.start()
        let callback = try XCTUnwrap(monitor.onStatusChange)
        callback(.devices([Sample.device()]))
        callback(.adbNotFound(customPath: nil))
        XCTAssertEqual(statusBar.rendered, [.devices([Sample.device()]), .adbNotFound(customPath: nil)])
    }

    func testStopStopsTheMonitor() {
        coordinator.stop()
        XCTAssertEqual(monitor.stopCount, 1)
    }

    // MARK: Requests from the menu

    func testRefreshRequestRefreshesTheMonitor() {
        coordinator.statusMenuDidRequestRefresh()
        XCTAssertEqual(monitor.refreshCount, 1)
    }

    func testPreferencesWindowIsCreatedLazilyOnceAndReused() {
        XCTAssertEqual(preferencesFactoryCalls, 0, "tidak dibuat sebelum diminta")
        coordinator.statusMenuDidRequestPreferences()
        coordinator.statusMenuDidRequestPreferences()
        XCTAssertEqual(preferencesFactoryCalls, 1)
        XCTAssertEqual(preferencesWindow.presentCount, 2)
    }

    // MARK: Power actions

    func testConfirmationIsAskedForTheRightActionAndDevice() {
        let device = Sample.device("SER7")
        coordinator.statusMenu(didRequest: .shutdown, on: device)
        XCTAssertEqual(alerts.confirmations.count, 1)
        XCTAssertEqual(alerts.confirmations.first?.action, .shutdown)
        XCTAssertEqual(alerts.confirmations.first?.device, device)
    }

    func testDeclinedConfirmationDoesNothing() {
        alerts.confirmAnswer = false
        coordinator.statusMenu(didRequest: .restart, on: Sample.device())
        XCTAssertTrue(service.performCalls.isEmpty)
        XCTAssertEqual(monitor.refreshCount, 0)
        XCTAssertTrue(alerts.failures.isEmpty)
    }

    func testConfirmedActionIsPerformedOnTheSelectedSerialOnly() {
        coordinator.statusMenu(didRequest: .restart, on: Sample.device("SER-A"))
        XCTAssertEqual(service.performCalls.count, 1)
        XCTAssertEqual(service.performCalls.first?.action, .restart)
        XCTAssertEqual(service.performCalls.first?.serial, "SER-A")
    }

    func testSuccessRefreshesWithoutShowingAnError() {
        coordinator.statusMenu(didRequest: .restart, on: Sample.device())
        XCTAssertEqual(monitor.refreshCount, 1)
        XCTAssertTrue(alerts.failures.isEmpty)
    }

    func testFailureRefreshesFirstThenShowsTheError() {
        service.performResult = .failure(.commandFailed("device offline"))
        let device = Sample.device("SER-B")

        coordinator.statusMenu(didRequest: .shutdown, on: device)

        XCTAssertEqual(log.entries, ["confirm", "perform", "refresh", "failure"],
                       "refresh harus sebelum dialog error, karena dialog bersifat modal")
        XCTAssertEqual(alerts.failures.count, 1)
        XCTAssertEqual(alerts.failures.first?.action, .shutdown)
        XCTAssertEqual(alerts.failures.first?.device, device)
        XCTAssertEqual(alerts.failures.first?.error, .commandFailed("device offline"))
    }

    func testEveryPowerActionFlowsThroughTheSameSequence() {
        for action in PowerAction.allCases {
            let before = log.entries.count
            coordinator.statusMenu(didRequest: action, on: Sample.device())
            XCTAssertEqual(Array(log.entries.dropFirst(before)), ["confirm", "perform", "refresh"], "\(action)")
        }
    }

    // MARK: - Wi-Fi

    func testWirelessListFromTheMonitorIsRenderedOnTheStatusBar() throws {
        coordinator.start()
        let service = WirelessService(name: "adb-A-aBcDeF", kind: .connect, host: "1.2.3.4", port: 5)
        try XCTUnwrap(monitor.onWirelessChange)([service])
        try XCTUnwrap(monitor.onWirelessChange)([])
        XCTAssertEqual(statusBar.renderedWireless, [[service], []])
    }

    func testWirelessActionsAreForwardedToTheWirelessHandler() {
        let device = Sample.device("SER1")
        coordinator.statusMenu(didRequestConnectTo: "1.2.3.4:5")
        coordinator.statusMenuDidRequestConnectByAddress()
        coordinator.statusMenu(didRequestPairingWith: "1.2.3.4:6")
        coordinator.statusMenu(didRequestPairingWith: nil)
        coordinator.statusMenu(didRequestDisconnect: device)
        coordinator.statusMenu(didRequestSwitchToWireless: device)
        XCTAssertEqual(wirelessHandler.calls,
                       ["connect:1.2.3.4:5", "connectByAddress", "pair:1.2.3.4:6", "pair:nil",
                        "disconnect:SER1", "switch:SER1"])
    }

    // MARK: - Fastboot, details, and tools

    func testFastbootListFromTheMonitorIsRenderedOnTheStatusBar() throws {
        coordinator.start()
        let device = FastbootDevice(serial: "ZY22", mode: "fastboot")
        try XCTUnwrap(monitor.onFastbootChange)([device])
        try XCTUnwrap(monitor.onFastbootChange)([])
        XCTAssertEqual(statusBar.renderedFastboot, [[device], []])
    }

    func testEveryPollIsHandedToTheDetailsTracker() throws {
        coordinator.start()
        let devices = [Sample.device("A"), Sample.device("B")]
        try XCTUnwrap(monitor.onPoll)(devices)
        try XCTUnwrap(monitor.onPoll)(devices)
        XCTAssertEqual(detailsTracker.tracked, [devices, devices])
    }

    func testDetailsFromTheTrackerAreRenderedOnTheStatusBar() throws {
        coordinator.start()
        let details = ["A": DeviceDetails(androidVersion: "12", batteryLevel: 50)]
        try XCTUnwrap(detailsTracker.onChange)(details)
        XCTAssertEqual(statusBar.renderedDetails, [details])
    }

    func testToolsActionsAreForwardedToTheToolsHandler() {
        let device = FastbootDevice(serial: "ZY22", mode: "fastboot")
        coordinator.statusMenuDidRequestRestartServer()
        coordinator.statusMenu(didRequestRebootFastbootDevice: device)
        XCTAssertEqual(toolsHandler.restartServerCount, 1)
        XCTAssertEqual(toolsHandler.fastbootReboots, [device])
        XCTAssertTrue(alerts.generalConfirmations.isEmpty, "the confirmation belongs to ToolsCoordinator")
    }

    // MARK: - Developer options

    func testOpenDeveloperOptionsUsesTheDeviceSerial() {
        coordinator.statusMenu(didRequestOpenDeveloperOptionsOn: Sample.device("SER-D"))
        XCTAssertEqual(settings.serials, ["SER-D"])
        XCTAssertTrue(alerts.errors.isEmpty)
    }

    func testOpenDeveloperOptionsFailureShowsTheDeviceNameAndTheAdbMessage() {
        settings.result = .failure(.commandFailed("Error: Activity not started, unable to resolve Intent"))
        coordinator.statusMenu(didRequestOpenDeveloperOptionsOn: Sample.device("S", model: "Pixel 3a"))
        XCTAssertEqual(alerts.errors.first?.title, "Could not open Developer options on Pixel 3a")
        XCTAssertEqual(alerts.errors.first?.message, "Error: Activity not started, unable to resolve Intent")
    }

    func testOpeningDeveloperOptionsDoesNotAskForConfirmationOrRefresh() {
        coordinator.statusMenu(didRequestOpenDeveloperOptionsOn: Sample.device())
        XCTAssertTrue(alerts.confirmations.isEmpty, "tidak merusak apa pun, jadi tanpa dialog konfirmasi")
        XCTAssertEqual(monitor.refreshCount, 0, "tidak mengubah daftar device")
    }
}
