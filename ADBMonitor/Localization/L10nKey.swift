//
//  L10nKey.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

/// Keys for all text shown to the user. Every language must have an entry for every key
/// (checked by tests); a missing key falls back to English.
enum L10nKey: String, CaseIterable {
    // Menu: device list and ADB errors
    case menuChecking
    case menuNoDevices
    case menuDevicesHeader
    case menuAdbCustomMissing
    case menuAdbFixInPreferences
    case menuAdbNotInstalled
    case menuAdbInstallHint
    case menuAdbSetPathHint
    case menuAdbError

    // Menu: device details
    case detailStatus
    case detailSerial
    case detailConnection
    case detailModel
    case detailProduct
    case detailDevice
    case detailTransportID
    /// "label: value" format (punctuation differs between languages).
    case labelValue

    // Menu: commands
    case menuCopySerial
    case menuOpenDeveloperOptions
    case developerOptionsFailureTitle
    case menuRefresh
    case menuPreferences
    case menuQuit

    // Device states
    case stateConnected
    case stateOffline
    case stateUnauthorized
    case stateNoPermissions
    case stateAuthorizing
    case stateConnecting
    case stateRecovery
    case stateSideload
    case stateBootloader

    // Hint per state
    case hintUnauthorized
    case hintNoPermissions
    case hintOffline

    // Connection types
    case connectionUSB
    case connectionWiFi
    case connectionEmulator
    case connectionUnknown

    // Power actions
    case powerRestartMenu
    case powerShutdownMenu
    case powerRestartVerb
    case powerShutdownVerb
    case powerRestartConfirmTitle
    case powerShutdownConfirmTitle
    case powerRestartConfirmBody
    case powerShutdownConfirmBody
    case powerRestartFailureTitle
    case powerShutdownFailureTitle

    case commonCancel

    // Error messages
    case errorAdbNotFound
    case errorTimedOut
    case errorLaunchFailed
    case errorLaunchAtLoginUnsupported

    // Preferences window
    case prefsWindowTitle
    case prefsAdbPath
    case prefsAdbPlaceholder
    case prefsChoose
    case prefsUsing
    case prefsAdbNotFound
    case prefsNotExecutable
    case prefsRefreshInterval
    case prefsSeconds
    case prefsStartup
    case prefsLaunchAtLogin
    case prefsLaunchUnsupported
    case prefsLaunchApproval
    case prefsLanguage
    case prefsLanguageSystem
    case prefsSave
    case prefsSelectAdbPanel

    // Wi-Fi: menu
    case menuWirelessHeader
    case menuWirelessConnectItem
    case menuWirelessPairItem
    case menuConnectByAddress
    case menuPairDevice
    case menuPairWithQR
    case menuDisconnect
    case menuSwitchToWiFi

    // Wi-Fi: input dialogs
    case connectPromptTitle
    case connectPromptBody
    case connectPromptPlaceholder
    case connectPromptButton
    case pairPromptTitle
    case pairPromptBody
    case pairAddressPlaceholder
    case pairCodePlaceholder
    case pairPromptButton
    case qrPromptTitle
    case qrPromptBody
    case qrStatusWaiting
    case qrStatusPairing
    case qrFailureTitle

    // Wi-Fi: results
    case pairSuccessTitle
    case pairSuccessBody
    case wirelessConnectFailureTitle
    case wirelessPairFailureTitle
    case wirelessDisconnectFailureTitle
    case wirelessSwitchFailureTitle
    case errorNoWiFiAddress
    case errorInvalidAddress
    case errorInvalidPairingCode
    case errorNoRouteHint
    case errorQRTimedOut

    // Wi-Fi: Preferences
    case prefsWireless
    case prefsWirelessDiscovery
    case prefsWirelessNote

    // Power actions: restart into a special mode
    case powerRecoveryMenu
    case powerRecoveryVerb
    case powerRecoveryConfirmTitle
    case powerRecoveryConfirmBody
    case powerRecoveryFailureTitle
    case powerBootloaderMenu
    case powerBootloaderVerb
    case powerBootloaderConfirmTitle
    case powerBootloaderConfirmBody
    case powerBootloaderFailureTitle
    case powerDownloadMenu
    case powerDownloadVerb
    case powerDownloadConfirmTitle
    case powerDownloadConfirmBody
    case powerDownloadFailureTitle

    // ADB server
    case menuRestartServer
    case serverRestartVerb
    case serverRestartConfirmTitle
    case serverRestartConfirmBody
    case serverRestartFailureTitle

    // Copy
    case menuCopyAdbPrefix
    case menuCopyAddress

    // Device details read from the device
    case detailAndroidVersion
    case detailBattery

    // Fastboot
    case menuFastbootHeader
    case stateFastboot
    case menuFastbootReboot
    case fastbootRebootVerb
    case fastbootRebootConfirmTitle
    case fastbootRebootConfirmBody
    case fastbootRebootFailureTitle
}
