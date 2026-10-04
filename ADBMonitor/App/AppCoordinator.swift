//
//  AppCoordinator.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import AppKit

/// Menghubungkan monitor device, status bar, dan aksi pengguna.
/// Semua dependensi berupa protokol sehingga bisa diganti (mis. saat testing).
@MainActor
final class AppCoordinator: StatusMenuActionHandling {

    private let monitor: DeviceMonitoring
    private let service: ADBServicing
    private let alerts: AlertPresenting
    private let makePreferencesWindow: @MainActor () -> PreferencesWindowController

    private var statusBar: StatusBarController?
    private lazy var preferencesWindow = makePreferencesWindow()

    init(monitor: DeviceMonitoring,
         service: ADBServicing,
         alerts: AlertPresenting,
         makePreferencesWindow: @escaping @MainActor () -> PreferencesWindowController) {
        self.monitor = monitor
        self.service = service
        self.alerts = alerts
        self.makePreferencesWindow = makePreferencesWindow
    }

    func start() {
        let statusBar = StatusBarController(actionHandler: self)
        self.statusBar = statusBar

        monitor.onStatusChange = { [weak statusBar] status in
            statusBar?.render(status)
        }
        monitor.start()
    }

    func stop() {
        monitor.stop()
    }

    // MARK: - StatusMenuActionHandling

    func statusMenuDidRequestRefresh() {
        monitor.refresh()
    }

    func statusMenuDidRequestPreferences() {
        preferencesWindow.present()
    }

    func statusMenuDidRequestQuit() {
        NSApp.terminate(nil)
    }

    func statusMenu(didRequest action: PowerAction, on device: ADBDevice) {
        guard alerts.confirm(action, on: device) else { return }

        service.perform(action, on: device.serial) { [weak self] result in
            guard let self = self else { return }
            self.monitor.refresh()  // daftar device segera diperbarui, tanpa menunggu poll berikutnya
            if case .failure(let error) = result {
                self.alerts.showFailure(of: action, on: device, message: error.message)
            }
        }
    }
}
