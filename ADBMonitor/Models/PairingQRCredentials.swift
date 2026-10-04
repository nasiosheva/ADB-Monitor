//
//  PairingQRCredentials.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

/// One-time credentials for pairing through a QR code. A phone that scans the QR advertises the
/// `_adb-tls-pairing._tcp` service named `name`; `password` is used as the pairing code for `adb pair`.
struct PairingQRCredentials: Equatable {

    /// Service name the phone will advertise, and which the Mac looks for in `adb mdns services`.
    let name: String
    let password: String

    /// Format understood by the "Pair device with QR code" screen on Android.
    var payload: String { "WIFI:T:ADB;S:\(name);P:\(password);;" }

    /// Letters and digits only: no character needs escaping in the `WIFI:` format (`\ ; , : "`),
    /// and none can be read by `adb` as an option.
    private static let alphabet = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
    private static let namePrefix = "adbmonitor-"
    private static let nameLength = 8
    private static let passwordLength = 12

    /// Random from `SystemRandomNumberGenerator` (a CSPRNG on macOS); a password is never reused.
    static func random() -> PairingQRCredentials {
        PairingQRCredentials(name: namePrefix + randomString(length: nameLength),
                             password: randomString(length: passwordLength))
    }

    private static func randomString(length: Int) -> String {
        String((0..<length).map { _ in alphabet.randomElement()! })
    }
}
