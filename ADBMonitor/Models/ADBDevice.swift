//
//  ADBDevice.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

/// One line of the output of `adb devices -l`.
struct ADBDevice: Equatable, Hashable {

    enum State: Equatable, Hashable {
        case device
        case offline
        case unauthorized
        case noPermissions
        case authorizing
        case connecting
        case recovery
        case sideload
        case bootloader
        case unknown(String)

        init(adbValue: String) {
            switch adbValue {
            case "device": self = .device
            case "offline": self = .offline
            case "unauthorized": self = .unauthorized
            case "authorizing": self = .authorizing
            case "connecting": self = .connecting
            case "recovery": self = .recovery
            case "sideload": self = .sideload
            case "bootloader": self = .bootloader
            default: self = .unknown(adbValue)
            }
        }

        /// Text key for the state label; `nil` for unknown states (shown as is).
        var labelKey: L10nKey? {
            switch self {
            case .device: return .stateConnected
            case .offline: return .stateOffline
            case .unauthorized: return .stateUnauthorized
            case .noPermissions: return .stateNoPermissions
            case .authorizing: return .stateAuthorizing
            case .connecting: return .stateConnecting
            case .recovery: return .stateRecovery
            case .sideload: return .stateSideload
            case .bootloader: return .stateBootloader
            case .unknown: return nil
            }
        }
    }

    enum Connection {
        case usb
        case network
        case emulator
        case unknown

        var labelKey: L10nKey {
            switch self {
            case .usb: return .connectionUSB
            case .network: return .connectionWiFi
            case .emulator: return .connectionEmulator
            case .unknown: return .connectionUnknown
            }
        }
    }

    let serial: String
    let state: State
    let model: String?
    let product: String?
    let deviceName: String?
    let transportID: String?
    let usbPath: String?

    /// Name shown in the menu: model, then codename, then serial.
    var displayName: String {
        model ?? deviceName ?? product ?? serial
    }

    var connection: Connection {
        if serial.hasPrefix("emulator-") { return .emulator }
        if serial.contains("._adb-tls-") || serial.contains(":") { return .network }
        if usbPath != nil { return .usb }
        return .unknown
    }
}
