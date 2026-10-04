//
//  StatusMenuBuilderTests.swift
//  ADBMonitorTests
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import AppKit
import XCTest
@testable import ADBMonitor

/// Memeriksa isi dan perilaku menu secara struktural. Tampilan visualnya (warna, tata letak) tetap perlu dilihat mata.
@MainActor
final class StatusMenuBuilderTests: XCTestCase {

    private var handler: RecordingMenuHandler!
    /// `NSMenuItem.target` bersifat weak: builder harus tetap hidup selama menu dipakai
    /// (di aplikasi dipegang oleh `StatusBarController`).
    private var builders: [StatusMenuBuilder] = []

    override func setUp() {
        super.setUp()
        handler = RecordingMenuHandler()
        builders = []
    }

    private func makeBuilder(_ language: AppLanguage = .english) -> StatusMenuBuilder {
        let localizer = Localizer(provider: StubLanguage(languagePreference: .explicit(language)),
                                  notificationCenter: NotificationCenter())
        return StatusMenuBuilder(handler: handler, localizer: localizer)
    }

    private func menu(for status: ADBStatus?, language: AppLanguage = .english) -> NSMenu {
        let menu = NSMenu()
        let builder = makeBuilder(language)
        builders.append(builder)
        builder.populate(menu, for: status)
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

    /// Mengirim aksi item persis seperti yang dilakukan AppKit saat diklik.
    private func click(_ item: NSMenuItem, file: StaticString = #filePath, line: UInt = #line) throws {
        let target = try XCTUnwrap(item.target as? NSObject, file: file, line: line)
        let action = try XCTUnwrap(item.action, file: file, line: line)
        _ = target.perform(action, with: item)
    }

    // MARK: Struktur per status

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

    // MARK: Daftar device

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
                        "", "Copy Serial Number", "Restart Device…", "Shut Down Device…"])
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

    // MARK: Aksi

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

    // MARK: Perilaku lain

    func testItemTargetIsWeakSoTheOwnerMustKeepTheBuilderAlive() throws {
        let m = NSMenu()
        // `autoreleasepool` agar objek benar-benar dilepas di sini, bukan menunggu akhir tes.
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
        builder.populate(m, for: nil)
        let first = m.items.count
        builder.populate(m, for: nil)
        builder.populate(m, for: .devices([]))
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
