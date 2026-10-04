//
//  WirelessAddress.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

/// Validasi input pengguna untuk koneksi ADB lewat Wi-Fi.
enum WirelessAddress {

    static let defaultPort = 5555

    /// Mengubah input pengguna menjadi `host:port`, atau `nil` jika tidak valid.
    ///
    /// - Parameter requirePort: `true` untuk pairing, yang tidak punya port bawaan.
    /// Host hanya boleh berisi huruf, angka, titik, dan tanda hubung (IPv4 atau nama host); IPv6 belum didukung.
    static func normalized(_ input: String, requirePort: Bool = false) -> String? {
        let trimmed = input.trimmed
        guard !trimmed.isEmpty else { return nil }

        let parts = trimmed.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        guard parts.count <= 2, let host = parts.first, isValidHost(host) else { return nil }

        if parts.count == 2 {
            guard let port = Int(parts[1]), (1...65535).contains(port) else { return nil }
            return "\(host):\(port)"
        }
        return requirePort ? nil : "\(host):\(defaultPort)"
    }

    /// Kode pairing ADB selalu 6 digit.
    static func isValidPairingCode(_ code: String) -> Bool {
        let trimmed = code.trimmed
        return trimmed.count == 6 && trimmed.allSatisfy { $0.isASCII && $0.isNumber }
    }

    private static func isValidHost(_ host: String) -> Bool {
        guard !host.isEmpty, !host.hasPrefix("-"), !host.hasPrefix(".") else { return false }
        return host.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "." || $0 == "-") }
    }
}
