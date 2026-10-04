//
//  DeviceDetailsTrackerTests.swift
//  ADBMonitorTests
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import XCTest
@testable import ADBMonitor

@MainActor
final class DeviceDetailsTrackerTests: XCTestCase {

    private var reader: FakeDetailsReader!
    private var tracker: DeviceDetailsTracker!
    private var clock = Date(timeIntervalSince1970: 1_000)
    private var emitted: [[String: DeviceDetails]] = []

    private let pixel = Sample.device("PIXEL")
    private let samsung = Sample.device("SAMSUNG")
    private let detailsA = DeviceDetails(androidVersion: "12", batteryLevel: 80)

    override func setUp() {
        super.setUp()
        reader = FakeDetailsReader()
        clock = Date(timeIntervalSince1970: 1_000)
        emitted = []
        tracker = DeviceDetailsTracker(reader: reader, refreshInterval: 60, now: { [unowned self] in clock })
        tracker.onChange = { [unowned self] in emitted.append($0) }
    }

    func testReadsEachReadyDeviceOnce() {
        tracker.track(devices: [pixel, samsung])
        XCTAssertEqual(reader.requested, ["PIXEL", "SAMSUNG"])
    }

    func testOnlyDevicesInTheDeviceStateAreRead() {
        let offline = Sample.device("OFF", state: .offline)
        let unauthorized = Sample.device("UNAUTH", state: .unauthorized)
        let recovery = Sample.device("REC", state: .recovery)
        tracker.track(devices: [offline, unauthorized, recovery, pixel])
        XCTAssertEqual(reader.requested, ["PIXEL"])
    }

    func testEmitsTheDetailsWhenTheReadFinishes() {
        tracker.track(devices: [pixel])
        XCTAssertTrue(emitted.isEmpty, "nothing to show before the read finishes")
        reader.complete(.success(detailsA))
        XCTAssertEqual(emitted, [["PIXEL": detailsA]])
    }

    func testDoesNotReadAgainWhileARequestIsInFlight() {
        tracker.track(devices: [pixel])
        tracker.track(devices: [pixel])
        tracker.track(devices: [pixel])
        XCTAssertEqual(reader.requested.count, 1)
    }

    func testDoesNotReadAgainBeforeTheIntervalPasses() {
        tracker.track(devices: [pixel])
        reader.complete(.success(detailsA))

        clock = clock.addingTimeInterval(59)
        tracker.track(devices: [pixel])
        XCTAssertEqual(reader.requested.count, 1)
    }

    func testReadsAgainAfterTheIntervalAndEmitsOnlyWhenTheValueChanged() {
        tracker.track(devices: [pixel])
        reader.complete(.success(detailsA))

        clock = clock.addingTimeInterval(60)
        tracker.track(devices: [pixel])
        XCTAssertEqual(reader.requested.count, 2)
        reader.complete(.success(detailsA))
        XCTAssertEqual(emitted.count, 1, "an identical answer is not announced again")

        clock = clock.addingTimeInterval(60)
        tracker.track(devices: [pixel])
        reader.complete(.success(DeviceDetails(androidVersion: "12", batteryLevel: 79)))
        XCTAssertEqual(emitted.last?["PIXEL"]?.batteryLevel, 79)
    }

    func testAFailedReadIsNotRetriedBeforeTheInterval() {
        tracker.track(devices: [pixel])
        reader.complete(.failure(.timedOut))
        XCTAssertTrue(emitted.isEmpty)

        clock = clock.addingTimeInterval(30)
        tracker.track(devices: [pixel])
        XCTAssertEqual(reader.requested.count, 1, "a device that cannot answer is not asked on every poll")

        clock = clock.addingTimeInterval(30)
        tracker.track(devices: [pixel])
        XCTAssertEqual(reader.requested.count, 2)
    }

    func testAnEmptyAnswerIsNotShown() {
        tracker.track(devices: [pixel])
        reader.complete(.success(DeviceDetails(androidVersion: nil, batteryLevel: nil)))
        XCTAssertTrue(emitted.isEmpty)
    }

    func testDetailsOfADeviceThatWentAwayAreDroppedAndAnnounced() {
        tracker.track(devices: [pixel, samsung])
        reader.complete(.success(detailsA))
        reader.complete(.success(DeviceDetails(androidVersion: "10", batteryLevel: 50)))
        XCTAssertEqual(emitted.last?.keys.sorted(), ["PIXEL", "SAMSUNG"])

        tracker.track(devices: [samsung])
        XCTAssertEqual(emitted.last?.keys.sorted(), ["SAMSUNG"])
    }

    func testADeviceThatComesBackIsReadAgainRightAway() {
        tracker.track(devices: [pixel])
        reader.complete(.success(detailsA))
        tracker.track(devices: [])            // unplugged
        tracker.track(devices: [pixel])       // plugged in again, well before the interval
        XCTAssertEqual(reader.requested, ["PIXEL", "PIXEL"])
    }

    func testNothingIsAnnouncedWhenNoDeviceHadDetails() {
        tracker.track(devices: [pixel])
        reader.complete(.failure(.timedOut))
        tracker.track(devices: [])
        XCTAssertTrue(emitted.isEmpty)
    }

    func testAnAnswerThatArrivesAfterTheDeviceLeftIsDroppedByTheNextTrack() {
        tracker.track(devices: [pixel])
        tracker.track(devices: [])            // gone while the read is still running
        reader.complete(.success(detailsA))
        XCTAssertEqual(emitted.last?.keys.sorted(), ["PIXEL"], "announced because the read finished")

        tracker.track(devices: [])
        XCTAssertEqual(emitted.last?.count, 0, "and forgotten by the next poll")
    }
}
