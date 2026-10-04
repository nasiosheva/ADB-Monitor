//
//  WirelessService.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

/// One ADB service found on the network through mDNS (`adb mdns services`).
struct WirelessService: Equatable, Hashable {

    enum Kind: Equatable, Hashable {
        /// Device is ready to connect (`_adb-tls-connect._tcp`, or `_adb._tcp` on old adb).
        case connect
        /// Device is waiting to be paired with a code (`_adb-tls-pairing._tcp`).
        case pairing
    }

    /// Service name, for example `adb-R9CN4057BXJ-aBcDeF`.
    let name: String
    let kind: Kind
    let host: String
    let port: Int

    var address: String { "\(host):\(port)" }

    /// Readable name: `adb-R9CN4057BXJ-aBcDeF` -> `R9CN4057BXJ`; other names are used as is.
    var displayName: String {
        guard name.hasPrefix("adb-") else { return name }
        let body = name.dropFirst(4)
        guard let dash = body.lastIndex(of: "-"), body.distance(from: dash, to: body.endIndex) == 7 else {
            return String(body)
        }
        return String(body[..<dash])
    }

    /// `true` if this service already appears as a connected device in `adb devices`.
    /// Devices connected automatically through mDNS use the serial `<name>._adb-tls-connect._tcp`;
    /// devices connected manually use `host:port`.
    func isConnected(among devices: [ADBDevice]) -> Bool {
        guard kind == .connect else { return false }
        return devices.contains { $0.serial == address || $0.serial.hasPrefix(name + ".") || $0.serial == name }
    }
}
