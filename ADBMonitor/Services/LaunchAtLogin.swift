//
//  LaunchAtLogin.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation
import ServiceManagement

enum LaunchAtLoginStatus: Equatable {
    /// macOS terlalu lama untuk API login item resmi (butuh macOS 13).
    case unsupported
    case disabled
    case enabled
    /// Terdaftar, tetapi pengguna harus menyetujuinya di System Settings → General → Login Items.
    case requiresApproval

    /// `true` jika pengguna sudah meminta app dibuka saat login (termasuk yang menunggu persetujuan).
    var isOn: Bool { self == .enabled || self == .requiresApproval }
}

enum LaunchAtLoginError: Error {
    case unsupported
}

/// Mengatur apakah app dibuka otomatis saat login.
///
/// Sumber kebenarannya adalah sistem, bukan `UserDefaults`, karena pengguna juga bisa mengubahnya
/// langsung di System Settings. Karena itu `status` selalu dibaca ulang, tidak di-cache.
protocol LaunchAtLoginControlling {
    var status: LaunchAtLoginStatus { get }
    func setEnabled(_ enabled: Bool) throws
}

/// Implementasi resmi lewat `SMAppService` (macOS 13+).
@available(macOS 13.0, *)
struct SMAppServiceLaunchAtLogin: LaunchAtLoginControlling {

    var status: LaunchAtLoginStatus {
        switch SMAppService.mainApp.status {
        case .enabled: return .enabled
        case .requiresApproval: return .requiresApproval
        case .notRegistered, .notFound: return .disabled
        @unknown default: return .disabled
        }
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}

/// Dipakai di macOS 12, yang belum punya API login item resmi untuk app biasa.
struct UnsupportedLaunchAtLogin: LaunchAtLoginControlling {
    var status: LaunchAtLoginStatus { .unsupported }

    func setEnabled(_ enabled: Bool) throws {
        throw LaunchAtLoginError.unsupported
    }
}

enum LaunchAtLogin {
    static func makeDefault() -> LaunchAtLoginControlling {
        if #available(macOS 13.0, *) {
            return SMAppServiceLaunchAtLogin()
        }
        return UnsupportedLaunchAtLogin()
    }
}
