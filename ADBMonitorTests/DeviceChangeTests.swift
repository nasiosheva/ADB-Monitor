//
//  DeviceChangeTests.swift
//  ADBMonitorTests
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import XCTest
@testable import ADBMonitor

final class DeviceChangeDetectorTests: XCTestCase {

    private var detector = DeviceChangeDetector()
    private let pixel = Sample.device("PIXEL")
    private let samsung = Sample.device("SAMSUNG", model: "SM A107F")

    func testTheFirstListOnlySetsTheBaseline() {
        XCTAssertEqual(detector.update(with: [pixel, samsung]), [])
        XCTAssertEqual(detector.update(with: [pixel, samsung]), [])
    }

    func testAnEmptyFirstListIsAlsoABaseline() {
        XCTAssertEqual(detector.update(with: []), [])
        XCTAssertEqual(detector.update(with: [pixel]), [.connected(pixel)])
    }

    func testANewDeviceIsReportedAsConnectedOnce() {
        _ = detector.update(with: [pixel])
        XCTAssertEqual(detector.update(with: [pixel, samsung]), [.connected(samsung)])
        XCTAssertEqual(detector.update(with: [pixel, samsung]), [])
    }

    func testAMissingDeviceIsOnlyDisconnectedAfterTwoListsInARow() {
        _ = detector.update(with: [pixel, samsung])
        XCTAssertEqual(detector.update(with: [pixel]), [], "one missing list can be an adb restart")
        XCTAssertEqual(detector.update(with: [pixel]), [.disconnected(samsung)])
        XCTAssertEqual(detector.update(with: [pixel]), [], "and it is reported only once")
    }

    func testADeviceThatComesBackAfterOneMissIsNeverReported() {
        _ = detector.update(with: [pixel])
        XCTAssertEqual(detector.update(with: []), [])
        XCTAssertEqual(detector.update(with: [pixel]), [])
        XCTAssertEqual(detector.update(with: []), [], "the miss counter started again")
        XCTAssertEqual(detector.update(with: [pixel]), [])
    }

    func testADeviceThatReturnsAfterBeingDisconnectedIsConnectedAgain() {
        _ = detector.update(with: [pixel])
        _ = detector.update(with: [])
        XCTAssertEqual(detector.update(with: []), [.disconnected(pixel)])
        XCTAssertEqual(detector.update(with: [pixel]), [.connected(pixel)])
    }

    func testAStateChangeOfAKnownDeviceIsNotAChange() {
        _ = detector.update(with: [Sample.device("PIXEL", state: .unauthorized)])
        XCTAssertEqual(detector.update(with: [Sample.device("PIXEL", state: .device)]), [])
    }

    func testTheDisconnectedEventCarriesTheNewestKnownDevice() {
        _ = detector.update(with: [Sample.device("PIXEL", model: nil)])
        _ = detector.update(with: [pixel])
        _ = detector.update(with: [])
        XCTAssertEqual(detector.update(with: []), [.disconnected(pixel)], "the model name was learned later")
    }

    func testDisconnectsComeFirstThenConnectsEachSortedBySerial() {
        let a = Sample.device("A"), b = Sample.device("B"), c = Sample.device("C"), d = Sample.device("D")
        var quick = DeviceChangeDetector(missesBeforeDisconnect: 1)
        _ = quick.update(with: [b, a])
        XCTAssertEqual(quick.update(with: [d, c]),
                       [.disconnected(a), .disconnected(b), .connected(c), .connected(d)])
    }

    func testOneMissIsEnoughWhenConfiguredSo() {
        var quick = DeviceChangeDetector(missesBeforeDisconnect: 1)
        _ = quick.update(with: [pixel])
        XCTAssertEqual(quick.update(with: []), [.disconnected(pixel)])
    }

    func testDuplicateSerialsInOneListAreCountedOnce() {
        _ = detector.update(with: [])
        XCTAssertEqual(detector.update(with: [pixel, pixel]), [.connected(pixel)])
    }
}

@MainActor
final class DeviceChangeNotifierTests: XCTestCase {

    private var center: NotificationCenter!
    private var notifier: FakeDeviceNotifier!
    private let pixel = Sample.device("PIXEL")
    private let samsung = Sample.device("SAMSUNG")

    override func setUp() {
        super.setUp()
        center = NotificationCenter()
        notifier = FakeDeviceNotifier()
    }

    private func makeTracker(_ settings: DeviceNotificationProviding) -> DeviceChangeNotifier {
        DeviceChangeNotifier(settings: settings, notifier: notifier,
                             detector: DeviceChangeDetector(missesBeforeDisconnect: 1), notificationCenter: center)
    }

    func testChangesAreNotifiedWhenEnabled() {
        let tracker = makeTracker(StubNotificationSettings(deviceNotificationsEnabled: true))
        tracker.track(devices: [pixel])
        tracker.track(devices: [pixel, samsung])
        tracker.track(devices: [samsung])
        XCTAssertEqual(notifier.notified, [.connected(samsung), .disconnected(pixel)])
    }

    func testDevicesThatWereAlreadyThereAreNotAnnounced() {
        let tracker = makeTracker(StubNotificationSettings(deviceNotificationsEnabled: true))
        tracker.track(devices: [pixel, samsung])
        XCTAssertTrue(notifier.notified.isEmpty)
    }

    func testNothingIsNotifiedWhenDisabled() {
        let tracker = makeTracker(StubNotificationSettings(deviceNotificationsEnabled: false))
        tracker.track(devices: [pixel])
        tracker.track(devices: [])
        XCTAssertTrue(notifier.notified.isEmpty)
    }

    func testTurningNotificationsOnLaterDoesNotAnnounceTheDevicesThatWereAlreadyConnected() {
        let settings = MutableNotificationSettings(false)
        let tracker = makeTracker(settings)
        tracker.track(devices: [pixel])          // tracked silently
        tracker.track(devices: [pixel, samsung]) // also silent

        settings.deviceNotificationsEnabled = true
        tracker.track(devices: [pixel, samsung])
        XCTAssertTrue(notifier.notified.isEmpty)

        tracker.track(devices: [samsung])
        XCTAssertEqual(notifier.notified, [.disconnected(pixel)])
    }

    func testPermissionIsRequestedWhenThePreferenceIsSavedWithNotificationsOn() {
        let settings = MutableNotificationSettings(false)
        let tracker = makeTracker(settings)

        center.post(name: .preferencesDidChange, object: nil)
        XCTAssertEqual(notifier.prepareCount, 0, "not while notifications are off")

        settings.deviceNotificationsEnabled = true
        center.post(name: .preferencesDidChange, object: nil)
        XCTAssertEqual(notifier.prepareCount, 1)
        withExtendedLifetime(tracker) {}
    }

    func testTheObserverIsRemovedWhenTheTrackerIsReleased() {
        var tracker: DeviceChangeNotifier? = makeTracker(StubNotificationSettings(deviceNotificationsEnabled: true))
        XCTAssertNotNil(tracker)
        tracker = nil
        center.post(name: .preferencesDidChange, object: nil)
        XCTAssertEqual(notifier.prepareCount, 0)
    }
}
