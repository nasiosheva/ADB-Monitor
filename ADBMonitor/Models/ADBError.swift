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
    /// Device tidak punya alamat IPv4 Wi-Fi (belum tersambung ke Wi-Fi).
    case noWiFiAddress
    /// Alamat `host[:port]` yang dimasukkan pengguna tidak valid.
    case invalidAddress
    /// Kode pairing bukan 6 digit.
    case invalidPairingCode
    /// Keluaran error mentah dari `adb`; tidak diterjemahkan.
    case commandFailed(String)
}
