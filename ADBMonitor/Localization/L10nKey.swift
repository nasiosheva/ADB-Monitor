//
//  L10nKey.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

/// Kunci semua teks yang tampil ke pengguna. Setiap bahasa wajib punya entri untuk setiap kunci
/// (diperiksa oleh pengujian); kunci yang hilang jatuh ke bahasa Inggris.
enum L10nKey: String, CaseIterable {
    // Menu: daftar device dan error ADB
    case menuChecking
    case menuNoDevices
    case menuDevicesHeader
    case menuAdbCustomMissing
    case menuAdbFixInPreferences
    case menuAdbNotInstalled
    case menuAdbInstallHint
    case menuAdbSetPathHint
    case menuAdbError

    // Menu: detail device
    case detailStatus
    case detailSerial
    case detailConnection
    case detailModel
    case detailProduct
    case detailDevice
    case detailTransportID
    /// Format "label: nilai" (tanda baca berbeda antar bahasa).
    case labelValue

    // Menu: perintah
    case menuCopySerial
    case menuOpenDeveloperOptions
    case developerOptionsFailureTitle
    case menuRefresh
    case menuPreferences
    case menuQuit

    // Status device
    case stateConnected
    case stateOffline
    case stateUnauthorized
    case stateNoPermissions
    case stateAuthorizing
    case stateConnecting
    case stateRecovery
    case stateSideload
    case stateBootloader

    // Petunjuk per status
    case hintUnauthorized
    case hintNoPermissions
    case hintOffline

    // Tipe koneksi
    case connectionUSB
    case connectionWiFi
    case connectionEmulator
    case connectionUnknown

    // Aksi daya
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

    // Pesan error
    case errorAdbNotFound
    case errorTimedOut
    case errorLaunchFailed
    case errorLaunchAtLoginUnsupported

    // Jendela Preferences
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
    case menuDisconnect
    case menuSwitchToWiFi

    // Wi-Fi: dialog input
    case connectPromptTitle
    case connectPromptBody
    case connectPromptPlaceholder
    case connectPromptButton
    case pairPromptTitle
    case pairPromptBody
    case pairAddressPlaceholder
    case pairCodePlaceholder
    case pairPromptButton

    // Wi-Fi: hasil
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

    // Wi-Fi: Preferences
    case prefsWireless
    case prefsWirelessDiscovery
    case prefsWirelessNote
}
