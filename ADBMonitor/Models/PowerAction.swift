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

    // Kunci teks, bukan teks jadi: terjemahannya ada di `Localization/` dan mengikuti bahasa yang dipilih.

    var menuTitleKey: L10nKey {
        switch self {
        case .restart: return .powerRestartMenu
        case .shutdown: return .powerShutdownMenu
        }
    }

    var verbKey: L10nKey {
        switch self {
        case .restart: return .powerRestartVerb
        case .shutdown: return .powerShutdownVerb
        }
    }

    /// Judul dialog konfirmasi; argumen: nama device.
    var confirmTitleKey: L10nKey {
        switch self {
        case .restart: return .powerRestartConfirmTitle
        case .shutdown: return .powerShutdownConfirmTitle
        }
    }

    /// Isi dialog konfirmasi; argumen: serial device.
    var confirmBodyKey: L10nKey {
        switch self {
        case .restart: return .powerRestartConfirmBody
        case .shutdown: return .powerShutdownConfirmBody
        }
    }

    /// Judul dialog gagal; argumen: nama device.
    var failureTitleKey: L10nKey {
        switch self {
        case .restart: return .powerRestartFailureTitle
        case .shutdown: return .powerShutdownFailureTitle
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
