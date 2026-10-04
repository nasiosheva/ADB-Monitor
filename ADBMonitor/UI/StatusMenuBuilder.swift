//
//  StatusMenuBuilder.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import AppKit

/// ADB Wi-Fi connection actions the user can request from the dropdown menu.
@MainActor
protocol WirelessActionHandling: AnyObject {
    /// Connects to a service found through mDNS (`host:port`).
    func statusMenu(didRequestConnectTo address: String)
    /// Asks the user to type an address, then connects.
    func statusMenuDidRequestConnectByAddress()
    /// Pairing; `address` is set when it comes from a discovered pairing service, `nil` for manual input.
    func statusMenu(didRequestPairingWith address: String?)
    /// Shows a QR code for the phone to scan, then pairs with the phone that does.
    func statusMenuDidRequestPairWithQR()
    func statusMenu(didRequestDisconnect device: ADBDevice)
    func statusMenu(didRequestSwitchToWireless device: ADBDevice)
}

/// Actions the user can request from the dropdown menu.
@MainActor
protocol StatusMenuActionHandling: WirelessActionHandling {
    func statusMenuDidRequestRefresh()
    func statusMenuDidRequestPreferences()
    func statusMenuDidRequestQuit()
    func statusMenu(didRequest action: PowerAction, on device: ADBDevice)
    func statusMenu(didRequestOpenDeveloperOptionsOn device: ADBDevice)
}

/// Fills an `NSMenu` according to `ADBStatus` and forwards clicks to `StatusMenuActionHandling`.
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

    /// Refills the same menu (instead of creating a new one) so a menu that is open does not close.
    /// `wireless` holds Wi-Fi services that were found but are not connected yet.
    func populate(_ menu: NSMenu, for status: ADBStatus?, wireless: [WirelessService] = []) {
        menu.removeAllItems()
        let items = statusItems(for: status, wireless: wireless) + [.separator()] + commandItems()
        items.forEach(menu.addItem)
    }

    // MARK: - Status section

    private func statusItems(for status: ADBStatus?, wireless: [WirelessService]) -> [NSMenuItem] {
        guard let status = status else { return [.info(l10n.text(.menuChecking))] }

        switch status {
        case .devices(let devices):
            return deviceListItems(for: devices) + wirelessItems(for: wireless) + wirelessCommandItems()
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

    // MARK: - Wi-Fi section

    private func wirelessItems(for services: [WirelessService]) -> [NSMenuItem] {
        guard !services.isEmpty else { return [] }
        return [.separator(), .info(l10n.text(.menuWirelessHeader, String(services.count)))]
            + services.map(wirelessServiceItem)
    }

    private func wirelessServiceItem(for service: WirelessService) -> NSMenuItem {
        let label = "\(service.displayName) (\(service.address))"
        switch service.kind {
        case .connect:
            return .command(l10n.text(.menuWirelessConnectItem, label),
                            action: #selector(connectServiceSelected(_:)),
                            target: self,
                            representedObject: service.address)
        case .pairing:
            return .command(l10n.text(.menuWirelessPairItem, label),
                            action: #selector(pairServiceSelected(_:)),
                            target: self,
                            representedObject: service.address)
        }
    }

    /// Always shown (while ADB works): manual connection stays useful on networks that block mDNS.
    private func wirelessCommandItems() -> [NSMenuItem] {
        [
            .separator(),
            .command(l10n.text(.menuConnectByAddress), action: #selector(connectByAddressSelected), target: self),
            .command(l10n.text(.menuPairDevice), action: #selector(pairDeviceSelected), target: self),
            .command(l10n.text(.menuPairWithQR), action: #selector(pairWithQRSelected), target: self),
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
        items += [.separator(), copySerialItem(for: device)]
        items += wirelessDeviceItems(for: device) + [developerOptionsItem(for: device)] + powerItems(for: device)

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

    /// Only for devices that are connected normally; the command is sent through the Android shell.
    private func developerOptionsItem(for device: ADBDevice) -> NSMenuItem {
        let item = NSMenuItem.command(l10n.text(.menuOpenDeveloperOptions),
                                      action: #selector(developerOptionsSelected(_:)),
                                      target: self,
                                      representedObject: device)
        item.isEnabled = device.state == .device
        return item
    }

    /// A Wi-Fi device can be disconnected; a ready USB device can be switched to Wi-Fi.
    private func wirelessDeviceItems(for device: ADBDevice) -> [NSMenuItem] {
        switch device.connection {
        case .network:
            return [.command(l10n.text(.menuDisconnect),
                             action: #selector(disconnectSelected(_:)),
                             target: self,
                             representedObject: device)]
        case .usb where device.state == .device:
            return [.command(l10n.text(.menuSwitchToWiFi),
                             action: #selector(switchToWirelessSelected(_:)),
                             target: self,
                             representedObject: device)]
        default:
            return []
        }
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

    @objc private func developerOptionsSelected(_ sender: NSMenuItem) {
        guard let device = sender.representedObject as? ADBDevice else { return }
        handler?.statusMenu(didRequestOpenDeveloperOptionsOn: device)
    }

    @objc private func connectServiceSelected(_ sender: NSMenuItem) {
        guard let address = sender.representedObject as? String else { return }
        handler?.statusMenu(didRequestConnectTo: address)
    }

    @objc private func pairServiceSelected(_ sender: NSMenuItem) {
        guard let address = sender.representedObject as? String else { return }
        handler?.statusMenu(didRequestPairingWith: address)
    }

    @objc private func connectByAddressSelected() { handler?.statusMenuDidRequestConnectByAddress() }
    @objc private func pairDeviceSelected() { handler?.statusMenu(didRequestPairingWith: nil) }
    @objc private func pairWithQRSelected() { handler?.statusMenuDidRequestPairWithQR() }

    @objc private func disconnectSelected(_ sender: NSMenuItem) {
        guard let device = sender.representedObject as? ADBDevice else { return }
        handler?.statusMenu(didRequestDisconnect: device)
    }

    @objc private func switchToWirelessSelected(_ sender: NSMenuItem) {
        guard let device = sender.representedObject as? ADBDevice else { return }
        handler?.statusMenu(didRequestSwitchToWireless: device)
    }

    @objc private func powerActionSelected(_ sender: NSMenuItem) {
        guard let request = sender.representedObject as? PowerRequest else { return }
        handler?.statusMenu(didRequest: request.action, on: request.device)
    }
}
