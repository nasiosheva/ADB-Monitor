//
//  LaunchAtLogin.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation
import ServiceManagement

enum LaunchAtLoginStatus: Equatable {
    /// macOS is too old for the official login item API (it needs macOS 13).
    case unsupported
    case disabled
    case enabled
    /// Registered, but the user must approve it in System Settings → General → Login Items.
    case requiresApproval

    /// `true` if the user already asked for the app to open at login (including one waiting for approval).
    var isOn: Bool { self == .enabled || self == .requiresApproval }
}

enum LaunchAtLoginError: Error {
    case unsupported
}

/// Controls whether the app opens automatically at login.
///
/// The source of truth is the system, not `UserDefaults`, because the user can also change it
/// directly in System Settings. That is why `status` is always read again and never cached.
protocol LaunchAtLoginControlling {
    var status: LaunchAtLoginStatus { get }
    func setEnabled(_ enabled: Bool) throws
}

/// Official implementation through `SMAppService` (macOS 13+).
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

/// Used on macOS 12, which has no official login item API for regular apps.
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
