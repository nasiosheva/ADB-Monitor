//
//  DeviceMonitor.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

@MainActor
protocol DeviceMonitoring: AnyObject {
    /// Dipanggil hanya ketika status berubah dibanding poll sebelumnya.
    var onStatusChange: ((ADBStatus) -> Void)? { get set }
    /// Dipanggil hanya ketika daftar device yang tersedia lewat Wi-Fi (belum tersambung) berubah.
    var onWirelessChange: (([WirelessService]) -> Void)? { get set }
    func start()
    func stop()
    /// Polling segera. Jika polling sedang berjalan, satu putaran lagi dijalankan setelah selesai.
    func refresh()
}

/// Memanggil `ADBServicing.listDevices` secara berkala dan melaporkan perubahan status.
///
/// Poll berikutnya dijadwalkan setelah poll sebelumnya selesai (bukan interval tetap) sehingga tidak
/// pernah tumpang tindih. Semua API dipanggil dari main thread.
@MainActor
final class DeviceMonitor: DeviceMonitoring {

    var onStatusChange: ((ADBStatus) -> Void)?
    var onWirelessChange: (([WirelessService]) -> Void)?

    private let service: ADBServicing
    private let discovery: WirelessDiscovering
    private let discoverySettings: WirelessDiscoveryProviding
    private let intervalProvider: RefreshIntervalProviding
    private let scheduler: Scheduling
    private let notificationCenter: NotificationCenter

    private var status: ADBStatus?
    private var wireless: [WirelessService] = []
    private var scheduledPoll: ScheduledTask?
    private var isRunning = false
    private var isPolling = false
    private var needsAnotherPoll = false

    init(service: ADBServicing,
         discovery: WirelessDiscovering,
         discoverySettings: WirelessDiscoveryProviding,
         intervalProvider: RefreshIntervalProviding,
         scheduler: Scheduling,
         notificationCenter: NotificationCenter = .default) {
        self.service = service
        self.discovery = discovery
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

            // Penemuan Wi-Fi hanya berarti jika ADB berjalan dan pengguna tidak mematikannya.
            guard case .devices(let devices) = newStatus, self.discoverySettings.wirelessDiscoveryEnabled else {
                self.finishPoll(with: newStatus, wireless: [])
                return
            }
            self.discovery.discoverWireless { [weak self] discovered in
                // Kegagalan penemuan (mis. mDNS tidak tersedia) bukan error: daftar Wi-Fi cukup dikosongkan.
                let available = ((try? discovered.get()) ?? []).filter { !$0.isConnected(among: devices) }
                self?.finishPoll(with: newStatus, wireless: available)
            }
        }
    }

    private func finishPoll(with newStatus: ADBStatus, wireless newWireless: [WirelessService]) {
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
