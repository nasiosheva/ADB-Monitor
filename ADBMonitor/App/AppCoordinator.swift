//
//  AppCoordinator.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import AppKit

/// Wires the device monitor, the status bar, and user actions together.
/// Every dependency is a protocol, so it can be replaced (for example in tests).
@MainActor
final class AppCoordinator: StatusMenuActionHandling {

    private let monitor: DeviceMonitoring
    private let service: ADBServicing
    private let alerts: AlertPresenting
    private let wireless: WirelessActionHandling
    private let tools: ToolsActionHandling
    private let screen: ScreenActionHandling & RecordingStateReporting
    private let settings: DeviceSettingsOpening
    private let localizer: Localizing
    private let detailsTracker: DeviceDetailsTracking
    private let changeTracker: DeviceChangeTracking
    private let makeStatusBar: @MainActor (StatusMenuActionHandling) -> StatusBarRendering
    private let makePreferencesWindow: @MainActor () -> PreferencesPresenting

    private var statusBar: StatusBarRendering?
    private lazy var preferencesWindow = makePreferencesWindow()

    init(monitor: DeviceMonitoring,
         service: ADBServicing,
         alerts: AlertPresenting,
         wireless: WirelessActionHandling,
         tools: ToolsActionHandling,
         screen: ScreenActionHandling & RecordingStateReporting,
         settings: DeviceSettingsOpening,
         localizer: Localizing,
         detailsTracker: DeviceDetailsTracking,
         changeTracker: DeviceChangeTracking,
         makeStatusBar: @escaping @MainActor (StatusMenuActionHandling) -> StatusBarRendering,
         makePreferencesWindow: @escaping @MainActor () -> PreferencesPresenting) {
        self.monitor = monitor
        self.service = service
        self.alerts = alerts
        self.wireless = wireless
        self.tools = tools
        self.screen = screen
        self.settings = settings
        self.localizer = localizer
        self.detailsTracker = detailsTracker
        self.changeTracker = changeTracker
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
        monitor.onFastbootChange = { [weak statusBar] devices in
            statusBar?.renderFastboot(devices)
        }
        // The trackers decide by themselves what to do; they are told about every poll.
        monitor.onPoll = { [weak detailsTracker, weak changeTracker] devices in
            detailsTracker?.track(devices: devices)
            changeTracker?.track(devices: devices)
        }
        detailsTracker.onChange = { [weak statusBar] details in
            statusBar?.renderDetails(details)
        }
        screen.onRecordingChange = { [weak statusBar] serials in
            statusBar?.renderRecording(serials)
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
            self.monitor.refresh()  // refresh the device list right away instead of waiting for the next poll
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

    // MARK: - WirelessActionHandling (forwarded to WirelessCoordinator)

    func statusMenu(didRequestConnectTo address: String) {
        wireless.statusMenu(didRequestConnectTo: address)
    }

    func statusMenuDidRequestConnectByAddress() {
        wireless.statusMenuDidRequestConnectByAddress()
    }

    func statusMenu(didRequestPairingWith address: String?) {
        wireless.statusMenu(didRequestPairingWith: address)
    }

    func statusMenuDidRequestPairWithQR() {
        wireless.statusMenuDidRequestPairWithQR()
    }

    func statusMenu(didRequestDisconnect device: ADBDevice) {
        wireless.statusMenu(didRequestDisconnect: device)
    }

    func statusMenu(didRequestSwitchToWireless device: ADBDevice) {
        wireless.statusMenu(didRequestSwitchToWireless: device)
    }

    // MARK: - ScreenActionHandling (forwarded to ScreenCoordinator)

    func statusMenu(didRequestScreenshotOf device: ADBDevice) {
        screen.statusMenu(didRequestScreenshotOf: device)
    }

    func statusMenu(didRequestToggleRecordingOf device: ADBDevice) {
        screen.statusMenu(didRequestToggleRecordingOf: device)
    }

    func statusMenu(didRequestMirror device: ADBDevice) {
        screen.statusMenu(didRequestMirror: device)
    }

    // MARK: - ToolsActionHandling (forwarded to ToolsCoordinator)

    func statusMenuDidRequestRestartServer() {
        tools.statusMenuDidRequestRestartServer()
    }

    func statusMenu(didRequestRebootFastbootDevice device: FastbootDevice) {
        tools.statusMenu(didRequestRebootFastbootDevice: device)
    }
}
