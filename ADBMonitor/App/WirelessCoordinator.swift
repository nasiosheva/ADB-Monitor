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
    private let qrPairer: WirelessQRPairing
    private let qrWindow: PairingQRPresenting
    private let alerts: AlertPresenting
    private let monitor: DeviceMonitoring
    private let l10n: Localizing
    private var isPairingWithQR = false

    init(controller: WirelessControlling,
         switcher: WirelessSwitching,
         prompts: WirelessPrompting,
         qrPairer: WirelessQRPairing,
         qrWindow: PairingQRPresenting,
         alerts: AlertPresenting,
         monitor: DeviceMonitoring,
         localizer: Localizing) {
        self.controller = controller
        self.switcher = switcher
        self.prompts = prompts
        self.qrPairer = qrPairer
        self.qrWindow = qrWindow
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

    func statusMenuDidRequestPairWithQR() {
        // A second request while the window is open just brings it to the front.
        guard !isPairingWithQR else {
            qrWindow.bringToFront()
            return
        }
        isPairingWithQR = true
        let credentials = PairingQRCredentials.random()

        qrWindow.show(payload: credentials.payload) { [weak self] in
            self?.qrPairer.cancel()
            self?.isPairingWithQR = false
        }
        qrPairer.start(credentials: credentials, onPairing: { [weak self] in
            self?.qrWindow.showPairingInProgress()
        }, completion: { [weak self] result in
            guard let self = self else { return }
            self.isPairingWithQR = false
            self.qrWindow.dismiss()
            self.monitor.refresh()  // after pairing, adb usually connects by itself through mDNS
            switch result {
            case .success(let address):
                self.alerts.showInfo(title: self.l10n.text(.pairSuccessTitle),
                                     message: self.l10n.text(.pairSuccessBody, address))
            case .failure(let error):
                self.alerts.showError(title: self.l10n.text(.qrFailureTitle), message: self.message(for: error))
            }
        })
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
