//
//  DeviceMonitorTests.swift
//  ADBMonitorTests
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import XCTest
@testable import ADBMonitor

@MainActor
final class DeviceMonitorTests: XCTestCase {

    private var service: FakeADBService!
    private var scheduler: FakeScheduler!
    private var center: NotificationCenter!
    private var monitor: DeviceMonitor!
    private var emitted: [ADBStatus] = []

    override func setUp() {
        super.setUp()
        service = FakeADBService()
        scheduler = FakeScheduler()
        center = NotificationCenter()
        emitted = []
        monitor = DeviceMonitor(service: service,
                                intervalProvider: StubInterval(refreshInterval: 2.5),
                                scheduler: scheduler,
                                notificationCenter: center)
        monitor.onStatusChange = { [unowned self] in emitted.append($0) }
    }

    func testStartPollsImmediately() {
        monitor.start()
        XCTAssertEqual(service.pendingLists.count, 1)
    }

    func testStartTwiceDoesNotPollTwice() {
        monitor.start()
        monitor.start()
        XCTAssertEqual(service.pendingLists.count, 1)
    }

    func testFirstResultIsEmittedAndNextPollScheduledWithConfiguredInterval() {
        monitor.start()
        service.completeList(.success([]))
        XCTAssertEqual(emitted, [.devices([])])
        XCTAssertEqual(scheduler.scheduled.count, 1)
        XCTAssertEqual(scheduler.scheduled.first?.interval, 2.5)
    }

    func testScheduledActionPollsAgain() {
        monitor.start()
        service.completeList(.success([]))
        scheduler.scheduled[0].action()
        XCTAssertEqual(service.pendingLists.count, 1)
    }

    func testUnchangedStatusIsNotEmittedAgain() {
        monitor.start()
        service.completeList(.success([]))
        scheduler.scheduled[0].action()
        service.completeList(.success([]))
        XCTAssertEqual(emitted.count, 1)
    }

    func testChangedStatusIsEmitted() {
        monitor.start()
        service.completeList(.success([]))
        scheduler.scheduled[0].action()
        service.completeList(.success([Sample.device()]))
        XCTAssertEqual(emitted.count, 2)
        XCTAssertEqual(emitted.last, .devices([Sample.device()]))
    }

    func testRefreshWhileIdlePollsImmediatelyAndCancelsTheScheduledPoll() {
        monitor.start()
        service.completeList(.success([]))
        monitor.refresh()
        XCTAssertEqual(service.pendingLists.count, 1)
        XCTAssertTrue(scheduler.scheduled[0].task.isCancelled)
    }

    func testRefreshDuringPollNeverOverlapsButRunsOneMoreRound() {
        monitor.start()
        monitor.refresh()
        XCTAssertEqual(service.pendingLists.count, 1, "tidak boleh ada dua poll bersamaan")
        service.completeList(.failure(.timedOut))
        XCTAssertEqual(service.pendingLists.count, 1, "satu poll tambahan langsung setelah yang pertama")
        XCTAssertTrue(scheduler.scheduled.isEmpty, "poll tambahan menggantikan penjadwalan biasa")
    }

    func testPreferencesChangeTriggersRefresh() {
        monitor.start()
        service.completeList(.success([]))
        center.post(name: .preferencesDidChange, object: nil)
        XCTAssertEqual(service.pendingLists.count, 1)
    }

    func testStopCancelsTimerIgnoresLateResultAndStopsReactingToPreferences() {
        monitor.start()
        service.completeList(.success([]))
        monitor.stop()
        XCTAssertTrue(scheduler.scheduled[0].task.isCancelled)

        center.post(name: .preferencesDidChange, object: nil)
        monitor.refresh()
        XCTAssertTrue(service.pendingLists.isEmpty)
    }

    func testResultArrivingAfterStopIsIgnored() {
        monitor.start()
        monitor.stop()
        service.completeList(.success([Sample.device()]))
        XCTAssertTrue(emitted.isEmpty)
        XCTAssertTrue(scheduler.scheduled.isEmpty)
    }

    func testErrorsAreReportedAsStatus() {
        monitor.start()
        service.completeList(.failure(.notFound(customPath: nil)))
        XCTAssertEqual(emitted, [.adbNotFound(customPath: nil)])
    }
}
