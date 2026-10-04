//
//  StatusMenuBuilder.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import AppKit

/// Aksi yang bisa diminta pengguna dari dropdown menu.
@MainActor
protocol StatusMenuActionHandling: AnyObject {
    func statusMenuDidRequestRefresh()
    func statusMenuDidRequestPreferences()
    func statusMenuDidRequestQuit()
    func statusMenu(didRequest action: PowerAction, on device: ADBDevice)
}

/// Mengisi `NSMenu` sesuai `ADBStatus` dan meneruskan klik ke `StatusMenuActionHandling`.
@MainActor
final class StatusMenuBuilder: NSObject {

    private struct PowerRequest {
        let action: PowerAction
        let device: ADBDevice
    }

    private weak var handler: StatusMenuActionHandling?

    init(handler: StatusMenuActionHandling) {
        self.handler = handler
        super.init()
    }

    /// Mengisi ulang menu yang sama (bukan membuat baru) agar menu yang sedang terbuka tidak tertutup.
    func populate(_ menu: NSMenu, for status: ADBStatus?) {
        menu.removeAllItems()
        let items = statusItems(for: status) + [.separator()] + commandItems()
        items.forEach(menu.addItem)
    }

    // MARK: - Status section

    private func statusItems(for status: ADBStatus?) -> [NSMenuItem] {
        guard let status = status else { return [.info("Checking for devices…")] }

        switch status {
        case .devices(let devices):
            return deviceListItems(for: devices)
        case .adbNotFound(let customPath):
            return adbNotFoundItems(customPath: customPath)
        case .failure(let message):
            return [.info("ADB error"), .info(message)]
        }
    }

    private func deviceListItems(for devices: [ADBDevice]) -> [NSMenuItem] {
        guard !devices.isEmpty else { return [.info("No devices connected")] }
        return [.info("Android Devices (\(devices.count))"), .separator()] + devices.map(deviceItem)
    }

    private func adbNotFoundItems(customPath: String?) -> [NSMenuItem] {
        if let customPath = customPath {
            return [.info("ADB not found at custom path:"), .info(customPath), .info("Fix it in Preferences.")]
        }
        return [.info("ADB is not installed"),
                .info("Install it (brew install android-platform-tools)"),
                .info("or set its path in Preferences."),
        ]
    }

    // MARK: - Device item

    private func deviceItem(for device: ADBDevice) -> NSMenuItem {
        let title = "\(device.displayName) (\(device.serial)) — \(device.state.label)"
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.attributedTitle = device.state.menuTitle(title)
        item.toolTip = device.serial
        item.submenu = detailMenu(for: device)
        return item
    }

    private func detailMenu(for device: ADBDevice) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        var items = detailRows(for: device).map { NSMenuItem.info("\($0.label): \($0.value)") }
        if let hint = device.state.hint {
            items += [.separator(), .info(hint)]
        }
        items += [.separator(), copySerialItem(for: device)] + powerItems(for: device)

        items.forEach(menu.addItem)
        return menu
    }

    private func detailRows(for device: ADBDevice) -> [(label: String, value: String)] {
        let rows: [(String, String?)] = [
            ("Status", device.state.label),
            ("Serial", device.serial),
            ("Connection", device.connection.rawValue),
            ("Model", device.model),
            ("Product", device.product),
            ("Device", device.deviceName),
            ("Transport ID", device.transportID),
        ]
        return rows.compactMap { label, value in value.map { (label: label, value: $0) } }
    }

    private func copySerialItem(for device: ADBDevice) -> NSMenuItem {
        .command("Copy Serial Number", action: #selector(copySerialSelected(_:)), target: self,
                 representedObject: device.serial)
    }

    private func powerItems(for device: ADBDevice) -> [NSMenuItem] {
        PowerAction.allCases.map { action in
            let item = NSMenuItem.command(action.menuTitle,
                                          action: #selector(powerActionSelected(_:)),
                                          target: self,
                                          representedObject: PowerRequest(action: action, device: device))
            item.isEnabled = action.isAvailable(for: device.state)
            return item
        }
    }

    // MARK: - Command section

    private func commandItems() -> [NSMenuItem] {
        [
            .command("Refresh", action: #selector(refreshSelected), target: self, key: "r"),
            .command("Preferences…", action: #selector(preferencesSelected), target: self, key: ","),
            .separator(),
            .command("Quit ADB Monitor", action: #selector(quitSelected), target: self, key: "q"),
        ]
    }

    // MARK: - Actions

    @objc private func refreshSelected() { handler?.statusMenuDidRequestRefresh() }
    @objc private func preferencesSelected() { handler?.statusMenuDidRequestPreferences() }
    @objc private func quitSelected() { handler?.statusMenuDidRequestQuit() }

    @objc private func copySerialSelected(_ sender: NSMenuItem) {
        guard let serial = sender.representedObject as? String else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(serial, forType: .string)
    }

    @objc private func powerActionSelected(_ sender: NSMenuItem) {
        guard let request = sender.representedObject as? PowerRequest else { return }
        handler?.statusMenu(didRequest: request.action, on: request.device)
    }
}
