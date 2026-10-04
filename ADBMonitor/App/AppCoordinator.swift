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
    private let wireless: WirelessActionHandling
    private let settings: DeviceSettingsOpening
    private let localizer: Localizing
    private let makeStatusBar: @MainActor (StatusMenuActionHandling) -> StatusBarRendering
    private let makePreferencesWindow: @MainActor () -> PreferencesPresenting

    private var statusBar: StatusBarRendering?
    private lazy var preferencesWindow = makePreferencesWindow()

    init(monitor: DeviceMonitoring,
         service: ADBServicing,
         alerts: AlertPresenting,
         wireless: WirelessActionHandling,
         settings: DeviceSettingsOpening,
         localizer: Localizing,
         makeStatusBar: @escaping @MainActor (StatusMenuActionHandling) -> StatusBarRendering,
         makePreferencesWindow: @escaping @MainActor () -> PreferencesPresenting) {
        self.monitor = monitor
        self.service = service
        self.alerts = alerts
        self.wireless = wireless
        self.settings = settings
        self.localizer = localizer
        self.makeStatusBar = makeStatusBar
        self.makePreferencesWindow = makePreferencesWindow
    }

    func start() {
        let statusBar = makeStatusBar(self)
        self.statusBar = statusBar

        monitor.onStatusChange = { [weak statusBar] status in
            statusBar?.render(status)
        }
        monitor.onWirelessChange = { [weak statusBar] services in
            statusBar?.renderWireless(services)
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
                self.alerts.showFailure(of: action, on: device, error: error)
            }
        }
    }

    func statusMenu(didRequestOpenDeveloperOptionsOn device: ADBDevice) {
        settings.openDeveloperOptions(on: device.serial) { [weak self] result in
            guard let self = self, case .failure(let error) = result else { return }
            self.alerts.showError(title: self.localizer.text(.developerOptionsFailureTitle, device.displayName),
                                  message: self.localizer.message(for: error))
        }
    }

    // MARK: - WirelessActionHandling (diteruskan ke WirelessCoordinator)

    func statusMenu(didRequestConnectTo address: String) {
        wireless.statusMenu(didRequestConnectTo: address)
    }

    func statusMenuDidRequestConnectByAddress() {
        wireless.statusMenuDidRequestConnectByAddress()
    }

    func statusMenu(didRequestPairingWith address: String?) {
        wireless.statusMenu(didRequestPairingWith: address)
    }

    func statusMenu(didRequestDisconnect device: ADBDevice) {
        wireless.statusMenu(didRequestDisconnect: device)
    }

    func statusMenu(didRequestSwitchToWireless device: ADBDevice) {
        wireless.statusMenu(didRequestSwitchToWireless: device)
    }
}
