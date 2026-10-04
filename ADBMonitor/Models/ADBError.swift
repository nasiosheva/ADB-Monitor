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
    /// Keluaran error mentah dari `adb`; tidak diterjemahkan.
    case commandFailed(String)
}
