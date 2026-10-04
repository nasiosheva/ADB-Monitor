//
//  StatusMenuBuilderTests.swift
//  ADBMonitorTests
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import AppKit
import XCTest
@testable import ADBMonitor

/// Checks the content and behavior of the menu structurally. The visual look (colors, layout) still needs a human eye.
@MainActor
final class StatusMenuBuilderTests: XCTestCase {

    private var handler: RecordingMenuHandler!
    /// `NSMenuItem.target` is weak: the builder must stay alive while the menu is in use
    /// (in the app it is owned by `StatusBarController`).
    private var builders: [StatusMenuBuilder] = []
    private var clipboard: RecordingClipboard!

    override func setUp() {
        super.setUp()
        handler = RecordingMenuHandler()
        clipboard = RecordingClipboard()
        builders = []
    }

    private func makeBuilder(_ language: AppLanguage = .english) -> StatusMenuBuilder {
        let localizer = Localizer(provider: StubLanguage(languagePreference: .explicit(language)),
                                  notificationCenter: NotificationCenter())
        return StatusMenuBuilder(handler: handler, localizer: localizer, clipboard: clipboard)
    }

    private func menu(for status: ADBStatus?,
                      wireless: [WirelessService] = [],
                      fastboot: [FastbootDevice] = [],
                      details: [String: DeviceDetails] = [:],
                      language: AppLanguage = .english) -> NSMenu {
        let menu = NSMenu()
        let builder = makeBuilder(language)
        builders.append(builder)
        builder.populate(menu, for: status, wireless: wireless, fastboot: fastboot, details: details)
        return menu
    }

    private func titles(_ menu: NSMenu) -> [String] { menu.items.map(\.title) }

    private func item(_ title: String,
                      in menu: NSMenu,
                      file: StaticString = #filePath,
                      line: UInt = #line) throws -> NSMenuItem {
        try XCTUnwrap(menu.items.first { $0.title == title }, "item \"\(title)\" tidak ada", file: file, line: line)
    }

    private func submenuTitles(of status: ADBStatus, at index: Int = 2) throws -> [String] {
        let m = menu(for: status)
        return titles(try XCTUnwrap(m.items[index].submenu))
    }

    /// Sends an item's action exactly like AppKit does when it is clicked.
    private func click(_ item: NSMenuItem, file: StaticString = #filePath, line: UInt = #line) throws {
        let target = try XCTUnwrap(item.target as? NSObject, file: file, line: line)
        let action = try XCTUnwrap(item.action, file: file, line: line)
        _ = target.perform(action, with: item)
    }

    // MARK: Structure per state

    func testCheckingState() {
        XCTAssertEqual(titles(menu(for: nil)),
                       ["Checking for devices…", "", "Refresh", "Preferences…", "", "Quit ADB Monitor"])
    }

    func testNoDevices() {
        XCTAssertEqual(titles(menu(for: .devices([]))).first, "No devices connected")
    }

    func testADBNotInstalled() {
        XCTAssertEqual(Array(titles(menu(for: .adbNotFound(customPath: nil))).prefix(3)),
                       ["ADB is not installed",
                        "Install it (brew install android-platform-tools)",
                        "or set its path in Preferences."])
    }

    func testCustomPathMissingShowsThePath() {
        XCTAssertEqual(Array(titles(menu(for: .adbNotFound(customPath: "/bad/adb"))).prefix(3)),
                       ["ADB not found at custom path:", "/bad/adb", "Fix it in Preferences."])
    }

    func testFailureShowsLocalizedErrorMessage() {
        XCTAssertEqual(Array(titles(menu(for: .failure(.timedOut))).prefix(2)),
                       ["ADB error", "adb did not respond (timed out)."])
        XCTAssertEqual(Array(titles(menu(for: .failure(.commandFailed("raw text")))).prefix(2)),
                       ["ADB error", "raw text"])
    }

    func testInformationalItemsAreDisabled() {
        let m = menu(for: nil)
        XCTAssertFalse(m.items[0].isEnabled)
    }

