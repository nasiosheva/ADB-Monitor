//
//  Translations+English.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

extension Translations {
    /// Bahasa acuan dan fallback untuk kunci yang belum diterjemahkan.
    static let english: [L10nKey: String] = [
        .menuChecking: "Checking for devices…",
        .menuNoDevices: "No devices connected",
        .menuDevicesHeader: "Android Devices (%@)",
        .menuAdbCustomMissing: "ADB not found at custom path:",
        .menuAdbFixInPreferences: "Fix it in Preferences.",
        .menuAdbNotInstalled: "ADB is not installed",
        .menuAdbInstallHint: "Install it (brew install android-platform-tools)",
        .menuAdbSetPathHint: "or set its path in Preferences.",
        .menuAdbError: "ADB error",

        .detailStatus: "Status",
        .detailSerial: "Serial",
        .detailConnection: "Connection",
        .detailModel: "Model",
        .detailProduct: "Product",
        .detailDevice: "Device",
        .detailTransportID: "Transport ID",
        .labelValue: "%1$@: %2$@",

        .menuCopySerial: "Copy Serial Number",
        .menuRefresh: "Refresh",
        .menuPreferences: "Preferences…",
        .menuQuit: "Quit ADB Monitor",

        .stateConnected: "Connected",
        .stateOffline: "Offline",
        .stateUnauthorized: "Unauthorized",
        .stateNoPermissions: "No Permissions",
        .stateAuthorizing: "Authorizing",
        .stateConnecting: "Connecting",
        .stateRecovery: "Recovery",
        .stateSideload: "Sideload",
        .stateBootloader: "Bootloader",

        .hintUnauthorized: "Accept the USB debugging prompt on the device.",
        .hintNoPermissions: "Check USB permissions / udev rules.",
        .hintOffline: "Reconnect the device or restart the adb server.",

        .connectionUSB: "USB",
        .connectionWiFi: "Wi-Fi",
        .connectionEmulator: "Emulator",
        .connectionUnknown: "Unknown",

        .powerRestartMenu: "Restart Device…",
        .powerShutdownMenu: "Shut Down Device…",
        .powerRestartVerb: "Restart",
        .powerShutdownVerb: "Shut Down",
        .powerRestartConfirmTitle: "Restart %@?",
        .powerShutdownConfirmTitle: "Shut Down %@?",
        .powerRestartConfirmBody: "The device (%@) will reboot immediately. Unsaved work on the device may be lost.",
        .powerShutdownConfirmBody: "The device (%@) will power off immediately and cannot be turned back on "
            + "from this Mac. Unsaved work on the device may be lost.",
        .powerRestartFailureTitle: "Could not restart %@",
        .powerShutdownFailureTitle: "Could not shut down %@",

        .commonCancel: "Cancel",

        .errorAdbNotFound: "ADB not found.",
        .errorTimedOut: "adb did not respond (timed out).",
        .errorLaunchFailed: "Failed to launch adb: %@",
        .errorLaunchAtLoginUnsupported: "Launch at login requires macOS 13 or later.",

        .prefsWindowTitle: "ADB Monitor Preferences",
        .prefsAdbPath: "ADB path:",
        .prefsAdbPlaceholder: "Auto-detect (leave empty)",
        .prefsChoose: "Choose…",
        .prefsUsing: "Using: %@",
        .prefsAdbNotFound: "ADB not found",
        .prefsNotExecutable: "Not an executable file",
        .prefsRefreshInterval: "Refresh interval:",
        .prefsSeconds: "%@ s",
        .prefsStartup: "Startup:",
        .prefsLaunchAtLogin: "Launch at login",
        .prefsLaunchUnsupported: "Requires macOS 13+. Use System Settings → Login Items.",
        .prefsLaunchApproval: "Approve in System Settings → General → Login Items.",
        .prefsLanguage: "Language:",
        .prefsLanguageSystem: "System default",
        .prefsSave: "Save",
        .prefsSelectAdbPanel: "Select adb executable",
    ]
}
