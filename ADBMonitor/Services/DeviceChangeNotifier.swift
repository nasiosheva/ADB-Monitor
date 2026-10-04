//
//  DeviceChangeNotifier.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

/// Shows a user notification. The real implementation uses `UserNotifications`.
@MainActor
protocol DeviceNotifying: AnyObject {
    /// Asks the system for permission to show notifications (only the first time does it prompt the user).
    func prepare()
    func notify(_ change: DeviceChange)
}

@MainActor
protocol DeviceChangeTracking: AnyObject {
    /// Called with the device list of every successful poll.
    func track(devices: [ADBDevice])
}

/// Turns the device lists of the polls into notifications.
///
/// The detector keeps running even while notifications are off, so turning them on later does not announce
/// every device that was already connected.
@MainActor
final class DeviceChangeNotifier: DeviceChangeTracking {

    private let settings: DeviceNotificationProviding
    private let notifier: DeviceNotifying
    private var detector: DeviceChangeDetector
    private let notificationCenter: NotificationCenter

    init(settings: DeviceNotificationProviding,
         notifier: DeviceNotifying,
         detector: DeviceChangeDetector = DeviceChangeDetector(),
         notificationCenter: NotificationCenter = .default) {
        self.settings = settings
        self.notifier = notifier
        self.detector = detector
        self.notificationCenter = notificationCenter
        // Ask for permission when the user turns the setting on, not on the first device event.
        notificationCenter.addObserver(self,
                                       selector: #selector(preferencesDidChange),
                                       name: .preferencesDidChange,
                                       object: nil)
    }

    deinit {
        notificationCenter.removeObserver(self)
    }

    func track(devices: [ADBDevice]) {
        let changes = detector.update(with: devices)
        guard settings.deviceNotificationsEnabled else { return }
        changes.forEach(notifier.notify)
    }

    @objc private func preferencesDidChange() {
        if settings.deviceNotificationsEnabled { notifier.prepare() }
    }
}