    // MARK: Device list

    func testDeviceListHeaderAndItemTitles() {
        let second = Sample.device("BBB", state: .unauthorized, model: "SM A107F")
        let m = menu(for: .devices([Sample.device("AAA"), second]))
        XCTAssertEqual(Array(titles(m).prefix(4)),
                       ["Android Devices (2)", "", "● Pixel 3a (AAA) — Connected", "● SM A107F (BBB) — Unauthorized"])
    }

    func testDeviceItemsHaveASubmenuAndSerialTooltip() throws {
        let m = menu(for: .devices([Sample.device("AAA")]))
        XCTAssertNotNil(m.items[2].submenu)
        XCTAssertEqual(m.items[2].toolTip, "AAA")
    }

    func testStatusDotColorFollowsState() throws {
        let cases: [(ADBDevice.State, NSColor)] = [
            (.device, .systemGreen), (.unauthorized, .systemOrange), (.noPermissions, .systemOrange),
            (.offline, .systemRed), (.recovery, .systemGray), (.unknown("x"), .systemGray),
        ]
        for (state, color) in cases {
            let m = menu(for: .devices([Sample.device(state: state)]))
            let title = try XCTUnwrap(m.items[2].attributedTitle, "\(state) tanpa attributedTitle")
            XCTAssertEqual(title.string.first, "●")
            XCTAssertEqual(title.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor, color, "\(state)")
        }
    }

    func testAttributedTitleKeepsTheFullText() throws {
        let m = menu(for: .devices([Sample.device("AAA")]))
        XCTAssertEqual(m.items[2].attributedTitle?.string, "● Pixel 3a (AAA) — Connected")
    }

    // MARK: Submenu

    func testSubmenuListsAllDetailsThenActions() throws {
        XCTAssertEqual(try submenuTitles(of: .devices([Sample.device("SER1")])),
                       ["Status: Connected", "Serial: SER1", "Connection: USB", "Model: Pixel 3a",
                        "Product: sargo", "Device: sargo", "Transport ID: 2",
                        "", "Copy Serial Number", "Copy ADB Command Prefix", "Switch to Wi-Fi",
                        "Open Developer Options",
                        "Restart Device…", "Shut Down Device…",
                        "", "Reboot to Recovery…", "Reboot to Bootloader…", "Reboot to Download Mode…"])
    }

    func testSubmenuOmitsMissingFields() throws {
        let bare = ADBDevice(serial: "S", state: .offline, model: nil, product: nil, deviceName: nil,
                             transportID: nil, usbPath: nil)
        let rows = try submenuTitles(of: .devices([bare]))
        XCTAssertEqual(Array(rows.prefix(3)), ["Status: Offline", "Serial: S", "Connection: Unknown"])
        XCTAssertFalse(rows.contains { $0.hasPrefix("Model") || $0.hasPrefix("Product") || $0.hasPrefix("Transport") })
    }

    func testUnauthorizedShowsHint() throws {
        let rows = try submenuTitles(of: .devices([Sample.device(state: .unauthorized)]))
        XCTAssertTrue(rows.contains("Accept the USB debugging prompt on the device."))
    }

    func testConnectedShowsNoHint() throws {
        let rows = try submenuTitles(of: .devices([Sample.device(state: .device)]))
        XCTAssertFalse(rows.contains { $0.contains("debugging prompt") })
    }

    func testPowerItemsEnablementFollowsState() throws {
        func enabled(_ state: ADBDevice.State) throws -> [Bool] {
            let m = menu(for: .devices([Sample.device(state: state)]))
            let sub = try XCTUnwrap(m.items[2].submenu)
            return [try item("Restart Device…", in: sub).isEnabled, try item("Shut Down Device…", in: sub).isEnabled]
        }
        XCTAssertEqual(try enabled(.device), [true, true])
        XCTAssertEqual(try enabled(.recovery), [true, false])
        XCTAssertEqual(try enabled(.offline), [false, false])
        XCTAssertEqual(try enabled(.unauthorized), [false, false])
    }

