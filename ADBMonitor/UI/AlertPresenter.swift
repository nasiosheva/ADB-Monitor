//
//  AlertPresenter.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import AppKit

@MainActor
protocol AlertPresenting {
    /// `true` jika pengguna menyetujui. Memblokir sampai dialog ditutup.
    func confirm(_ action: PowerAction, on device: ADBDevice) -> Bool
    func showFailure(of action: PowerAction, on device: ADBDevice, message: String)
}

@MainActor
struct AppKitAlertPresenter: AlertPresenting {

    func confirm(_ action: PowerAction, on device: ADBDevice) -> Bool {
        let alert = NSAlert()
        alert.messageText = "\(action.verb) \(device.displayName)?"
        alert.informativeText = "The device (\(device.serial)) \(action.consequence) "
            + "Unsaved work on the device may be lost."
        alert.alertStyle = .warning
        alert.addButton(withTitle: action.verb)
        alert.addButton(withTitle: "Cancel")
        return run(alert) == .alertFirstButtonReturn
    }

    func showFailure(of action: PowerAction, on device: ADBDevice, message: String) {
        let alert = NSAlert()
        alert.messageText = "Could not \(action.verb.lowercased()) \(device.displayName)"
        alert.informativeText = message
        alert.alertStyle = .critical
        _ = run(alert)
    }

    private func run(_ alert: NSAlert) -> NSApplication.ModalResponse {
        NSApp.activate(ignoringOtherApps: true)  // app accessory (tanpa Dock) harus diaktifkan manual
        return alert.runModal()
    }
}
