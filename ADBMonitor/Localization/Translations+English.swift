//
//  Translations+English.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

extension Translations {
    /// Reference language and fallback for keys that are not translated yet.
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
        .menuOpenDeveloperOptions: "Open Developer Options",
        .developerOptionsFailureTitle: "Could not open Developer options on %@",
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

        .menuWirelessHeader: "Available over Wi-Fi (%@)",
        .menuWirelessConnectItem: "Connect to %@",
        .menuWirelessPairItem: "Pair with %@…",
        .menuConnectByAddress: "Connect to IP Address…",
        .menuPairDevice: "Pair Device…",
        .menuDisconnect: "Disconnect",
        .menuSwitchToWiFi: "Switch to Wi-Fi",

        .connectPromptTitle: "Connect over Wi-Fi",
        .connectPromptBody: "Enter the device IP address. The port defaults to 5555; for Wireless debugging use the "
            + "port shown on the device.",
        .connectPromptPlaceholder: "192.168.1.5:5555",
        .connectPromptButton: "Connect",
        .pairPromptTitle: "Pair a device",
        .pairPromptBody: "On the device open Developer options → Wireless debugging → Pair device with pairing code, "
            + "then enter the address and code shown there.",
        .pairAddressPlaceholder: "IP address and port (192.168.1.5:41223)",
        .pairCodePlaceholder: "6-digit pairing code",
        .pairPromptButton: "Pair",

        .pairSuccessTitle: "Paired",
        .pairSuccessBody: "%@ is paired. If it does not appear in the list, connect to it under Available over Wi-Fi.",
        .wirelessConnectFailureTitle: "Could not connect to %@",
        .wirelessPairFailureTitle: "Could not pair with %@",
        .wirelessDisconnectFailureTitle: "Could not disconnect %@",
        .wirelessSwitchFailureTitle: "Could not switch %@ to Wi-Fi",
        .errorNoWiFiAddress: "The device has no Wi-Fi IP address. Connect it to Wi-Fi first.",
        .errorInvalidAddress: "Enter a valid IP address, optionally followed by a port (for example 192.168.1.5:5555).",
        .errorInvalidPairingCode: "Enter the 6-digit pairing code shown on the device.",
        .errorNoRouteHint: "If other devices on this network are reachable, the adb server that is already running "
            + "may lack Local Network permission. Run adb kill-server, then allow ADB Monitor under "
            + "System Settings → Privacy & Security → Local Network.",

        .prefsWireless: "Wi-Fi:",
        .prefsWirelessDiscovery: "Detect devices on Wi-Fi",
        .prefsWirelessNote: "Uses mDNS; some networks block it.",
    ]
}
