//
//  ADBDevice.swift
//  ADBMonitor
//

import Foundation

/// Satu baris hasil `adb devices -l`.
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

        var label: String {
            switch self {
            case .device: return "Connected"
            case .offline: return "Offline"
            case .unauthorized: return "Unauthorized"
            case .noPermissions: return "No Permissions"
            case .authorizing: return "Authorizing"
            case .connecting: return "Connecting"
            case .recovery: return "Recovery"
            case .sideload: return "Sideload"
            case .bootloader: return "Bootloader"
            case .unknown(let raw): return raw.capitalized
            }
        }
    }

    enum Connection: String {
        case usb = "USB"
        case network = "Wi-Fi"
        case emulator = "Emulator"
        case unknown = "Unknown"
    }

    let serial: String
    let state: State
    let model: String?
    let product: String?
    let deviceName: String?
    let transportID: String?
    let usbPath: String?

    /// Nama yang ditampilkan di menu: model, lalu codename, lalu serial.
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
