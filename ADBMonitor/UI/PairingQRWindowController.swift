//
//  PairingQRWindowController.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import AppKit

/// The window that shows the pairing QR code while the app waits for a phone to scan it.
@MainActor
protocol PairingQRPresenting: AnyObject {
    /// Shows `payload` as a QR code. `onCancel` runs if the user cancels or closes the window;
    /// it does not run after `dismiss()`.
    func show(payload: String, onCancel: @escaping () -> Void)
    func bringToFront()
    /// Switches the status line to "pairing in progress" once a phone has scanned the code.
    func showPairingInProgress()
    func dismiss()
}

/// A non-modal floating panel, so the menu bar item and polling keep working while it is open.
@MainActor
final class AppKitPairingQRPresenter: NSObject, PairingQRPresenting, NSWindowDelegate {

    static let qrSide: CGFloat = 240
    static let contentWidth: CGFloat = 320
    private static let margin: CGFloat = 20
    private static let spacing: CGFloat = 12

    private let l10n: Localizing
    private var panel: NSPanel?
    private var statusLabel: NSTextField?
    private var onCancel: (() -> Void)?

    init(localizer: Localizing) {
        self.l10n = localizer
    }

    func show(payload: String, onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
        let panel = makePanel(payload: payload)
        self.panel = panel
        NSApp.activate(ignoringOtherApps: true)  // an accessory app (no Dock icon) must be activated by hand
        panel.center()
        panel.makeKeyAndOrderFront(nil)
    }

    func bringToFront() {
        NSApp.activate(ignoringOtherApps: true)
        panel?.makeKeyAndOrderFront(nil)
    }

    func showPairingInProgress() {
        statusLabel?.stringValue = l10n.text(.qrStatusPairing)
    }

    func dismiss() {
        onCancel = nil
        close()
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        let cancel = onCancel
        onCancel = nil
        panel = nil
        statusLabel = nil
        cancel?()
    }

    // MARK: - Layout

    /// Frames are explicit, not `NSStackView`: see the note on `AppKitWirelessPrompter.makeAccessoryView`.
    func makePanel(payload: String) -> NSPanel {
        let width = Self.contentWidth
        let title = NSTextField(labelWithString: l10n.text(.qrPromptTitle))
        title.font = .boldSystemFont(ofSize: 15)
        let body = NSTextField(wrappingLabelWithString: l10n.text(.qrPromptBody))
        body.preferredMaxLayoutWidth = width
        let status = NSTextField(labelWithString: l10n.text(.qrStatusWaiting))
        status.textColor = .secondaryLabelColor
        status.alignment = .center
        let cancel = NSButton(title: l10n.text(.commonCancel), target: self, action: #selector(cancelPressed))
        cancel.keyEquivalent = "\u{1b}"  // Esc

        let image = NSImageView(frame: NSRect(x: 0, y: 0, width: Self.qrSide, height: Self.qrSide))
        image.image = QRCodeRenderer.image(for: payload, side: Self.qrSide)
        image.imageScaling = .scaleProportionallyUpOrDown

        let titleHeight = ceil(title.intrinsicContentSize.height)
        let bodyHeight = ceil(body.intrinsicContentSize.height)
        let statusHeight = ceil(status.intrinsicContentSize.height)
        let buttonHeight = ceil(cancel.intrinsicContentSize.height)
        let contentHeight = titleHeight + bodyHeight + Self.qrSide + statusHeight + buttonHeight + 4 * Self.spacing
        let size = NSSize(width: width + 2 * Self.margin, height: contentHeight + 2 * Self.margin)

        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                            styleMask: [.titled, .closable],
                            backing: .buffered,
                            defer: false)
        panel.title = l10n.text(.qrPromptTitle)
        panel.isReleasedWhenClosed = false  // ARC owns it; closing must not free it a second time
        panel.level = .floating
        panel.delegate = self

        // AppKit coordinates start at the bottom, so lay out from the bottom up.
        var y = Self.margin
        cancel.frame = NSRect(x: (size.width - 90) / 2, y: y, width: 90, height: buttonHeight)
        y += buttonHeight + Self.spacing
        status.frame = NSRect(x: Self.margin, y: y, width: width, height: statusHeight)
        y += statusHeight + Self.spacing
        image.frame = NSRect(x: (size.width - Self.qrSide) / 2, y: y, width: Self.qrSide, height: Self.qrSide)
        y += Self.qrSide + Self.spacing
        body.frame = NSRect(x: Self.margin, y: y, width: width, height: bodyHeight)
        y += bodyHeight + Self.spacing
        title.frame = NSRect(x: Self.margin, y: y, width: width, height: titleHeight)

        let content = NSView(frame: NSRect(origin: .zero, size: size))
        [title, body, image, status, cancel].forEach(content.addSubview)
        panel.contentView = content
        statusLabel = status
        return panel
    }

    @objc private func cancelPressed() {
        close()  // `windowWillClose` reports the cancellation
    }

    private func close() {
        panel?.close()
    }
}
