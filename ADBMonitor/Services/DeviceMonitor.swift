//
//  DeviceMonitor.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

@MainActor
protocol DeviceMonitoring: AnyObject {
    /// Called only when the status changed compared with the previous poll.
    var onStatusChange: ((ADBStatus) -> Void)? { get set }
    /// Called only when the list of devices available over Wi-Fi (not yet connected) changes.
    var onWirelessChange: (([WirelessService]) -> Void)? { get set }
    /// Called only when the list of devices in fastboot mode changes.
    var onFastbootChange: (([FastbootDevice]) -> Void)? { get set }
    /// Called after every successful poll with the devices adb listed, even when nothing changed.
    var onPoll: (([ADBDevice]) -> Void)? { get set }
    func start()
    func stop()
    /// Polls right away. If a poll is already running, one more round runs after it finishes.
    func refresh()
}

/// Calls `ADBServicing.listDevices` periodically and reports status changes.
///
/// The next poll is scheduled after the previous one finishes (not on a fixed interval), so polls
/// never overlap. All APIs are called from the main thread.
@MainActor
final class DeviceMonitor: DeviceMonitoring {

    var onStatusChange: ((ADBStatus) -> Void)?
    var onWirelessChange: (([WirelessService]) -> Void)?
    var onFastbootChange: (([FastbootDevice]) -> Void)?
    var onPoll: (([ADBDevice]) -> Void)?

    private let service: ADBServicing
    private let discovery: WirelessDiscovering
    private let fastboot: FastbootListing
    private let discoverySettings: WirelessDiscoveryProviding
    private let intervalProvider: RefreshIntervalProviding
    private let scheduler: Scheduling
    private let notificationCenter: NotificationCenter

    private var status: ADBStatus?
    private var wireless: [WirelessService] = []
    private var fastbootDevices: [FastbootDevice] = []
    private var scheduledPoll: ScheduledTask?
    private var isRunning = false
    private var isPolling = false
    private var needsAnotherPoll = false

    init(service: ADBServicing,
         discovery: WirelessDiscovering,
         fastboot: FastbootListing,
         discoverySettings: WirelessDiscoveryProviding,
         intervalProvider: RefreshIntervalProviding,
         scheduler: Scheduling,
         notificationCenter: NotificationCenter = .default) {
        self.service = service
        self.discovery = discovery
        self.fastboot = fastboot
        self.discoverySettings = discoverySettings
        self.intervalProvider = intervalProvider
        self.scheduler = scheduler
        self.notificationCenter = notificationCenter
    }

    deinit {
        scheduledPoll?.cancel()
    }

    // MARK: - DeviceMonitoring

    func start() {
        guard !isRunning else { return }
        isRunning = true
        notificationCenter.addObserver(self,
                                       selector: #selector(preferencesDidChange),
                                       name: .preferencesDidChange,
                                       object: nil)
        poll()
    }

    func stop() {
        isRunning = false
        cancelScheduledPoll()
        notificationCenter.removeObserver(self)
    }

    func refresh() {
        guard isRunning else { return }
        if isPolling {
            needsAnotherPoll = true
        } else {
            poll()
        }
    }

    // MARK: - Polling

    @objc private func preferencesDidChange() {
        refresh()
    }

    private func poll() {
        cancelScheduledPoll()
        guard isRunning, !isPolling else { return }
        isPolling = true

        service.listDevices { [weak self] result in
            guard let self = self else { return }
            let newStatus = ADBStatus(result: result)

            // Wi-Fi and fastboot lookups only matter when ADB works.
            guard case .devices(let devices) = newStatus else {
                self.finishPoll(with: newStatus, wireless: [], fastboot: [])
                return
            }
            self.discoverWireless(excluding: devices) { wireless in
                self.listFastboot { fastboot in
                    self.finishPoll(with: newStatus, wireless: wireless, fastboot: fastboot)
                }
            }
        }
    }

    /// Wi-Fi services that are not connected yet. Empty when the user turned discovery off.
    private func discoverWireless(excluding devices: [ADBDevice], completion: @escaping ([WirelessService]) -> Void) {
        guard discoverySettings.wirelessDiscoveryEnabled else {
            completion([])
            return
        }
        discovery.discoverWireless { discovered in
            // A discovery failure (for example mDNS unavailable) is not an error: just empty the Wi-Fi list.
            completion(((try? discovered.get()) ?? []).filter { !$0.isConnected(among: devices) })
        }
    }

    /// Devices in fastboot mode. A missing `fastboot` or a failure is not an error: the list is just empty.
    private func listFastboot(completion: @escaping ([FastbootDevice]) -> Void) {
        fastboot.listFastboot { result in
            completion((try? result.get()) ?? [])
        }
    }

    private func finishPoll(with newStatus: ADBStatus, wireless newWireless: [WirelessService],
                            fastboot newFastboot: [FastbootDevice]) {
        isPolling = false
        guard isRunning else { return }

        if newStatus != status {
            status = newStatus
            onStatusChange?(newStatus)
        }
        if newWireless != wireless {
            wireless = newWireless
            onWirelessChange?(newWireless)
        }
        if newFastboot != fastbootDevices {
            fastbootDevices = newFastboot
            onFastbootChange?(newFastboot)
        }
        if case .devices(let devices) = newStatus {
            onPoll?(devices)
        }

        if needsAnotherPoll {
            needsAnotherPoll = false
            poll()
        } else {
            scheduleNextPoll()
        }
    }

    private func scheduleNextPoll() {
        scheduledPoll = scheduler.schedule(after: intervalProvider.refreshInterval) { [weak self] in
            self?.poll()
        }
    }

    private func cancelScheduledPoll() {
        scheduledPoll?.cancel()
        scheduledPoll = nil
    }
}
