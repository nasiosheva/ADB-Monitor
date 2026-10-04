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
    private var discovery: FakeWirelessDiscovery!
    private var fastboot: FakeFastbootService!
    private var settings: MutableDiscoverySettings!
    private var scheduler: FakeScheduler!
    private var center: NotificationCenter!
    private var monitor: DeviceMonitor!
    private var emitted: [ADBStatus] = []
    private var emittedWireless: [[WirelessService]] = []

    override func setUp() {
        super.setUp()
        service = FakeADBService()
        discovery = FakeWirelessDiscovery()
        fastboot = FakeFastbootService()
        settings = MutableDiscoverySettings(false)   // the older tests do not touch Wi-Fi discovery
        scheduler = FakeScheduler()
        center = NotificationCenter()
        emitted = []
        emittedWireless = []
        monitor = DeviceMonitor(service: service,
                                discovery: discovery,
                                fastboot: fastboot,
                                discoverySettings: settings,
                                intervalProvider: StubInterval(refreshInterval: 2.5),
                                scheduler: scheduler,
                                notificationCenter: center)
        monitor.onStatusChange = { [unowned self] in emitted.append($0) }
        monitor.onWirelessChange = { [unowned self] in emittedWireless.append($0) }
    }

    private let phone = WirelessService(name: "adb-AAA-aBcDeF", kind: .connect, host: "192.168.1.5", port: 37899)
    private let pairing = WirelessService(name: "adb-BBB-xYz123", kind: .pairing, host: "192.168.1.6", port: 41223)

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

    // MARK: - Wi-Fi discovery

    func testDiscoveryRunsAfterTheDeviceListWhenEnabled() {
        settings.wirelessDiscoveryEnabled = true
        monitor.start()
        XCTAssertTrue(discovery.pending.isEmpty, "penemuan menunggu daftar device")
        service.completeList(.success([]))
        XCTAssertEqual(discovery.pending.count, 1)
    }

    func testDiscoveredServicesAreEmittedAndOnlyOnChange() {
        settings.wirelessDiscoveryEnabled = true
        monitor.start()
        service.completeList(.success([]))
        discovery.complete(.success([phone, pairing]))
        XCTAssertEqual(emittedWireless, [[phone, pairing]])

        scheduler.scheduled[0].action()
        service.completeList(.success([]))
        discovery.complete(.success([phone, pairing]))
        XCTAssertEqual(emittedWireless.count, 1, "daftar yang sama tidak dikirim ulang")

        scheduler.scheduled[1].action()
        service.completeList(.success([]))
        discovery.complete(.success([phone]))
        XCTAssertEqual(emittedWireless.last, [phone])
    }

    func testNothingIsEmittedWhenNothingWasDiscovered() {
        settings.wirelessDiscoveryEnabled = true
        monitor.start()
        service.completeList(.success([]))
        discovery.complete(.success([]))
        XCTAssertTrue(emittedWireless.isEmpty)
    }

    func testServicesThatAreAlreadyConnectedAreFilteredOut() {
        settings.wirelessDiscoveryEnabled = true
        monitor.start()
        let connected = Sample.device("adb-AAA-aBcDeF._adb-tls-connect._tcp")
        service.completeList(.success([connected]))
        discovery.complete(.success([phone, pairing]))
        XCTAssertEqual(emittedWireless, [[pairing]], "yang sudah tersambung tidak ditawarkan lagi")
    }

    func testDiscoveryIsSkippedWhenDisabled() {
        settings.wirelessDiscoveryEnabled = false
        monitor.start()
        service.completeList(.success([]))
        XCTAssertTrue(discovery.pending.isEmpty)
        XCTAssertTrue(emittedWireless.isEmpty)
    }

    func testDiscoveryFailureIsNotAnError() {
        settings.wirelessDiscoveryEnabled = true
        monitor.start()
        service.completeList(.success([]))
        discovery.complete(.failure(.commandFailed("mdns unavailable")))
        XCTAssertEqual(emitted, [.devices([])], "status device tidak terpengaruh")
        XCTAssertTrue(emittedWireless.isEmpty)
    }

    func testAdbFailureSkipsDiscoveryAndClearsThePreviousList() {
        settings.wirelessDiscoveryEnabled = true
        monitor.start()
        service.completeList(.success([]))
        discovery.complete(.success([phone]))

        scheduler.scheduled[0].action()
        service.completeList(.failure(.notFound(customPath: nil)))
        XCTAssertTrue(discovery.pending.isEmpty, "tanpa ADB tidak ada yang bisa ditemukan")
        XCTAssertEqual(emittedWireless.last, [])
    }

    func testTurningDiscoveryOffClearsTheListOnTheNextPoll() {
        settings.wirelessDiscoveryEnabled = true
        monitor.start()
        service.completeList(.success([]))
        discovery.complete(.success([phone]))

        settings.wirelessDiscoveryEnabled = false
        center.post(name: .preferencesDidChange, object: nil)
        service.completeList(.success([]))
        XCTAssertEqual(emittedWireless.last, [])
        XCTAssertTrue(discovery.pending.isEmpty)
    }

    func testPollsNeverOverlapWhileDiscoveryIsPending() {
        settings.wirelessDiscoveryEnabled = true
        monitor.start()
        service.completeList(.success([]))
        monitor.refresh()
        XCTAssertTrue(service.pendingLists.isEmpty, "refresh saat penemuan berjalan tidak boleh memulai poll baru")

        discovery.complete(.success([]))
        XCTAssertEqual(service.pendingLists.count, 1, "poll tambahan berjalan setelah penemuan selesai")
    }

    // MARK: - Fastboot and per-poll callback

    private let bootloaderPhone = FastbootDevice(serial: "ZY22XXXX", mode: "fastboot")

    func testFastbootDevicesAreEmittedAndOnlyOnChange() {
        var emittedFastboot: [[FastbootDevice]] = []
        monitor.onFastbootChange = { emittedFastboot.append($0) }
        fastboot.listResult = .success([bootloaderPhone])

        monitor.start()
        service.completeList(.success([]))
        XCTAssertEqual(emittedFastboot, [[bootloaderPhone]])

        scheduler.scheduled[0].action()
        service.completeList(.success([]))
        XCTAssertEqual(emittedFastboot.count, 1, "the same list is not sent again")

        fastboot.listResult = .success([])
        scheduler.scheduled[1].action()
        service.completeList(.success([]))
        XCTAssertEqual(emittedFastboot.last, [], "unplugging clears the list")
    }

    func testNothingIsEmittedWhenNoFastbootDeviceExists() {
        var emittedFastboot: [[FastbootDevice]] = []
        monitor.onFastbootChange = { emittedFastboot.append($0) }
        monitor.start()
        service.completeList(.success([]))
        XCTAssertTrue(emittedFastboot.isEmpty)
        XCTAssertEqual(fastboot.listCount, 1)
    }

    func testFastbootFailureIsNotAnError() {
        var emittedFastboot: [[FastbootDevice]] = []
        monitor.onFastbootChange = { emittedFastboot.append($0) }
        fastboot.listResult = .failure(.notFound(customPath: nil))
        monitor.start()
        service.completeList(.success([Sample.device()]))
        XCTAssertEqual(emitted, [.devices([Sample.device()])])
        XCTAssertTrue(emittedFastboot.isEmpty)
    }

    func testFastbootIsSkippedAndClearedWhenAdbFails() {
        var emittedFastboot: [[FastbootDevice]] = []
        monitor.onFastbootChange = { emittedFastboot.append($0) }
        fastboot.listResult = .success([bootloaderPhone])
        monitor.start()
        service.completeList(.success([]))
        XCTAssertEqual(fastboot.listCount, 1)

        scheduler.scheduled[0].action()
        service.completeList(.failure(.timedOut))
        XCTAssertEqual(fastboot.listCount, 1, "no fastboot lookup when adb itself fails")
        XCTAssertEqual(emittedFastboot.last, [])
    }

    func testOnPollReportsTheDevicesOfEverySuccessfulPollEvenWhenUnchanged() {
        var polled: [[ADBDevice]] = []
        monitor.onPoll = { polled.append($0) }
        let device = Sample.device()

        monitor.start()
        service.completeList(.success([device]))
        scheduler.scheduled[0].action()
        service.completeList(.success([device]))
        XCTAssertEqual(polled, [[device], [device]])
        XCTAssertEqual(emitted.count, 1, "while onStatusChange fires only on a change")
    }

    func testOnPollIsNotCalledWhenAdbFails() {
        var polled: [[ADBDevice]] = []
        monitor.onPoll = { polled.append($0) }
        monitor.start()
        service.completeList(.failure(.timedOut))
        XCTAssertTrue(polled.isEmpty)
    }
}