    // MARK: Actions

    func testCommandItemsInvokeTheHandler() throws {
        let m = menu(for: nil)
        try click(try item("Refresh", in: m))
        try click(try item("Preferences…", in: m))
        try click(try item("Quit ADB Monitor", in: m))
        XCTAssertEqual(handler.refreshCount, 1)
        XCTAssertEqual(handler.preferencesCount, 1)
        XCTAssertEqual(handler.quitCount, 1)
    }

    func testKeyEquivalents() throws {
        let m = menu(for: nil)
        XCTAssertEqual(try item("Refresh", in: m).keyEquivalent, "r")
        XCTAssertEqual(try item("Preferences…", in: m).keyEquivalent, ",")
        XCTAssertEqual(try item("Quit ADB Monitor", in: m).keyEquivalent, "q")
    }

    func testPowerItemsSendTheActionAndTheDevice() throws {
        let device = Sample.device("SER9")
        let m = menu(for: .devices([device]))
        let sub = try XCTUnwrap(m.items[2].submenu)
        try click(try item("Restart Device…", in: sub))
        try click(try item("Shut Down Device…", in: sub))
        XCTAssertEqual(handler.powerRequests.map(\.action), [.restart, .shutdown])
        XCTAssertEqual(handler.powerRequests.map(\.device), [device, device])
    }

    // MARK: Boot modes

    func testBootModeItemsFollowThePowerItemsAfterASeparator() throws {
        let sub = try XCTUnwrap(menu(for: .devices([Sample.device()])).items[2].submenu)
        let rows = titles(sub)
        let restart = try XCTUnwrap(rows.firstIndex(of: "Shut Down Device…"))
        XCTAssertEqual(Array(rows[(restart + 1)...]),
                       ["", "Reboot to Recovery…", "Reboot to Bootloader…", "Reboot to Download Mode…"])
    }

    func testBootModeEnablementFollowsState() throws {
        func enabled(_ state: ADBDevice.State) throws -> [Bool] {
            let sub = try XCTUnwrap(menu(for: .devices([Sample.device(state: state)])).items[2].submenu)
            return try ["Reboot to Recovery…", "Reboot to Bootloader…", "Reboot to Download Mode…"]
                .map { try item($0, in: sub).isEnabled }
        }
        XCTAssertEqual(try enabled(.device), [true, true, true])
        XCTAssertEqual(try enabled(.recovery), [true, true, false])
        XCTAssertEqual(try enabled(.offline), [false, false, false])
        XCTAssertEqual(try enabled(.unauthorized), [false, false, false])
    }

    func testBootModeItemsSendTheActionAndTheDevice() throws {
        let device = Sample.device("SER9")
        let sub = try XCTUnwrap(menu(for: .devices([device])).items[2].submenu)
        try click(try item("Reboot to Recovery…", in: sub))
        try click(try item("Reboot to Bootloader…", in: sub))
        try click(try item("Reboot to Download Mode…", in: sub))
        XCTAssertEqual(handler.powerRequests.map(\.action), [.rebootRecovery, .rebootBootloader, .rebootDownload])
        XCTAssertEqual(handler.powerRequests.map(\.device), [device, device, device])
    }

    // MARK: Copy items

    func testCopyItemsPutTheRightTextOnTheClipboard() throws {
        let sub = try XCTUnwrap(menu(for: .devices([Sample.device("SER9")])).items[2].submenu)
        try click(try item("Copy Serial Number", in: sub))
        try click(try item("Copy ADB Command Prefix", in: sub))
        XCTAssertEqual(clipboard.copied, ["SER9", "adb -s SER9"])
    }

    func testCopyAddressIsOnlyOfferedForAPlainHostAndPortSerial() throws {
        func hasCopyAddress(_ device: ADBDevice) throws -> Bool {
            let sub = try XCTUnwrap(menu(for: .devices([device])).items[2].submenu)
            return titles(sub).contains("Copy Address")
        }
        XCTAssertFalse(try hasCopyAddress(Sample.device("SER9")), "USB serial")
        XCTAssertFalse(try hasCopyAddress(Sample.device("adb-R9CN4057BXJ-aBcDeF._adb-tls-connect._tcp")),
                       "an mDNS serial is not an address that can be given to adb connect")
        XCTAssertTrue(try hasCopyAddress(Sample.device("192.168.1.3:5555", usbPath: nil)))
    }

