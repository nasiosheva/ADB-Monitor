//
//  WirelessService.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

/// Satu layanan ADB yang ditemukan di jaringan lewat mDNS (`adb mdns services`).
struct WirelessService: Equatable, Hashable {

    enum Kind: Equatable, Hashable {
        /// Device siap disambungkan (`_adb-tls-connect._tcp`, atau `_adb._tcp` pada adb lama).
        case connect
        /// Device sedang menunggu pairing dengan kode (`_adb-tls-pairing._tcp`).
        case pairing
    }

    /// Nama layanan, misalnya `adb-R9CN4057BXJ-aBcDeF`.
    let name: String
    let kind: Kind
    let host: String
    let port: Int

    var address: String { "\(host):\(port)" }

    /// Nama yang enak dibaca: `adb-R9CN4057BXJ-aBcDeF` -> `R9CN4057BXJ`; nama lain dipakai apa adanya.
    var displayName: String {
        guard name.hasPrefix("adb-") else { return name }
        let body = name.dropFirst(4)
        guard let dash = body.lastIndex(of: "-"), body.distance(from: dash, to: body.endIndex) == 7 else {
            return String(body)
        }
        return String(body[..<dash])
    }

    /// `true` jika layanan ini sudah muncul sebagai device yang tersambung di `adb devices`.
    /// Device yang disambungkan otomatis lewat mDNS memakai serial `<name>._adb-tls-connect._tcp`;
    /// yang disambungkan manual memakai `host:port`.
    func isConnected(among devices: [ADBDevice]) -> Bool {
        guard kind == .connect else { return false }
        return devices.contains { $0.serial == address || $0.serial.hasPrefix(name + ".") || $0.serial == name }
    }
}
