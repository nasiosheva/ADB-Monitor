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
    private let l10n: Localizing

    init(handler: StatusMenuActionHandling, localizer: Localizing) {
        self.handler = handler
        self.l10n = localizer
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
        guard let status = status else { return [.info(l10n.text(.menuChecking))] }

        switch status {
        case .devices(let devices):
            return deviceListItems(for: devices)
        case .adbNotFound(let customPath):
            return adbNotFoundItems(customPath: customPath)
        case .failure(let error):
            return [.info(l10n.text(.menuAdbError)), .info(l10n.message(for: error))]
        }
    }

    private func deviceListItems(for devices: [ADBDevice]) -> [NSMenuItem] {
        guard !devices.isEmpty else { return [.info(l10n.text(.menuNoDevices))] }
        return [.info(l10n.text(.menuDevicesHeader, String(devices.count))), .separator()] + devices.map(deviceItem)
    }

    private func adbNotFoundItems(customPath: String?) -> [NSMenuItem] {
        if let customPath = customPath {
            return [.info(l10n.text(.menuAdbCustomMissing)),
                    .info(customPath),
                    .info(l10n.text(.menuAdbFixInPreferences)),
            ]
        }
        return [.info(l10n.text(.menuAdbNotInstalled)),
                .info(l10n.text(.menuAdbInstallHint)),
                .info(l10n.text(.menuAdbSetPathHint)),
        ]
    }

    // MARK: - Device item

    private func deviceItem(for device: ADBDevice) -> NSMenuItem {
        let title = "\(device.displayName) (\(device.serial)) — \(l10n.label(for: device.state))"
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.attributedTitle = device.state.menuTitle(title)
        item.toolTip = device.serial
        item.submenu = detailMenu(for: device)
        return item
    }

    private func detailMenu(for device: ADBDevice) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        var items = detailRows(for: device).map { NSMenuItem.info(l10n.text(.labelValue, $0.label, $0.value)) }
        if let hintKey = device.state.hintKey {
            items += [.separator(), .info(l10n.text(hintKey))]
        }
        items += [.separator(), copySerialItem(for: device)] + powerItems(for: device)

        items.forEach(menu.addItem)
        return menu
    }

    private func detailRows(for device: ADBDevice) -> [(label: String, value: String)] {
        let rows: [(L10nKey, String?)] = [
            (.detailStatus, l10n.label(for: device.state)),
            (.detailSerial, device.serial),
            (.detailConnection, l10n.name(of: device.connection)),
            (.detailModel, device.model),
            (.detailProduct, device.product),
            (.detailDevice, device.deviceName),
            (.detailTransportID, device.transportID),
        ]
        return rows.compactMap { key, value in value.map { (label: l10n.text(key), value: $0) } }
    }

    private func copySerialItem(for device: ADBDevice) -> NSMenuItem {
        .command(l10n.text(.menuCopySerial), action: #selector(copySerialSelected(_:)), target: self,
                 representedObject: device.serial)
    }

    private func powerItems(for device: ADBDevice) -> [NSMenuItem] {
        PowerAction.allCases.map { action in
            let item = NSMenuItem.command(l10n.text(action.menuTitleKey),
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
            .command(l10n.text(.menuRefresh), action: #selector(refreshSelected), target: self, key: "r"),
            .command(l10n.text(.menuPreferences), action: #selector(preferencesSelected), target: self, key: ","),
            .separator(),
            .command(l10n.text(.menuQuit), action: #selector(quitSelected), target: self, key: "q"),
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
