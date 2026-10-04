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
    case rebootRecovery
    case rebootBootloader
    case rebootDownload

    /// The three actions that restart into a special mode (as opposed to a normal restart or a shutdown).
    var isBootMode: Bool {
        switch self {
        case .rebootRecovery, .rebootBootloader, .rebootDownload: return true
        case .restart, .shutdown: return false
        }
    }

    /// Arguments after `adb -s <serial>`.
    var adbArguments: [String] {
        switch self {
        case .restart: return ["reboot"]
        case .shutdown: return ["shell", "reboot", "-p"]
        case .rebootRecovery: return ["reboot", "recovery"]
        case .rebootBootloader: return ["reboot", "bootloader"]
        case .rebootDownload: return ["reboot", "download"]
        }
    }

    // Text keys, not finished text: translations live in `Localization/` and follow the selected language.

    var menuTitleKey: L10nKey {
        switch self {
        case .restart: return .powerRestartMenu
        case .shutdown: return .powerShutdownMenu
        case .rebootRecovery: return .powerRecoveryMenu
        case .rebootBootloader: return .powerBootloaderMenu
        case .rebootDownload: return .powerDownloadMenu
        }
    }

    var verbKey: L10nKey {
        switch self {
        case .restart: return .powerRestartVerb
        case .shutdown: return .powerShutdownVerb
        case .rebootRecovery: return .powerRecoveryVerb
        case .rebootBootloader: return .powerBootloaderVerb
        case .rebootDownload: return .powerDownloadVerb
        }
    }

    /// Confirmation dialog title; argument: device name.
    var confirmTitleKey: L10nKey {
        switch self {
        case .restart: return .powerRestartConfirmTitle
        case .shutdown: return .powerShutdownConfirmTitle
        case .rebootRecovery: return .powerRecoveryConfirmTitle
        case .rebootBootloader: return .powerBootloaderConfirmTitle
        case .rebootDownload: return .powerDownloadConfirmTitle
        }
    }

    /// Confirmation dialog body; argument: device serial.
    var confirmBodyKey: L10nKey {
        switch self {
        case .restart: return .powerRestartConfirmBody
        case .shutdown: return .powerShutdownConfirmBody
        case .rebootRecovery: return .powerRecoveryConfirmBody
        case .rebootBootloader: return .powerBootloaderConfirmBody
        case .rebootDownload: return .powerDownloadConfirmBody
        }
    }

    /// Failure dialog title; argument: device name.
    var failureTitleKey: L10nKey {
        switch self {
        case .restart: return .powerRestartFailureTitle
        case .shutdown: return .powerShutdownFailureTitle
        case .rebootRecovery: return .powerRecoveryFailureTitle
        case .rebootBootloader: return .powerBootloaderFailureTitle
        case .rebootDownload: return .powerDownloadFailureTitle
        }
    }

    func isAvailable(for state: ADBDevice.State) -> Bool {
        switch self {
        // `adb reboot` can be sent to a normal device and to one that is in recovery.
        case .restart: return state == .device || state == .recovery
        // Shutdown goes through the shell, so it is only for devices that booted normally.
        case .shutdown: return state == .device
        // `adb reboot recovery` and `adb reboot bootloader` also work from recovery.
        case .rebootRecovery, .rebootBootloader: return state == .device || state == .recovery
        // `reboot download` is Samsung specific and has only been tried from a normally booted device.
        case .rebootDownload: return state == .device
        }
    }
}
