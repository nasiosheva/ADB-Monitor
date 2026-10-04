//
//  StatusBarController.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import AppKit

/// Abstraction of the menu bar view, so `AppCoordinator` can be tested without a real `NSStatusItem`.
@MainActor
protocol StatusBarRendering: AnyObject {
    /// `nil` means there is no result from the first poll yet.
    func render(_ status: ADBStatus?)
    /// Wi-Fi services that are available (found, not yet connected).
    func renderWireless(_ services: [WirelessService])
    /// Devices that are in fastboot mode.
    func renderFastboot(_ devices: [FastbootDevice])
    /// Android version and battery of connected devices, keyed by serial.
    func renderDetails(_ details: [String: DeviceDetails])
    /// Serials of the devices whose screen is being recorded.
    func renderRecording(_ serials: Set<String>)
}

/// Owns the `NSStatusItem` in the menu bar and keeps the button and dropdown in sync with `ADBStatus`.
@MainActor
final class StatusBarController: StatusBarRendering {

    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private let menuBuilder: StatusMenuBuilder
    private let buttonPresenter = StatusButtonPresenter()
    private var lastStatus: ADBStatus?
    private var lastWireless: [WirelessService] = []
    private var lastFastboot: [FastbootDevice] = []
    private var lastDetails: [String: DeviceDetails] = [:]
    private var lastRecording: Set<String> = []

    init(actionHandler: StatusMenuActionHandling, localizer: Localizing) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        menuBuilder = StatusMenuBuilder(handler: actionHandler, localizer: localizer)
        menu.autoenablesItems = false
        statusItem.menu = menu
        render(nil)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(languageDidChange),
                                               name: .languageDidChange,
                                               object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    func render(_ status: ADBStatus?) {
        lastStatus = status
        if let button = statusItem.button {
            buttonPresenter.apply(status, to: button)
        }
        rebuildMenu()
    }

    func renderWireless(_ services: [WirelessService]) {
        lastWireless = services
        rebuildMenu()
    }

    func renderFastboot(_ devices: [FastbootDevice]) {
        lastFastboot = devices
        rebuildMenu()
    }

    func renderDetails(_ details: [String: DeviceDetails]) {
        lastDetails = details
        rebuildMenu()
    }

    func renderRecording(_ serials: Set<String>) {
        lastRecording = serials
        rebuildMenu()
    }

    private func rebuildMenu() {
        menuBuilder.populate(menu, for: lastStatus, wireless: lastWireless, fastboot: lastFastboot,
                             details: lastDetails, recording: lastRecording)
    }

    /// The language changed: rebuild the menu from the last status without waiting for the next poll.
    @objc private func languageDidChange() {
        render(lastStatus)
    }
}
