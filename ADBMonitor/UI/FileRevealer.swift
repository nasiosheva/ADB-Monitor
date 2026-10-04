//
//  FileRevealer.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import AppKit

/// Shows a file to the user. Injected so tests do not open Finder windows.
@MainActor
protocol FileRevealing: AnyObject {
    func reveal(_ url: URL)
}

/// Selects the file in a Finder window.
@MainActor
final class FinderFileRevealer: FileRevealing {
    func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
