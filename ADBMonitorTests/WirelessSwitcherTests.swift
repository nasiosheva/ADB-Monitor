//
//  WirelessSwitcherTests.swift
//  ADBMonitorTests
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import XCTest
@testable import ADBMonitor

@MainActor
final class WirelessSwitcherTests: XCTestCase {

    private var controller: FakeWirelessController!
    private var scheduler: FakeScheduler!
    private var log: CallLog!
    private var switcher: WirelessSwitcher!
    private var results: [Result<String, ADBError>] = []

    override func setUp() {
        super.setUp()
        controller = FakeWirelessController()
        scheduler = FakeScheduler()
        log = CallLog()
        controller.log = log
        results = []
    }

    private func start(port: Int = 5555, maxAttempts: Int = 6, retryDelay: TimeInterval = 1, serial: String = "SER") {
        switcher = WirelessSwitcher(controller: controller, scheduler: scheduler, port: port,
                                    retryDelay: retryDelay, maxAttempts: maxAttempts)
        switcher.switchToWireless(serial: serial) { [unowned self] in results.append($0) }
    }

    /// Runs the next pending scheduled action (simulates the delay passing).
    private func fireNext() {
        guard let next = scheduler.scheduled.first(where: { !$0.task.isCancelled }) else { return }
        next.task.cancel()   // mark it as used so the next `fireNext` picks up the new schedule
        next.action()
    }

    func testFlowIsWifiAddressThenTCPIPThenConnect() {
        start()
        XCTAssertEqual(log.entries, ["wifiAddress", "tcpip"], "connect harus menunggu jeda")
        XCTAssertEqual(controller.wifiCalls, ["SER"])
        XCTAssertEqual(controller.tcpipCalls.first?.serial, "SER")
        XCTAssertEqual(controller.tcpipCalls.first?.port, 5555)

        fireNext()
        XCTAssertEqual(log.entries, ["wifiAddress", "tcpip", "connect"])
        XCTAssertEqual(controller.connectCalls, ["192.168.1.23:5555"])
        XCTAssertEqual(results, [.success("192.168.1.23:5555")])
    }

    func testWaitsTheConfiguredDelayBeforeEachConnectAttempt() {
        start(retryDelay: 2.5)
        XCTAssertEqual(scheduler.scheduled.first?.interval, 2.5)
        XCTAssertTrue(controller.connectCalls.isEmpty)
    }

    func testRetriesUntilTheDeviceAccepts() {
        let refused: Result<Void, ADBError> = .failure(.commandFailed("refused"))
        controller.connectResults = [refused, refused, .success(())]
        start()
        fireNext(); fireNext(); fireNext()
        XCTAssertEqual(controller.connectCalls.count, 3)
        XCTAssertEqual(results, [.success("192.168.1.23:5555")], "completion hanya sekali")
    }

    func testGivesUpAfterMaxAttemptsWithTheLastError() {
        controller.connectResults = ["a", "b", "c"].map { .failure(.commandFailed($0)) }
        start(maxAttempts: 3)
        fireNext(); fireNext(); fireNext()
        XCTAssertEqual(controller.connectCalls.count, 3)
        XCTAssertEqual(results, [.failure(.commandFailed("c"))])
        XCTAssertFalse(scheduler.scheduled.contains { !$0.task.isCancelled }, "tidak boleh ada percobaan keempat")
    }

    func testStopsWhenTheDeviceHasNoWifiAddress() {
        controller.wifiResult = .failure(.noWiFiAddress)
        start()
        XCTAssertEqual(results, [.failure(.noWiFiAddress)])
        XCTAssertTrue(controller.tcpipCalls.isEmpty, "jangan mengubah mode adbd bila tidak ada alamat Wi-Fi")
        XCTAssertTrue(scheduler.scheduled.isEmpty)
    }

    func testStopsWhenTCPIPFails() {
        controller.tcpipResult = .failure(.commandFailed("error: device offline"))
        start()
        XCTAssertEqual(results, [.failure(.commandFailed("error: device offline"))])
        XCTAssertTrue(scheduler.scheduled.isEmpty)
        XCTAssertTrue(controller.connectCalls.isEmpty)
    }

    func testUsesTheConfiguredPortForBothTCPIPAndConnect() {
        start(port: 5565)
        fireNext()
        XCTAssertEqual(controller.tcpipCalls.first?.port, 5565)
        XCTAssertEqual(controller.connectCalls, ["192.168.1.23:5565"])
        XCTAssertEqual(results, [.success("192.168.1.23:5565")])
    }

    /// Regression from the real phone test: the flow used to die silently if the owner released the switcher
    /// before the asynchronous steps finished, so `completion` was never called.
    func testFlowStillCompletesWhenTheOwnerReleasesTheSwitcher() {
        weak var weakSwitcher: WirelessSwitcher?
        autoreleasepool {
            let temporary = WirelessSwitcher(controller: controller, scheduler: scheduler)
            weakSwitcher = temporary
            temporary.switchToWireless(serial: "SER") { [unowned self] in results.append($0) }
        }
        fireNext()
        XCTAssertEqual(results, [.success("192.168.1.23:5555")])
        XCTAssertEqual(controller.connectCalls, ["192.168.1.23:5555"])
        _ = weakSwitcher
    }

    func testSwitcherIsReleasedOnceTheFlowEnds() {
        weak var weakSwitcher: WirelessSwitcher?
        autoreleasepool {
            // Local scheduler: `FakeScheduler` keeps scheduled closures forever, unlike `Timer`,
            // which releases them after running, so it is released too and only the switcher is under test.
            let localScheduler = FakeScheduler()
            let temporary = WirelessSwitcher(controller: controller, scheduler: localScheduler)
            weakSwitcher = temporary
            temporary.switchToWireless(serial: "SER") { _ in }
            localScheduler.scheduled.first?.action()
            localScheduler.reset()
        }
        XCTAssertNil(weakSwitcher, "tidak boleh ada siklus retain setelah alur selesai")
    }
}
