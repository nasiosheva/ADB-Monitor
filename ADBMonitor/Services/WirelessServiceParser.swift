//
//  WirelessServiceParser.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

protocol WirelessServiceParsing {
    func parse(_ output: String) -> [WirelessService]
}

/// Parses the output of `adb mdns services`:
///
///     List of discovered mdns services
///     adb-R9CN4057BXJ-aBcDeF	_adb-tls-connect._tcp.	192.168.1.5:37899
///     adb-R9CN4057BXJ-xYz123	_adb-tls-pairing._tcp.	192.168.1.5:41223
struct WirelessServiceParser: WirelessServiceParsing {

    private static let header = "List of discovered mdns services"

    func parse(_ output: String) -> [WirelessService] {
        var seen = Set<WirelessService>()
        var services: [WirelessService] = []

        for rawLine in output.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmed
            guard !line.isEmpty, !line.hasPrefix(Self.header), let service = parseService(line) else { continue }
            if seen.insert(service).inserted { services.append(service) }
        }
        return services.sorted(by: Self.isOrderedBefore)
    }

    /// Sorted by name; for the same name, the "connect" service comes before "pairing".
    private static func isOrderedBefore(_ lhs: WirelessService, _ rhs: WirelessService) -> Bool {
        if lhs.name != rhs.name { return lhs.name < rhs.name }
        return lhs.kind == .connect && rhs.kind == .pairing
    }

    private func parseService(_ line: String) -> WirelessService? {
        let tokens = line.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
        guard tokens.count >= 3, let kind = kind(of: tokens[1]), let endpoint = endpoint(from: tokens[2]) else {
            return nil
        }
        return WirelessService(name: tokens[0], kind: kind, host: endpoint.host, port: endpoint.port)
    }

    private func kind(of serviceType: String) -> WirelessService.Kind? {
        if serviceType.contains("_adb-tls-pairing") { return .pairing }
        if serviceType.contains("_adb-tls-connect") || serviceType.hasPrefix("_adb._tcp") { return .connect }
        return nil
    }

    /// `192.168.1.5:37899` -> (`192.168.1.5`, 37899). Addresses with no port or an out-of-range port are rejected.
    private func endpoint(from token: String) -> (host: String, port: Int)? {
        guard let colon = token.lastIndex(of: ":"),
              let port = Int(token[token.index(after: colon)...]),
              (1...65535).contains(port) else { return nil }
        let host = String(token[..<colon])
        return host.isEmpty ? nil : (host, port)
    }
}
