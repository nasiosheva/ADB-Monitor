//
//  PowerAction.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

/// Aksi daya yang bisa dikirim ke satu device lewat adb.
/// Menambah aksi baru cukup dengan menambah case; menu dan dialog konfirmasi mengikuti otomatis.
enum PowerAction: CaseIterable {
    case restart
    case shutdown

    /// Argumen setelah `adb -s <serial>`.
    var adbArguments: [String] {
        switch self {
        case .restart: return ["reboot"]
        case .shutdown: return ["shell", "reboot", "-p"]
        }
    }

    var menuTitle: String {
        switch self {
        case .restart: return "Restart Device…"
        case .shutdown: return "Shut Down Device…"
        }
    }

    var verb: String {
        switch self {
        case .restart: return "Restart"
        case .shutdown: return "Shut Down"
        }
    }

    /// Kelanjutan kalimat "The device (<serial>) …" pada dialog konfirmasi.
    var consequence: String {
        switch self {
        case .restart: return "will reboot immediately."
        case .shutdown: return "will power off immediately and cannot be turned back on from this Mac."
        }
    }

    func isAvailable(for state: ADBDevice.State) -> Bool {
        switch self {
        // `adb reboot` bisa dikirim ke device normal maupun yang berada di recovery.
        case .restart: return state == .device || state == .recovery
        // Shutdown lewat shell, jadi hanya untuk device yang booting normal.
        case .shutdown: return state == .device
        }
    }
}
