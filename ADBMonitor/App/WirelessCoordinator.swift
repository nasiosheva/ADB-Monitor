//
//  WirelessCoordinator.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

/// Wi-Fi connection flows: validate input, run adb, refresh the list, then show the result.
@MainActor
final class WirelessCoordinator: WirelessActionHandling {

    private let controller: WirelessControlling
    private let switcher: WirelessSwitching
    private let prompts: WirelessPrompting
    private let alerts: AlertPresenting
    private let monitor: DeviceMonitoring
    private let l10n: Localizing

    init(controller: WirelessControlling,
         switcher: WirelessSwitching,
         prompts: WirelessPrompting,
         alerts: AlertPresenting,
         monitor: DeviceMonitoring,
         localizer: Localizing) {
        self.controller = controller
        self.switcher = switcher
        self.prompts = prompts
        self.alerts = alerts
        self.monitor = monitor
        self.l10n = localizer
    }

    // MARK: - WirelessActionHandling

    func statusMenu(didRequestConnectTo address: String) {
        connect(to: address)
    }

    func statusMenuDidRequestConnectByAddress() {
        guard let input = prompts.askConnectAddress() else { return }
        guard let address = WirelessAddress.normalized(input) else {
            showError(.wirelessConnectFailureTitle, subject: input.trimmed, error: .invalidAddress)
            return
        }
        connect(to: address)
    }

    func statusMenu(didRequestPairingWith address: String?) {
        guard let input = prompts.askPairing(prefilledAddress: address) else { return }
        guard let pairingAddress = WirelessAddress.normalized(input.address, requirePort: true) else {
            showError(.wirelessPairFailureTitle, subject: input.address.trimmed, error: .invalidAddress)
            return
        }
        guard WirelessAddress.isValidPairingCode(input.code) else {
            showError(.wirelessPairFailureTitle, subject: pairingAddress, error: .invalidPairingCode)
            return
        }

        controller.pair(address: pairingAddress, code: input.code) { [weak self] result in
            guard let self = self else { return }
            self.monitor.refresh()  // after pairing, adb usually connects by itself through mDNS
            switch result {
            case .success:
                self.alerts.showInfo(title: self.l10n.text(.pairSuccessTitle),
                                     message: self.l10n.text(.pairSuccessBody, pairingAddress))
            case .failure(let error):
                self.showError(.wirelessPairFailureTitle, subject: pairingAddress, error: error)
            }
        }
    }

    func statusMenu(didRequestDisconnect device: ADBDevice) {
        controller.disconnect(serial: device.serial) { [weak self] result in
            guard let self = self else { return }
            self.monitor.refresh()
            if case .failure(let error) = result {
                self.showError(.wirelessDisconnectFailureTitle, subject: device.displayName, error: error)
            }
        }
    }

    func statusMenu(didRequestSwitchToWireless device: ADBDevice) {
        switcher.switchToWireless(serial: device.serial) { [weak self] result in
            guard let self = self else { return }
            self.monitor.refresh()
            if case .failure(let error) = result {
                self.showError(.wirelessSwitchFailureTitle, subject: device.displayName, error: error)
            }
        }
    }

    // MARK: - Helpers

    private func connect(to address: String) {
        controller.connect(to: address) { [weak self] result in
            guard let self = self else { return }
            self.monitor.refresh()
            if case .failure(let error) = result {
                self.showError(.wirelessConnectFailureTitle, subject: address, error: error)
            }
        }
    }

    private func showError(_ titleKey: L10nKey, subject: String, error: ADBError) {
        alerts.showError(title: l10n.text(titleKey, subject), message: message(for: error))
    }

    /// "No route to host" while the network is fine usually means the already-running adb server lacks
    /// Local Network permission (seen on a real phone: a new server worked, the old one failed).
    private func message(for error: ADBError) -> String {
        let base = l10n.message(for: error)
        if case .commandFailed(let raw) = error, raw.localizedCaseInsensitiveContains("no route to host") {
            return base + "\n\n" + l10n.text(.errorNoRouteHint)
        }
        return base
    }
}
