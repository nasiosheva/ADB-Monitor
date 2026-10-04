//
//  WirelessCoordinatorTests.swift
//  ADBMonitorTests
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import XCTest
@testable import ADBMonitor

@MainActor
final class WirelessCoordinatorTests: XCTestCase {

    private var controller: FakeWirelessController!
    private var switcher: FakeWirelessSwitcher!
    private var prompts: FakeWirelessPrompter!
    private var alerts: FakeAlerts!
    private var monitor: FakeMonitor!
    private var log: CallLog!
    private var coordinator: WirelessCoordinator!

    private func english(_ key: L10nKey) -> String { Translations.english[key] ?? "" }

    override func setUp() {
        super.setUp()
        log = CallLog()
        controller = FakeWirelessController()
        controller.log = log
        switcher = FakeWirelessSwitcher()
        switcher.log = log
        prompts = FakeWirelessPrompter()
        alerts = FakeAlerts()
        alerts.log = log
        monitor = FakeMonitor()
        monitor.log = log
        let localizer = Localizer(provider: StubLanguage(languagePreference: .explicit(.english)),
                                  notificationCenter: NotificationCenter())
        coordinator = WirelessCoordinator(controller: controller, switcher: switcher, prompts: prompts,
                                          alerts: alerts, monitor: monitor, localizer: localizer)
    }

    // MARK: Connect dari hasil penemuan

    func testConnectToDiscoveredServiceConnectsAndRefreshes() {
        coordinator.statusMenu(didRequestConnectTo: "192.168.1.5:37899")
        XCTAssertEqual(controller.connectCalls, ["192.168.1.5:37899"])
        XCTAssertEqual(monitor.refreshCount, 1)
        XCTAssertTrue(alerts.errors.isEmpty)
    }

    func testConnectFailureRefreshesThenShowsAnError() {
        controller.connectResults = [.failure(.commandFailed("failed to connect: Connection refused"))]
        coordinator.statusMenu(didRequestConnectTo: "192.168.1.5:37899")
        XCTAssertEqual(log.entries, ["connect", "refresh", "error"], "refresh sebelum dialog modal")
        XCTAssertEqual(alerts.errors.first?.title, "Could not connect to 192.168.1.5:37899")
        XCTAssertEqual(alerts.errors.first?.message, "failed to connect: Connection refused")
    }

    func testNoRouteToHostAddsTheLocalNetworkHint() {
        controller.connectResults = [.failure(.commandFailed("failed to connect to '1.2.3.4:5555': No route to host"))]
        coordinator.statusMenu(didRequestConnectTo: "1.2.3.4:5555")
        let message = alerts.errors.first?.message ?? ""
        XCTAssertTrue(message.hasPrefix("failed to connect to '1.2.3.4:5555': No route to host"))
        XCTAssertTrue(message.hasSuffix(english(.errorNoRouteHint)))
    }

    func testOtherFailuresDoNotGetTheLocalNetworkHint() {
        let refused = "failed to connect to '1.2.3.4:5555': Connection refused"
        controller.connectResults = [.failure(.commandFailed(refused))]
        coordinator.statusMenu(didRequestConnectTo: "1.2.3.4:5555")
        XCTAssertEqual(alerts.errors.first?.message, refused)
    }

    // MARK: Connect manual

    func testManualConnectNormalizesTheAddress() {
        prompts.connectAnswer = " 192.168.1.5 "
        coordinator.statusMenuDidRequestConnectByAddress()
        XCTAssertEqual(prompts.connectAsked, 1)
        XCTAssertEqual(controller.connectCalls, ["192.168.1.5:5555"])
    }

    func testCancellingTheConnectPromptDoesNothing() {
        prompts.connectAnswer = nil
        coordinator.statusMenuDidRequestConnectByAddress()
        XCTAssertTrue(controller.connectCalls.isEmpty)
        XCTAssertEqual(monitor.refreshCount, 0)
        XCTAssertTrue(alerts.errors.isEmpty)
    }

    func testInvalidManualAddressShowsAnErrorWithoutRunningAdb() {
        prompts.connectAnswer = "bad host"
        coordinator.statusMenuDidRequestConnectByAddress()
        XCTAssertTrue(controller.connectCalls.isEmpty)
        XCTAssertEqual(alerts.errors.first?.title, "Could not connect to bad host")
        XCTAssertEqual(alerts.errors.first?.message, english(.errorInvalidAddress))
    }

    // MARK: Pairing

