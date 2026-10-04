//
//  UserNotificationNotifier.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

// `UserNotifications` does not mark `UNUserNotificationCenter` and `UNNotificationRequest` as `Sendable` yet,
// but both are documented as safe to use from any thread.
@preconcurrency import UserNotifications

/// Shows a macOS notification when a device connects or disconnects.
///
/// `requestAuthorization` only prompts the user the first time; after that it answers from the saved choice,
/// so it is called before every notification instead of keeping track of the permission here.
@MainActor
final class UserNotificationNotifier: NSObject, DeviceNotifying, UNUserNotificationCenterDelegate {

    private let center: UNUserNotificationCenter
    private let l10n: Localizing

    init(localizer: Localizing, center: UNUserNotificationCenter = .current()) {
        self.center = center
        self.l10n = localizer
        super.init()
        center.delegate = self
    }

    func prepare() {
        center.requestAuthorization(options: [.alert]) { _, _ in }
    }

    func notify(_ change: DeviceChange) {
        let device: ADBDevice
        let titleKey: L10nKey
        switch change {
        case .connected(let connected):
            (device, titleKey) = (connected, .notifyDeviceConnected)
        case .disconnected(let disconnected):
            (device, titleKey) = (disconnected, .notifyDeviceDisconnected)
        }

        let content = UNMutableNotificationContent()
        content.title = l10n.text(titleKey)
        content.body = "\(device.displayName) (\(device.serial))"
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)

        let center = self.center
        center.requestAuthorization(options: [.alert]) { granted, _ in
            guard granted else { return }
            center.add(request) { _ in }
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Without this, macOS hides notifications while the app is the active one (for example while its menu is open).
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler:
                                                @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list])
    }
}
