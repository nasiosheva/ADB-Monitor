//
//  WirelessPrompter.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import AppKit

/// Input dialogs for Wi-Fi connections. Return `nil` if the user cancels.
@MainActor
protocol WirelessPrompting {
    func askConnectAddress() -> String?
    func askPairing(prefilledAddress: String?) -> (address: String, code: String)?
}

@MainActor
struct AppKitWirelessPrompter: WirelessPrompting {

    private let l10n: Localizing

    init(localizer: Localizing) {
        self.l10n = localizer
    }

    func askConnectAddress() -> String? {
        let address = makeField(placeholder: l10n.text(.connectPromptPlaceholder))
        let alert = makeAlert(title: l10n.text(.connectPromptTitle),
                              body: l10n.text(.connectPromptBody),
                              button: l10n.text(.connectPromptButton),
                              fields: [address])
        return run(alert, focus: address) ? address.stringValue : nil
    }

    func askPairing(prefilledAddress: String?) -> (address: String, code: String)? {
        let address = makeField(placeholder: l10n.text(.pairAddressPlaceholder))
        address.stringValue = prefilledAddress ?? ""
        let code = makeField(placeholder: l10n.text(.pairCodePlaceholder))
        let alert = makeAlert(title: l10n.text(.pairPromptTitle),
                              body: l10n.text(.pairPromptBody),
                              button: l10n.text(.pairPromptButton),
                              fields: [address, code])
        // Alamat sudah terisi dari hasil penemuan: langsung fokus ke kode.
        guard run(alert, focus: prefilledAddress == nil ? address : code) else { return nil }
        return (address.stringValue, code.stringValue)
    }

    // MARK: - Helpers

    private func makeField(placeholder: String) -> NSTextField {
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        field.placeholderString = placeholder
        return field
    }

    private func makeAlert(title: String, body: String, button: String, fields: [NSTextField]) -> NSAlert {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = body
        alert.alertStyle = .informational
        alert.addButton(withTitle: button)
        alert.addButton(withTitle: l10n.text(.commonCancel))

        let spacing: CGFloat = 8
        let height = CGFloat(fields.count) * 24 + CGFloat(fields.count - 1) * spacing
        let stack = NSStackView(views: fields)
        stack.orientation = .vertical
        stack.spacing = spacing
        stack.frame = NSRect(x: 0, y: 0, width: 320, height: height)
        alert.accessoryView = stack
        return alert
    }

    /// `true` jika pengguna menekan tombol utama.
    private func run(_ alert: NSAlert, focus field: NSTextField) -> Bool {
        NSApp.activate(ignoringOtherApps: true)  // app accessory (tanpa Dock) harus diaktifkan manual
        alert.window.initialFirstResponder = field
        return alert.runModal() == .alertFirstButtonReturn
    }
}
