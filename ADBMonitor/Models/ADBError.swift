//
//  ADBError.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

enum ADBError: Error, Equatable {
    /// `customPath` is set when the user configured a manual path that is not valid.
    case notFound(customPath: String?)
    /// A helper tool other than adb (for example `scrcpy`) is not installed; carries its name.
    case toolNotFound(String)
    case timedOut
    case launchFailed(String)
    /// The device has no Wi-Fi IPv4 address (it is not connected to Wi-Fi).
    case noWiFiAddress
    /// The `host[:port]` address entered by the user is not valid.
    case invalidAddress
    /// The pairing code is not 6 digits.
    case invalidPairingCode
    /// No phone scanned the pairing QR code before the wait ran out.
    case qrPairingTimedOut
    /// Raw error output from `adb`; not translated.
    case commandFailed(String)
}
