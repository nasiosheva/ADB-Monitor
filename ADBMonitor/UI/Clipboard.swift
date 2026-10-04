//
//  Clipboard.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import AppKit

/// Writes text to the clipboard. A protocol so tests can check what would be copied without touching the
/// real clipboard of the user.
@MainActor
protocol ClipboardWriting {
    func copy(_ text: String)
}

@MainActor
struct SystemClipboard: ClipboardWriting {
    func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
