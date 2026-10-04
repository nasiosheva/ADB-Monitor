//
//  StatusButtonPresenter.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import AppKit

/// Decides how the status item button in the menu bar looks for an `ADBStatus`.
@MainActor
struct StatusButtonPresenter {

    private struct Content {
        let image: NSImage?
        let title: String
    }

    /// Brand icon from the asset catalog (`MenuBarIcon`); falls back to an SF Symbol if the asset is missing.
    private static let brandIcon: NSImage? = templateImage(named: "MenuBarIcon") ?? symbol("iphone")
    private static let warningIcon: NSImage? = symbol("exclamationmark.triangle")

    func apply(_ status: ADBStatus?, to button: NSStatusBarButton) {
        let content = self.content(for: status)

        if let image = content.image {
            button.image = image
            button.imagePosition = .imageLeft
            button.title = " " + content.title
        } else {
            button.image = nil
            button.title = "📱 " + content.title
        }
    }

    private func content(for status: ADBStatus?) -> Content {
        switch status {
        case .none:
            return Content(image: Self.brandIcon, title: "…")
        case .devices(let devices)?:
            return Content(image: Self.brandIcon, title: "\(devices.count)")
        case .adbNotFound?, .failure?:
            return Content(image: Self.warningIcon, title: "ADB")
        }
    }

    // MARK: - Image loading

    /// A template image follows light/dark mode automatically.
    private static func templateImage(named name: String) -> NSImage? {
        guard let image = NSImage(named: name) else { return nil }
        image.isTemplate = true
        image.accessibilityDescription = "ADB Monitor"
        return image
    }

    private static func symbol(_ name: String) -> NSImage? {
        guard let image = NSImage(systemSymbolName: name, accessibilityDescription: "ADB Monitor") else { return nil }
        image.isTemplate = true
        return image
    }
}
