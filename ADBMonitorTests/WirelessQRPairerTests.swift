//
//  WirelessQRPairerTests.swift
//  ADBMonitorTests
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import XCTest
@testable import ADBMonitor

@MainActor
final class WirelessQRPairerTests: XCTestCase {

    private let credentials = PairingQRCredentials(name: "adbmonitor-Ab3dEf9h", password: "Zx81Qw0Lm2Ns")

    private var discovery: FakeWirelessDiscovery!
    private var controller: FakeWirelessController!
    private var scheduler: FakeScheduler!
    private var pairer: WirelessQRPairer!
    private var results: [Result<String, ADBError>] = []
    private var pairingNotifications = 0

    override func setUp() {
        super.setUp()
        discovery = FakeWirelessDiscovery()
        controller = FakeWirelessController()
        scheduler = FakeScheduler()
        pairer = WirelessQRPairer(discovery: discovery, controller: controller, scheduler: scheduler,
                                  pollInterval: 2, maxPolls: 3)
        results = []
        pairingNotifications = 0
    }

    private func start() {
        pairer.start(credentials: credentials,
                     onPairing: { [unowned self] in pairingNotifications += 1 },
                     completion: { [unowned self] in results.append($0) })
    }

    private func service(_ name: String, kind: WirelessService.Kind = .pairing,
                         host: String = "192.168.1.5", port: Int = 41223) -> WirelessService {
        WirelessService(name: name, kind: kind, host: host, port: port)
    }

    /// Runs the timer that `schedule` stored, like the run loop would.
    private func fireScheduledPoll() {
        let action = scheduler.scheduled[0].action
        scheduler.reset()  // a real `Timer` releases its closure after firing
        action()
    }

    func testPairsWithTheServiceWhoseNameMatchesTheQRCode() {
        start()
        discovery.complete(.success([service("adbmonitor-other"), service(credentials.name, port: 37001)]))
        XCTAssertEqual(pairingNotifications, 1)
        XCTAssertEqual(controller.qrPairCalls.map(\.address), ["192.168.1.5:37001"])
        XCTAssertEqual(controller.qrPairCalls.map(\.password), [credentials.password])
        XCTAssertEqual(results, [.success("192.168.1.5:37001")])
    }

    func testKeepsPollingUntilTheServiceAppears() {
        start()
        discovery.complete(.success([]))
        XCTAssertEqual(scheduler.scheduled.map(\.interval), [2])
        XCTAssertTrue(controller.qrPairCalls.isEmpty)

        fireScheduledPoll()
        discovery.complete(.success([service(credentials.name)]))
        XCTAssertEqual(results, [.success("192.168.1.5:41223")])
    }

    func testIgnoresAServiceWithTheRightNameThatIsNotAPairingService() {
        start()
        discovery.complete(.success([service(credentials.name, kind: .connect)]))
        XCTAssertTrue(controller.qrPairCalls.isEmpty)
        XCTAssertEqual(scheduler.scheduled.count, 1, "still waiting")
    }

    func testTimesOutAfterTheMaximumNumberOfPolls() {
        start()
        for _ in 0..<2 {
            discovery.complete(.success([]))
            fireScheduledPoll()
        }
        discovery.complete(.success([]))
        XCTAssertEqual(results, [.failure(.qrPairingTimedOut)])
        XCTAssertTrue(scheduler.scheduled.isEmpty, "nothing is scheduled after giving up")
    }

    func testADiscoveryErrorDoesNotStopTheWait() {
        start()
        discovery.complete(.failure(.commandFailed("error: mdns unavailable")))
        XCTAssertTrue(results.isEmpty)
        XCTAssertEqual(scheduler.scheduled.count, 1)
    }

    func testAMissingAdbEndsTheWaitAtOnce() {
        start()
        discovery.complete(.failure(.notFound(customPath: nil)))
        XCTAssertEqual(results, [.failure(.notFound(customPath: nil))])
        XCTAssertTrue(scheduler.scheduled.isEmpty)
    }

    func testPairFailureIsReported() {
        controller.pairResult = .failure(.commandFailed("Failed: Wrong password or connection was dropped."))
        start()
        discovery.complete(.success([service(credentials.name)]))
        XCTAssertEqual(results, [.failure(.commandFailed("Failed: Wrong password or connection was dropped."))])
    }

    func testCancelStopsEverythingAndNeverCallsBack() {
        start()
        discovery.complete(.success([]))
        pairer.cancel()
        XCTAssertTrue(scheduler.scheduled.allSatisfy { $0.task.isCancelled })

        // Even a timer that already fired, or a discovery already in flight, must not do anything.
        scheduler.scheduled.first?.action()
        XCTAssertTrue(discovery.pending.isEmpty, "no new discovery after cancel")
        XCTAssertTrue(results.isEmpty)
    }

    func testAResultFromACancelledDiscoveryIsDropped() {
        start()
        pairer.cancel()
        discovery.complete(.success([service(credentials.name)]))
        XCTAssertTrue(controller.qrPairCalls.isEmpty)
        XCTAssertTrue(results.isEmpty)
    }

    func testStartingAgainCancelsTheOldSession() {
        start()
        discovery.complete(.success([]))
        let first = scheduler.scheduled[0]
        start()
        XCTAssertTrue(first.task.isCancelled)
        first.action()
        XCTAssertEqual(discovery.pending.count, 1, "only the new session's discovery is pending")
    }
}
