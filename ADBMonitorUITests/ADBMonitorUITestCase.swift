//
//  ADBMonitorUITestCase.swift
//  ADBMonitorUITests
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import XCTest

/// Base of all UI tests. The app is launched in test mode (`-ui-testing`): `adb` is simulated by
/// `FakeADBWorld`, and every adb command is recorded in a log file that is read here.
///
/// What to know about the accessibility tree of this menu bar app:
/// - Menu items are found by `title`, not `label`. Command items get an automatic `identifier` from the selector name.
/// - The submenus of **all** devices are in the tree at once (with a zero frame), so an action item must be looked up
///   inside the intended device item, not across the whole `app.menuItems`.
class ADBMonitorUITestCase: XCTestCase {

    var app: XCUIApplication!
    private var logURL: URL!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        logURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("adbmonitor-uitest-\(UUID().uuidString).log")
    }

    override func tearDown() {
        app?.terminate()
        try? FileManager.default.removeItem(at: logURL)
        super.tearDown()
    }

    // MARK: - Launching

    @discardableResult
    func launch(scenario: String = "devices", language: String = "en") -> XCUIApplication {
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-ui-scenario", scenario, "-ui-language", language]
        app.launchEnvironment["ADBMONITOR_UITEST_LOG"] = logURL.path
        app.launch()
        XCTAssertTrue(statusItem.waitForExistence(timeout: 10), "item menu bar tidak muncul")
        return app
    }

    var statusItem: XCUIElement { app.menuBars.statusItems.firstMatch }

    // MARK: - Menu

    /// Opens the dropdown and waits until its command items exist.
    func openMenu(file: StaticString = #filePath, line: UInt = #line) {
        statusItem.click()
        XCTAssertTrue(app.menuItems["refreshSelected"].waitForExistence(timeout: 5), "menu tidak terbuka",
                      file: file, line: line)
    }

    func closeMenu() {
        app.typeKey(.escape, modifierFlags: [])
    }

    func menuItem(_ title: String) -> XCUIElement {
        app.menuItems.matching(NSPredicate(format: "title == %@", title)).firstMatch
    }

    func menuItem(containing fragment: String) -> XCUIElement {
        app.menuItems.matching(NSPredicate(format: "title CONTAINS %@", fragment)).firstMatch
    }

    /// Device item in the dropdown, found by serial (or another part of the title).
    func deviceItem(_ fragment: String) -> XCUIElement { menuItem(containing: fragment) }

    /// Item inside a specific device's submenu. The submenu opens by clicking its device item.
    func submenuItem(_ title: String, of device: XCUIElement) -> XCUIElement {
        device.menuItems.matching(NSPredicate(format: "title == %@", title)).firstMatch
    }

    /// Opens a device's submenu and returns the item inside it.
    func openSubmenu(of fragment: String, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let device = deviceItem(fragment)
        XCTAssertTrue(device.waitForExistence(timeout: 5), "device \(fragment) tidak ada di menu", file: file, line: line)
        device.click()
        return device
    }

    /// Clicks an action item in a device submenu (the menu closes afterwards).
    func chooseDeviceAction(_ title: String, device fragment: String, file: StaticString = #filePath, line: UInt = #line) {
        openMenu(file: file, line: line)
        let device = openSubmenu(of: fragment, file: file, line: line)
        let action = submenuItem(title, of: device)
        XCTAssertTrue(action.waitForExistence(timeout: 5), "aksi \(title) tidak ada", file: file, line: line)
        action.click()
    }

    // MARK: - Dialog

    var dialog: XCUIElement { app.dialogs.firstMatch }

    @discardableResult
    func waitForDialog(file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        XCTAssertTrue(dialog.waitForExistence(timeout: 8), "dialog tidak muncul", file: file, line: line)
        return dialog
    }

    func dialogTexts() -> [String] {
        dialog.staticTexts.allElementsBoundByIndex.compactMap { $0.value as? String }
    }

    func clickDialogButton(_ title: String, file: StaticString = #filePath, line: UInt = #line) {
        let button = dialog.buttons[title]
        XCTAssertTrue(button.waitForExistence(timeout: 5), "tombol \(title) tidak ada", file: file, line: line)
        button.click()
    }

    func waitForNoDialog(file: StaticString = #filePath, line: UInt = #line) {
        let gone = expectation(for: NSPredicate(format: "count == 0"), evaluatedWith: app.dialogs)
        wait(for: [gone], timeout: 8)
    }

    // MARK: - adb command log

    func commands() -> [String] {
        let text = (try? String(contentsOf: logURL, encoding: .utf8)) ?? ""
        return text.split(separator: "\n").map(String.init)
    }

    func hasCommand(_ fragment: String) -> Bool { commands().contains { $0.contains(fragment) } }

    /// Waits until an adb command containing `fragment` shows up in the log.
    func waitForCommand(_ fragment: String, timeout: TimeInterval = 8,
                        file: StaticString = #filePath, line: UInt = #line) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if hasCommand(fragment) { return }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        XCTFail("perintah \"\(fragment)\" tidak pernah dijalankan. Log:\n\(commands().joined(separator: "\n"))",
                file: file, line: line)
    }

    /// Makes sure the command is NOT run, after waiting briefly so a failure can show up.
    func assertNoCommand(_ fragment: String, waiting: TimeInterval = 1.5,
                         file: StaticString = #filePath, line: UInt = #line) {
        RunLoop.current.run(until: Date().addingTimeInterval(waiting))
        XCTAssertFalse(hasCommand(fragment), "perintah \"\(fragment)\" seharusnya tidak dijalankan. Log:\n\(commands().joined(separator: "\n"))",
                       file: file, line: line)
    }

    /// Waits until the menu bar item title (the device count) becomes `title`, for example " 4".
    func waitForStatusTitle(_ title: String, timeout: TimeInterval = 8,
                            file: StaticString = #filePath, line: UInt = #line) {
        let done = expectation(for: NSPredicate(format: "title == %@", title), evaluatedWith: statusItem)
        wait(for: [done], timeout: timeout)
    }
}