    func testCopyAddressCopiesTheSerial() throws {
        let device = Sample.device("192.168.1.3:5555", usbPath: nil)
        let sub = try XCTUnwrap(menu(for: .devices([device])).items[2].submenu)
        try click(try item("Copy Address", in: sub))
        XCTAssertEqual(clipboard.copied, ["192.168.1.3:5555"])
    }

    // MARK: Device details

    func testDetailRowsShowTheVersionAndBatteryWhenKnown() throws {
        let m = menu(for: .devices([Sample.device("SER9")]),
                     details: ["SER9": DeviceDetails(androidVersion: "12", batteryLevel: 87)])
        let rows = titles(try XCTUnwrap(m.items[2].submenu))
        XCTAssertTrue(rows.contains("Android version: 12"))
        XCTAssertTrue(rows.contains("Battery: 87%"))
    }

    func testDetailRowsAreLeftOutWhenUnknownOrForAnotherDevice() throws {
        let other = ["OTHER": DeviceDetails(androidVersion: "12", batteryLevel: 87)]
        let rows = titles(try XCTUnwrap(menu(for: .devices([Sample.device("SER9")]), details: other).items[2].submenu))
        XCTAssertFalse(rows.contains { $0.hasPrefix("Android version") || $0.hasPrefix("Battery") })

        let partial = ["SER9": DeviceDetails(androidVersion: "12", batteryLevel: nil)]
        let partialRows = titles(try XCTUnwrap(menu(for: .devices([Sample.device("SER9")]), details: partial)
            .items[2].submenu))
        XCTAssertTrue(partialRows.contains("Android version: 12"))
        XCTAssertFalse(partialRows.contains { $0.hasPrefix("Battery") })
    }

    // MARK: Fastboot section

    private let fastbootDevice = FastbootDevice(serial: "ZY22XXXX", mode: "fastboot")

    func testNoFastbootSectionWithoutFastbootDevices() {
        XCTAssertFalse(titles(menu(for: .devices([Sample.device()]))).contains { $0.contains("Fastboot") })
    }

    func testFastbootSectionListsTheDevicesAfterTheAdbDevices() {
        let m = menu(for: .devices([Sample.device("AAA")]), fastboot: [fastbootDevice])
        XCTAssertEqual(Array(titles(m).prefix(6)),
                       ["Android Devices (1)", "", "● Pixel 3a (AAA) — Connected", "",
                        "Fastboot Devices (1)", "● ZY22XXXX — Fastboot"])
    }

    func testFastbootSectionAlsoShowsWhenNoAdbDeviceIsConnected() {
        let m = menu(for: .devices([]), fastboot: [fastbootDevice])
        XCTAssertTrue(titles(m).contains("Fastboot Devices (1)"))
        XCTAssertTrue(titles(m).contains("● ZY22XXXX — Fastboot"))
    }

    func testFastbootDotIsPurple() throws {
        let m = menu(for: .devices([]), fastboot: [fastbootDevice])
        let entry = try item("● ZY22XXXX — Fastboot", in: m)
        XCTAssertEqual(entry.attributedTitle?.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor,
                       .systemPurple)
    }

    func testFastbootSubmenuHasInfoCopyAndReboot() throws {
        let m = menu(for: .devices([]), fastboot: [fastbootDevice])
        let sub = try XCTUnwrap(try item("● ZY22XXXX — Fastboot", in: m).submenu)
        XCTAssertEqual(titles(sub), ["Status: Fastboot", "Serial: ZY22XXXX", "", "Copy Serial Number",
                                     "Reboot Device…"])
    }

