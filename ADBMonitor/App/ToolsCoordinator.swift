//
//  ToolsCoordinator.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

/// Flows for the tool actions: restart the adb server, and reboot a device that is in fastboot mode.
/// Each asks for a confirmation first, runs the command, refreshes the lists, then shows an error if it failed.
@MainActor
final class ToolsCoordinator: ToolsActionHandling {

    private let server: ADBServerControlling
    private let fastboot: FastbootControlling
    private let alerts: AlertPresenting
    private let monitor: DeviceMonitoring
    private let l10n: Localizing

    init(server: ADBServerControlling,
         fastboot: FastbootControlling,
         alerts: AlertPresenting,
         monitor: DeviceMonitoring,
         localizer: Localizing) {
        self.server = server
        self.fastboot = fastboot
        self.alerts = alerts
        self.monitor = monitor
        self.l10n = localizer
    }

    // MARK: - ToolsActionHandling

    func statusMenuDidRequestRestartServer() {
        let approved = alerts.confirm(title: l10n.text(.serverRestartConfirmTitle),
                                      message: l10n.text(.serverRestartConfirmBody),
                                      button: l10n.text(.serverRestartVerb))
        guard approved else { return }

        server.restartServer { [weak self] result in
            guard let self = self else { return }
            self.monitor.refresh()  // the new server is up: show the devices without waiting for the next poll
            if case .failure(let error) = result {
                self.alerts.showError(title: self.l10n.text(.serverRestartFailureTitle),
                                      message: self.l10n.message(for: error))
            }
        }
    }

    func statusMenu(didRequestRebootFastbootDevice device: FastbootDevice) {
        let approved = alerts.confirm(title: l10n.text(.fastbootRebootConfirmTitle, device.serial),
                                      message: l10n.text(.fastbootRebootConfirmBody, device.serial),
                                      button: l10n.text(.fastbootRebootVerb))
        guard approved else { return }

        fastboot.reboot(serial: device.serial) { [weak self] result in
            guard let self = self else { return }
            self.monitor.refresh()
            if case .failure(let error) = result {
                self.alerts.showError(title: self.l10n.text(.fastbootRebootFailureTitle, device.serial),
                                      message: self.l10n.message(for: error))
            }
        }
    }
}
