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
        statusBarFactoryCalls = 0
        preferencesFactoryCalls = 0

        let statusBar = statusBar!
        let preferencesWindow = preferencesWindow!
        coordinator = AppCoordinator(monitor: monitor,
                                     service: service,
                                     alerts: alerts,
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

    // MARK: Permintaan dari menu

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

    // MARK: Aksi daya

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
}