    func testFastbootSubmenuActions() throws {
        let m = menu(for: .devices([]), fastboot: [fastbootDevice])
        let sub = try XCTUnwrap(try item("● ZY22XXXX — Fastboot", in: m).submenu)
        try click(try item("Copy Serial Number", in: sub))
        try click(try item("Reboot Device…", in: sub))
        XCTAssertEqual(clipboard.copied, ["ZY22XXXX"])
        XCTAssertEqual(handler.fastbootReboots, [fastbootDevice])
    }

    func testNoFastbootSectionWhenAdbFails() {
        let m = menu(for: .failure(.timedOut), fastboot: [fastbootDevice])
        XCTAssertFalse(titles(m).contains { $0.contains("Fastboot") })
    }

    // MARK: Restart ADB server

    func testRestartServerItemIsOnlyShownWhenAdbIsInstalled() {
        XCTAssertTrue(titles(menu(for: .devices([]))).contains("Restart ADB Server…"))
        XCTAssertTrue(titles(menu(for: .failure(.timedOut))).contains("Restart ADB Server…"))
        XCTAssertFalse(titles(menu(for: .adbNotFound(customPath: nil))).contains("Restart ADB Server…"))
        XCTAssertFalse(titles(menu(for: nil)).contains("Restart ADB Server…"))
    }

    func testRestartServerItemSitsBetweenPreferencesAndQuit() {
        let all = titles(menu(for: .devices([])))
        XCTAssertEqual(Array(all.suffix(4)), ["Preferences…", "Restart ADB Server…", "", "Quit ADB Monitor"])
    }

    func testRestartServerItemInvokesTheHandler() throws {
        try click(try item("Restart ADB Server…", in: menu(for: .devices([]))))
        XCTAssertEqual(handler.restartServerCount, 1)
    }

    // MARK: New strings follow the language

    func testNewItemsFollowTheSelectedLanguage() throws {
        let m = menu(for: .devices([Sample.device("AAA")]), fastboot: [fastbootDevice],
                     details: ["AAA": DeviceDetails(androidVersion: "12", batteryLevel: 5)], language: .indonesian)
        XCTAssertTrue(titles(m).contains("Restart Server ADB…"))
        XCTAssertTrue(titles(m).contains("Perangkat Fastboot (1)"))
        let sub = titles(try XCTUnwrap(m.items[2].submenu))
        XCTAssertTrue(sub.contains("Versi Android: 12"))
        XCTAssertTrue(sub.contains("Baterai: 5%"))
        XCTAssertTrue(sub.contains("Salin Awalan Perintah ADB"))
        XCTAssertTrue(sub.contains("Reboot ke Recovery…"))
    }

    // MARK: Other behavior

    func testItemTargetIsWeakSoTheOwnerMustKeepTheBuilderAlive() throws {
        let m = NSMenu()
        // `autoreleasepool` so the object is really released here, not at the end of the test.
        try autoreleasepool {
            let builder = makeBuilder()
            builder.populate(m, for: nil)
            XCTAssertNotNil(try item("Refresh", in: m).target, "selama builder hidup, target terisi")
        }
        XCTAssertNil(try item("Refresh", in: m).target, "setelah builder dilepas, target menjadi nil (weak)")
    }

    func testPopulateRefillsTheSameMenuWithoutAccumulating() {
        let builder = makeBuilder()
        let m = NSMenu()
        builder.populate(m, for: .devices([Sample.device()]))
        let first = m.items.count
        builder.populate(m, for: .devices([Sample.device()]))
        builder.populate(m, for: .devices([Sample.device()]))
        XCTAssertEqual(m.items.count, first)
    }

    func testMenuFollowsTheSelectedLanguage() throws {
        let m = menu(for: .devices([Sample.device("AAA")]), language: .indonesian)
        XCTAssertEqual(m.items[0].title, "Perangkat Android (1)")
        XCTAssertEqual(m.items[2].title, "● Pixel 3a (AAA) — Terhubung")
        XCTAssertNoThrow(try item("Segarkan", in: m))
    }

