//
//  ADBError.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

enum ADBError: Error, Equatable {
    /// `customPath` terisi jika pengguna menetapkan path manual yang tidak valid.
    case notFound(customPath: String?)
    case timedOut
    case launchFailed(String)
    case commandFailed(String)

    var message: String {
        switch self {
        case .notFound: return "ADB not found."
        case .timedOut: return "adb did not respond (timed out)."
        case .launchFailed(let reason): return "Failed to launch adb: \(reason)"
        case .commandFailed(let reason): return reason
        }
    }
}
