//
//  AlertPresenter.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import AppKit

@MainActor
protocol AlertPresenting {
    /// `true` if the user approves. Blocks until the dialog is closed.
    func confirm(_ action: PowerAction, on device: ADBDevice) -> Bool
    func showFailure(of action: PowerAction, on device: ADBDevice, error: ADBError)
    /// General error dialog (title and body are already translated by the caller).
    func showError(title: String, message: String)
    func showInfo(title: String, message: String)
}

@MainActor
struct AppKitAlertPresenter: AlertPresenting {

    private let l10n: Localizing

    init(localizer: Localizing) {
        self.l10n = localizer
    }

    func confirm(_ action: PowerAction, on device: ADBDevice) -> Bool {
        let alert = NSAlert()
        alert.messageText = l10n.text(action.confirmTitleKey, device.displayName)
        alert.informativeText = l10n.text(action.confirmBodyKey, device.serial)
        alert.alertStyle = .warning
        alert.addButton(withTitle: l10n.text(action.verbKey))
        alert.addButton(withTitle: l10n.text(.commonCancel))
        return run(alert) == .alertFirstButtonReturn
    }

    func showFailure(of action: PowerAction, on device: ADBDevice, error: ADBError) {
        let alert = NSAlert()
        alert.messageText = l10n.text(action.failureTitleKey, device.displayName)
        alert.informativeText = l10n.message(for: error)
        alert.alertStyle = .critical
        _ = run(alert)
    }

    func showError(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        _ = run(alert)
    }

    func showInfo(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        _ = run(alert)
    }

    private func run(_ alert: NSAlert) -> NSApplication.ModalResponse {
        NSApp.activate(ignoringOtherApps: true)  // an accessory app (no Dock icon) must be activated manually
        return alert.runModal()
    }
}