    func testEveryLanguageBuildsAMenuWithNoEmptyCommandTitles() {
        for language in AppLanguage.allCases {
            let m = menu(for: .devices([Sample.device()]), language: language)
            let nonSeparators = m.items.filter { !$0.isSeparatorItem }
            XCTAssertTrue(nonSeparators.allSatisfy { !$0.title.isEmpty }, "\(language.rawValue)")
        }
    }

    // MARK: - Developer options

    func testDeveloperOptionsItemIsEnabledOnlyForReadyDevices() throws {
        func enabled(_ state: ADBDevice.State) throws -> Bool {
            let m = menu(for: .devices([Sample.device(state: state)]))
            return try item("Open Developer Options", in: try XCTUnwrap(m.items[2].submenu)).isEnabled
        }
        XCTAssertTrue(try enabled(.device))
        for state in [ADBDevice.State.offline, .unauthorized, .recovery, .noPermissions, .bootloader] {
            XCTAssertFalse(try enabled(state), "\(state)")
        }
    }

    func testDeveloperOptionsItemIsAvailableForWifiDevicesToo() throws {
        let rows = try submenuTitles(of: .devices([Sample.device("192.168.1.5:5555", usbPath: nil)]))
        XCTAssertTrue(rows.contains("Open Developer Options"))
    }

    func testClickingDeveloperOptionsSendsTheDevice() throws {
        let device = Sample.device("SER5")
        let m = menu(for: .devices([device]))
        try click(try item("Open Developer Options", in: try XCTUnwrap(m.items[2].submenu)))
        XCTAssertEqual(handler.developerOptionsRequests, [device])
    }

    func testDeveloperOptionsItemFollowsTheSelectedLanguage() throws {
        let m = menu(for: .devices([Sample.device()]), language: .indonesian)
        XCTAssertNoThrow(try item("Buka Opsi Pengembang", in: try XCTUnwrap(m.items[2].submenu)))
    }

    // MARK: - Wi-Fi

    private let connectService = WirelessService(name: "adb-R9CN4057BXJ-aBcDeF", kind: .connect,
                                                 host: "192.168.1.5", port: 37899)
    private let pairingService = WirelessService(name: "adb-R9CN4057BXJ-xYz123", kind: .pairing,
                                                 host: "192.168.1.5", port: 41223)

    func testWirelessSectionListsDiscoveredServices() {
        let m = menu(for: .devices([]), wireless: [connectService, pairingService])
        XCTAssertEqual(titles(m), ["No devices connected", "",
                                   "Available over Wi-Fi (2)",
                                   "Connect to R9CN4057BXJ (192.168.1.5:37899)",
                                   "Pair with R9CN4057BXJ (192.168.1.5:41223)…",
                                   "", "Connect to IP Address…", "Pair Device…", "Pair with QR Code…",
                                   "", "Refresh", "Preferences…", "Restart ADB Server…", "", "Quit ADB Monitor"])
    }

    func testNoWirelessHeaderWhenNothingWasDiscovered() {
        XCTAssertFalse(titles(menu(for: .devices([Sample.device()]))).contains { $0.hasPrefix("Available over") })
    }

    func testManualWirelessCommandsAreShownEvenWithoutDiscovery() {
        XCTAssertTrue(titles(menu(for: .devices([]))).contains("Connect to IP Address…"))
        XCTAssertTrue(titles(menu(for: .devices([]))).contains("Pair Device…"))
    }

    func testWirelessItemsAreHiddenWhenAdbIsUnavailable() {
        for status in [ADBStatus?.none, .adbNotFound(customPath: nil), .failure(.timedOut)] {
            let all = titles(menu(for: status, wireless: [connectService]))
            XCTAssertFalse(all.contains("Connect to IP Address…"), "\(String(describing: status))")
            XCTAssertFalse(all.contains { $0.hasPrefix("Available over") })
        }
    }

