//
//  ADBService+Wireless.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

/// Service discovery only; separate from `WirelessControlling` so `DeviceMonitor`
/// does not depend on the connection commands.
protocol WirelessDiscovering {
    func discoverWireless(completion: @escaping (Result<[WirelessService], ADBError>) -> Void)
}

protocol WirelessControlling {
    /// `adb connect`. `address` has the form `host[:port]` (default port 5555).
    func connect(to address: String, completion: @escaping (Result<Void, ADBError>) -> Void)
    /// `adb disconnect <serial>`. Never runs `adb disconnect` without an argument, which drops every connection.
    func disconnect(serial: String, completion: @escaping (Result<Void, ADBError>) -> Void)
    /// `adb pair <host:port> <code>`; the pairing port is required.
    func pair(address: String, code: String, completion: @escaping (Result<Void, ADBError>) -> Void)
    /// Alamat IPv4 Wi-Fi sebuah device yang tersambung (biasanya lewat USB).
    func wifiAddress(of serial: String, completion: @escaping (Result<String, ADBError>) -> Void)
    /// `adb -s <serial> tcpip <port>`: moves adbd to TCP mode until the device is rebooted.
    func enableTCPIP(on serial: String, port: Int, completion: @escaping (Result<Void, ADBError>) -> Void)
}

extension ADBService: WirelessDiscovering, WirelessControlling {

    private static let discoverTimeout: TimeInterval = 5
    private static let connectTimeout: TimeInterval = 10
    private static let pairTimeout: TimeInterval = 20
    private static let shellTimeout: TimeInterval = 8

    // MARK: - Discovery

    func discoverWireless(completion: @escaping (Result<[WirelessService], ADBError>) -> Void) {
        execute(["mdns", "services"], timeout: Self.discoverTimeout) { [serviceParser] result in
            completion(result.map { serviceParser.parse($0.stdout) })
        }
    }

    // MARK: - Control

    func connect(to address: String, completion: @escaping (Result<Void, ADBError>) -> Void) {
        guard let normalized = WirelessAddress.normalized(address) else {
            completion(.failure(.invalidAddress))
            return
        }
        // `adb connect` always exits 0, even on failure; the result is only in the stdout text.
        execute(["connect", normalized], timeout: Self.connectTimeout) { result in
            completion(result.flatMap(Self.verifyConnected))
        }
    }

    func disconnect(serial: String, completion: @escaping (Result<Void, ADBError>) -> Void) {
        let target = serial.trimmed
        guard !target.isEmpty else {
            completion(.failure(.invalidAddress))
            return
        }
        execute(["disconnect", target], timeout: Self.connectTimeout) { result in
            completion(result.map { _ in () })
        }
    }

    func pair(address: String, code: String, completion: @escaping (Result<Void, ADBError>) -> Void) {
        guard let normalized = WirelessAddress.normalized(address, requirePort: true) else {
            completion(.failure(.invalidAddress))
            return
        }
        guard WirelessAddress.isValidPairingCode(code) else {
            completion(.failure(.invalidPairingCode))
            return
        }
        execute(["pair", normalized, code.trimmed], timeout: Self.pairTimeout) { result in
            completion(result.flatMap(Self.verifyPaired))
        }
    }

    func wifiAddress(of serial: String, completion: @escaping (Result<String, ADBError>) -> Void) {
        let routeQuery = ["-s", serial, "shell", "ip", "route", "get", "1.1.1.1"]
        let interfaceQuery = ["-s", serial, "shell", "ip", "-f", "inet", "addr", "show", "wlan0"]

        execute(routeQuery, timeout: Self.shellTimeout) { [weak self] first in
            if case .success(let output) = first, let address = WiFiAddressParser.ipv4(in: output.stdout) {
                completion(.success(address))
                return
            }
            // Only a command failure (for example `ip route get` is missing) may be retried another way.
            if case .failure(let error) = first, !Self.isCommandFailure(error) {
                completion(.failure(error))
                return
            }
            self?.execute(interfaceQuery, timeout: Self.shellTimeout) { second in
                switch second {
                case .success(let output):
                    let address = WiFiAddressParser.ipv4(in: output.stdout)
                    completion(address.map { .success($0) } ?? .failure(.noWiFiAddress))
                case .failure(let error):
                    completion(.failure(Self.isCommandFailure(error) ? .noWiFiAddress : error))
                }
            }
        }
    }

    func enableTCPIP(on serial: String, port: Int, completion: @escaping (Result<Void, ADBError>) -> Void) {
        guard (1...65535).contains(port) else {
            completion(.failure(.invalidAddress))
            return
        }
        execute(["-s", serial, "tcpip", String(port)], timeout: Self.connectTimeout) { result in
            completion(result.map { _ in () })
        }
    }

    // MARK: - Interpreting output

    private static func isCommandFailure(_ error: ADBError) -> Bool {
        if case .commandFailed = error { return true }
        return false
    }

    private static func verifyConnected(_ output: ProcessOutput) -> Result<Void, ADBError> {
        let text = output.stdout.trimmed
        let lowercased = text.lowercased()
        if lowercased.hasPrefix("connected to") || lowercased.hasPrefix("already connected to") {
            return .success(())
        }
        return .failure(.commandFailed(firstLine(of: text) ?? firstLine(of: output.stderr) ?? "adb connect failed."))
    }

    private static func verifyPaired(_ output: ProcessOutput) -> Result<Void, ADBError> {
        if output.stdout.lowercased().contains("successfully paired") { return .success(()) }
        let message = output.stdout
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmed }
            .first { !$0.isEmpty && !$0.hasPrefix("Enter pairing code") }
        return .failure(.commandFailed(message ?? firstLine(of: output.stderr) ?? "adb pair failed."))
    }
}
