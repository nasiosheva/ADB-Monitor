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

/// A dialog with its text fields, kept apart from `runModal()` so its layout can be tested.
@MainActor
struct PromptDialog {
    let alert: NSAlert
    let fields: [NSTextField]
}

@MainActor
struct AppKitWirelessPrompter: WirelessPrompting {

    /// Width of a text field. `NSAlert` sizes the dialog to the width of the `accessoryView`.
    static let fieldWidth: CGFloat = 312
    static let fieldHeight: CGFloat = 24
    static let fieldSpacing: CGFloat = 8

    private let l10n: Localizing

    init(localizer: Localizing) {
        self.l10n = localizer
    }

    func askConnectAddress() -> String? {
        let dialog = makeConnectDialog()
        return run(dialog, focus: dialog.fields[0]) ? dialog.fields[0].stringValue : nil
    }

    func askPairing(prefilledAddress: String?) -> (address: String, code: String)? {
        let dialog = makePairingDialog(prefilledAddress: prefilledAddress)
        let address = dialog.fields[0]
        let code = dialog.fields[1]
        // The address is already filled in from discovery: focus the code field right away.
        guard run(dialog, focus: prefilledAddress == nil ? address : code) else { return nil }
        return (address.stringValue, code.stringValue)
    }

    // MARK: - Dialog

    func makeConnectDialog() -> PromptDialog {
        let address = makeField(placeholder: l10n.text(.connectPromptPlaceholder))
        return makeDialog(title: l10n.text(.connectPromptTitle),
                          body: l10n.text(.connectPromptBody),
                          button: l10n.text(.connectPromptButton),
                          fields: [address])
    }

    func makePairingDialog(prefilledAddress: String?) -> PromptDialog {
        let address = makeField(placeholder: l10n.text(.pairAddressPlaceholder))
        address.stringValue = prefilledAddress ?? ""
        let code = makeField(placeholder: l10n.text(.pairCodePlaceholder))
        return makeDialog(title: l10n.text(.pairPromptTitle),
                          body: l10n.text(.pairPromptBody),
                          button: l10n.text(.pairPromptButton),
                          fields: [address, code])
    }

    // MARK: - Helpers

    private func makeField(placeholder: String) -> NSTextField {
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: Self.fieldWidth, height: Self.fieldHeight))
        field.placeholderString = placeholder
        field.usesSingleLineMode = true
        return field
    }

    private func makeDialog(title: String, body: String, button: String, fields: [NSTextField]) -> PromptDialog {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = body
        alert.alertStyle = .informational
        alert.addButton(withTitle: button)
        alert.addButton(withTitle: l10n.text(.commonCancel))
        alert.accessoryView = makeAccessoryView(containing: fields)
        return PromptDialog(alert: alert, fields: fields)
    }

    /// Fields are laid out with explicit frames. `NSStackView` is not used: inside an `accessoryView` it collapses
    /// to width 0 because `NSTextField` has no intrinsic width, so the text fields would not be visible.
    private func makeAccessoryView(containing fields: [NSTextField]) -> NSView {
        let count = CGFloat(fields.count)
        let height = count * Self.fieldHeight + (count - 1) * Self.fieldSpacing
        let container = NSView(frame: NSRect(x: 0, y: 0, width: Self.fieldWidth, height: height))
        for (index, field) in fields.enumerated() {
            let row = CGFloat(index)
            // AppKit coordinates start at the bottom: the first field is at the top.
            let y = height - (row + 1) * Self.fieldHeight - row * Self.fieldSpacing
            field.frame = NSRect(x: 0, y: y, width: Self.fieldWidth, height: Self.fieldHeight)
            container.addSubview(field)
        }
        return container
    }

    /// `true` if the user pressed the primary button.
    private func run(_ dialog: PromptDialog, focus field: NSTextField) -> Bool {
        NSApp.activate(ignoringOtherApps: true)  // an accessory app (no Dock icon) must be activated manually
        dialog.alert.window.initialFirstResponder = field
        return dialog.alert.runModal() == .alertFirstButtonReturn
    }
}
