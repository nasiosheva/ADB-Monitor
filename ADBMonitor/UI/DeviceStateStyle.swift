//
//  DeviceStateStyle.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import AppKit

/// Display style for `ADBDevice.State`, kept apart from the model so the model does not depend on AppKit.
extension ADBDevice.State {

    var indicatorColor: NSColor {
        switch self {
        case .device: return .systemGreen
        case .unauthorized, .noPermissions, .authorizing, .connecting: return .systemOrange
        case .offline: return .systemRed
        case .recovery, .sideload, .bootloader, .unknown: return .systemGray
        }
    }

    /// Key of the hint for the user when the state needs action.
    var hintKey: L10nKey? {
        switch self {
        case .unauthorized: return .hintUnauthorized
        case .noPermissions: return .hintNoPermissions
        case .offline: return .hintOffline
        default: return nil
        }
    }

    /// Menu title with a colored dot in front, for example "● Pixel 3a (…) — Connected".
    ///
    /// The color is carried by an attributed title, not `NSMenuItem.image`: macOS does not draw custom images
    /// on these menu items (SF Symbols, bitmaps, and drawing handlers all failed to show), while colored text
    /// shows up and follows light/dark mode through dynamic system colors.
    func menuTitle(_ text: String) -> NSAttributedString {
        MenuTitleStyle.dotted(text, color: indicatorColor)
    }
}

/// Menu titles that start with a colored dot.
enum MenuTitleStyle {

    /// Dot color for devices in fastboot mode (not an adb state, so it is not part of `ADBDevice.State`).
    static let fastbootColor = NSColor.systemPurple

    static func dotted(_ text: String, color: NSColor) -> NSAttributedString {
        let font = NSFont.menuFont(ofSize: 0)
        let dot: [NSAttributedString.Key: Any] = [.foregroundColor: color, .font: font]
        let title = NSMutableAttributedString(string: "● ", attributes: dot)
        title.append(NSAttributedString(string: text, attributes: [.font: font]))
        return title
    }
}
