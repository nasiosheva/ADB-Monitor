//
//  PowerAction.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

/// A power action that can be sent to one device through adb.
/// Adding an action only takes a new case; the menu and the confirmation dialog follow automatically.
enum PowerAction: CaseIterable {
    case restart
    case shutdown

    /// Arguments after `adb -s <serial>`.
    var adbArguments: [String] {
        switch self {
        case .restart: return ["reboot"]
        case .shutdown: return ["shell", "reboot", "-p"]
        }
    }

    // Text keys, not finished text: translations live in `Localization/` and follow the selected language.

    var menuTitleKey: L10nKey {
        switch self {
        case .restart: return .powerRestartMenu
        case .shutdown: return .powerShutdownMenu
        }
    }

    var verbKey: L10nKey {
        switch self {
        case .restart: return .powerRestartVerb
        case .shutdown: return .powerShutdownVerb
        }
    }

    /// Confirmation dialog title; argument: device name.
    var confirmTitleKey: L10nKey {
        switch self {
        case .restart: return .powerRestartConfirmTitle
        case .shutdown: return .powerShutdownConfirmTitle
        }
    }

    /// Confirmation dialog body; argument: device serial.
    var confirmBodyKey: L10nKey {
        switch self {
        case .restart: return .powerRestartConfirmBody
        case .shutdown: return .powerShutdownConfirmBody
        }
    }

    /// Failure dialog title; argument: device name.
    var failureTitleKey: L10nKey {
        switch self {
        case .restart: return .powerRestartFailureTitle
        case .shutdown: return .powerShutdownFailureTitle
        }
    }

    func isAvailable(for state: ADBDevice.State) -> Bool {
        switch self {
        // `adb reboot` can be sent to a normal device and to one that is in recovery.
        case .restart: return state == .device || state == .recovery
        // Shutdown goes through the shell, so it is only for devices that booted normally.
        case .shutdown: return state == .device
        }
    }
}
