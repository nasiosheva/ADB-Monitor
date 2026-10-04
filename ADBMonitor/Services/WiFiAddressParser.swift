//
//  WiFiAddressParser.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

/// Mengambil alamat IPv4 Wi-Fi sebuah device dari keluaran shell Android.
enum WiFiAddressParser {

    /// Mendukung dua bentuk keluaran:
    ///
    ///     1.1.1.1 via 192.168.1.1 dev wlan0 src 192.168.1.23 uid 2000      (ip route get)
    ///     inet 192.168.1.23/24 brd 192.168.1.255 scope global wlan0         (ip -f inet addr show wlan0)
    ///
    /// Alamat loopback (127.x) dan 0.0.0.0 diabaikan.
    static func ipv4(in output: String) -> String? {
        let patterns = [#"\bsrc\s+(\d{1,3}(?:\.\d{1,3}){3})\b"#, #"\binet\s+(\d{1,3}(?:\.\d{1,3}){3})/"#]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            for match in regex.matches(in: output, range: NSRange(output.startIndex..., in: output)) {
                guard let range = Range(match.range(at: 1), in: output) else { continue }
                let candidate = String(output[range])
                if isUsable(candidate) { return candidate }
            }
        }
        return nil
    }

    private static func isUsable(_ address: String) -> Bool {
        let octets = address.split(separator: ".").compactMap { Int($0) }
        guard octets.count == 4, octets.allSatisfy({ (0...255).contains($0) }) else { return false }
        return octets[0] != 127 && address != "0.0.0.0"
    }
}