    func testPairingPassesThePrefilledAddressToThePrompt() {
        prompts.pairAnswer = nil
        coordinator.statusMenu(didRequestPairingWith: "192.168.1.5:41223")
        coordinator.statusMenu(didRequestPairingWith: nil)
        XCTAssertEqual(prompts.pairingPrefills.count, 2)
        XCTAssertEqual(prompts.pairingPrefills[0], "192.168.1.5:41223")
        XCTAssertNil(prompts.pairingPrefills[1] ?? nil)
    }

    func testSuccessfulPairingRefreshesAndShowsAnInfoDialog() {
        prompts.pairAnswer = (" 192.168.1.5:41223 ", " 123456 ")
        coordinator.statusMenu(didRequestPairingWith: nil)
        XCTAssertEqual(controller.pairCalls.count, 1)
        XCTAssertEqual(controller.pairCalls.first?.address, "192.168.1.5:41223")
        XCTAssertEqual(controller.pairCalls.first?.code, " 123456 ", "kode diteruskan; service yang memangkasnya")
        XCTAssertEqual(monitor.refreshCount, 1)
        XCTAssertEqual(alerts.infos.first?.title, "Paired")
        XCTAssertEqual(alerts.infos.first?.message,
                       "192.168.1.5:41223 is paired. If it does not appear in the list, connect to it under "
                       + "Available over Wi-Fi.")
        XCTAssertTrue(alerts.errors.isEmpty)
    }

    func testPairingFailureShowsTheAdbMessage() {
        prompts.pairAnswer = ("192.168.1.5:41223", "123456")
        controller.pairResult = .failure(.commandFailed("Failed: Wrong password"))
        coordinator.statusMenu(didRequestPairingWith: nil)
        XCTAssertEqual(alerts.errors.first?.title, "Could not pair with 192.168.1.5:41223")
        XCTAssertEqual(alerts.errors.first?.message, "Failed: Wrong password")
        XCTAssertTrue(alerts.infos.isEmpty)
    }

    func testPairingWithoutAPortIsRejectedBeforeRunningAdb() {
        prompts.pairAnswer = ("192.168.1.5", "123456")
        coordinator.statusMenu(didRequestPairingWith: nil)
        XCTAssertTrue(controller.pairCalls.isEmpty)
        XCTAssertEqual(alerts.errors.first?.message, english(.errorInvalidAddress))
    }

    func testPairingWithABadCodeIsRejectedBeforeRunningAdb() {
        prompts.pairAnswer = ("192.168.1.5:41223", "12ab")
        coordinator.statusMenu(didRequestPairingWith: nil)
        XCTAssertTrue(controller.pairCalls.isEmpty)
        XCTAssertEqual(alerts.errors.first?.message, english(.errorInvalidPairingCode))
    }

    func testCancellingThePairingPromptDoesNothing() {
        prompts.pairAnswer = nil
        coordinator.statusMenu(didRequestPairingWith: nil)
        XCTAssertTrue(controller.pairCalls.isEmpty)
        XCTAssertTrue(alerts.errors.isEmpty && alerts.infos.isEmpty)
    }

    // MARK: Disconnect

    func testDisconnectUsesTheDeviceSerialAndRefreshes() {
        coordinator.statusMenu(didRequestDisconnect: Sample.device("192.168.1.5:5555"))
        XCTAssertEqual(controller.disconnectCalls, ["192.168.1.5:5555"])
        XCTAssertEqual(monitor.refreshCount, 1)
        XCTAssertTrue(alerts.errors.isEmpty)
    }

    func testDisconnectFailureNamesTheDevice() {
        controller.disconnectResult = .failure(.commandFailed("error: no such device"))
        coordinator.statusMenu(didRequestDisconnect: Sample.device("S", model: "Pixel 3a"))
        XCTAssertEqual(alerts.errors.first?.title, "Could not disconnect Pixel 3a")
        XCTAssertEqual(alerts.errors.first?.message, "error: no such device")
    }

    // MARK: USB -> Wi-Fi

    func testSwitchToWirelessUsesTheSwitcherAndRefreshes() {
        coordinator.statusMenu(didRequestSwitchToWireless: Sample.device("SER9"))
        XCTAssertEqual(switcher.serials, ["SER9"])
        XCTAssertEqual(monitor.refreshCount, 1)
        XCTAssertTrue(alerts.errors.isEmpty)
    }

    func testSwitchFailureExplainsTheMissingWifiAddress() {
        switcher.result = .failure(.noWiFiAddress)
        coordinator.statusMenu(didRequestSwitchToWireless: Sample.device("S", model: "Pixel 3a"))
        XCTAssertEqual(alerts.errors.first?.title, "Could not switch Pixel 3a to Wi-Fi")
        XCTAssertEqual(alerts.errors.first?.message, english(.errorNoWiFiAddress))
        XCTAssertEqual(log.entries, ["switch", "refresh", "error"])
    }
}