    func testClickingWirelessItemsInvokesTheHandler() throws {
        let m = menu(for: .devices([]), wireless: [connectService, pairingService])
        try click(try item("Connect to R9CN4057BXJ (192.168.1.5:37899)", in: m))
        try click(try item("Pair with R9CN4057BXJ (192.168.1.5:41223)…", in: m))
        try click(try item("Connect to IP Address…", in: m))
        try click(try item("Pair Device…", in: m))
        try click(try item("Pair with QR Code…", in: m))
        XCTAssertEqual(handler.connectAddresses, ["192.168.1.5:37899"])
        XCTAssertEqual(handler.pairingRequests.count, 2)
        XCTAssertEqual(handler.pairingRequests[0], "192.168.1.5:41223")
        XCTAssertNil(handler.pairingRequests[1] ?? nil, "pairing manual tanpa alamat terisi")
        XCTAssertEqual(handler.connectByAddressCount, 1)
        XCTAssertEqual(handler.qrPairingRequestCount, 1)
    }

    func testNetworkDeviceOffersDisconnectOnly() throws {
        let rows = try submenuTitles(of: .devices([Sample.device("192.168.1.5:5555", usbPath: nil)]))
        XCTAssertTrue(rows.contains("Disconnect"))
        XCTAssertFalse(rows.contains("Switch to Wi-Fi"))
    }

    func testReadyUSBDeviceOffersSwitchToWifiOnly() throws {
        let rows = try submenuTitles(of: .devices([Sample.device("USB1", state: .device)]))
        XCTAssertTrue(rows.contains("Switch to Wi-Fi"))
        XCTAssertFalse(rows.contains("Disconnect"))
    }

    func testOtherDevicesOfferNeitherWirelessAction() throws {
        let cases = [Sample.device("USB1", state: .offline),
                     Sample.device("USB2", state: .unauthorized),
                     Sample.device("emulator-5554", usbPath: nil)]
        for device in cases {
            let rows = try submenuTitles(of: .devices([device]))
            XCTAssertFalse(rows.contains("Switch to Wi-Fi") || rows.contains("Disconnect"), device.serial)
        }
    }

    func testDisconnectAndSwitchItemsSendTheDevice() throws {
        let wifi = Sample.device("192.168.1.5:5555", usbPath: nil)
        let usb = Sample.device("USB1")
        let m = menu(for: .devices([wifi, usb]))
        try click(try item("Disconnect", in: try XCTUnwrap(m.items[2].submenu)))
        try click(try item("Switch to Wi-Fi", in: try XCTUnwrap(m.items[3].submenu)))
        XCTAssertEqual(handler.disconnects, [wifi])
        XCTAssertEqual(handler.switches, [usb])
    }

    func testWirelessItemsFollowTheSelectedLanguage() {
        let m = menu(for: .devices([]), wireless: [connectService], language: .indonesian)
        XCTAssertTrue(titles(m).contains("Tersedia lewat Wi-Fi (1)"))
        XCTAssertTrue(titles(m).contains("Hubungkan ke R9CN4057BXJ (192.168.1.5:37899)"))
        XCTAssertTrue(titles(m).contains("Hubungkan ke Alamat IP…"))
    }
}

@MainActor
final class DeviceStateStyleTests: XCTestCase {

    func testHintKeys() {
        XCTAssertEqual(ADBDevice.State.unauthorized.hintKey, .hintUnauthorized)
        XCTAssertEqual(ADBDevice.State.noPermissions.hintKey, .hintNoPermissions)
        XCTAssertEqual(ADBDevice.State.offline.hintKey, .hintOffline)
        XCTAssertNil(ADBDevice.State.device.hintKey)
        XCTAssertNil(ADBDevice.State.recovery.hintKey)
    }

    func testMenuTitleColorsOnlyTheDot() throws {
        let title = ADBDevice.State.offline.menuTitle("Text")
        XCTAssertEqual(title.string, "● Text")
        XCTAssertEqual(title.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor, .systemRed)
        XCTAssertNil(title.attribute(.foregroundColor, at: 3, effectiveRange: nil),
                     "teks biasa harus memakai warna menu bawaan agar tetap terbaca saat disorot")
    }
}
