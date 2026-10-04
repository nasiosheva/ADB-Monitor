//
//  DeviceListParser.swift
//  ADBMonitor
//

import Foundation

protocol DeviceListParsing {
    func parse(_ output: String) -> [ADBDevice]
}

/// Mem-parse output `adb devices -l`, misalnya:
///
///     List of devices attached
///     R58M123ABC   device usb:1-1 product:o1sxxx model:SM_G991B device:o1s transport_id:2
///     R9CN4057BXJ  device 2-1 product:a10sxx model:SM_A107F device:a10s transport_id:1
///     emulator-5554 offline transport_id:1
///     0123456789   no permissions (user in plugdev group; are your udev rules wrong?); see [url]
struct DeviceListParser: DeviceListParsing {

    private static let headerPrefix = "List of devices attached"
    private static let attributeKeys: Set<String> = ["product", "model", "device", "transport_id", "usb"]
    /// adb versi baru menulis path USB tanpa prefix ("2-1"), versi lama dengan "usb:1-1".
    private static let bareUSBPathPattern = #"^\d+-[\d.]+$"#

    func parse(_ output: String) -> [ADBDevice] {
        let lines = output.split(whereSeparator: \.isNewline).map { $0.trimmed }
        guard let header = lines.firstIndex(where: { $0.hasPrefix(Self.headerPrefix) }) else { return [] }

        return lines[(header + 1)...]
            .compactMap(parseDevice)
            .sorted { $0.serial.localizedStandardCompare($1.serial) == .orderedAscending }
    }

    // MARK: - Line parsing

    private func parseDevice(from line: String) -> ADBDevice? {
        // Baris yang diawali "*" adalah pesan daemon, misalnya "* daemon started successfully".
        guard !line.isEmpty, !line.hasPrefix("*") else { return nil }

        let tokens = line.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
        guard tokens.count >= 2 else { return nil }

        let (state, attributeTokens) = parseState(from: tokens.dropFirst())
        let attributes = parseAttributes(from: attributeTokens)

        return ADBDevice(serial: tokens[0],
                         state: state,
                         model: attributes["model"].map(makeReadable),
                         product: attributes["product"],
                         deviceName: attributes["device"],
                         transportID: attributes["transport_id"],
                         usbPath: attributes["usb"])
    }

    /// State "no permissions" terdiri dari dua kata sehingga perlu penanganan khusus.
    private func parseState(from tokens: ArraySlice<String>) -> (ADBDevice.State, ArraySlice<String>) {
        guard let first = tokens.first else { return (.unknown(""), []) }
        if first == "no", tokens.dropFirst().first == "permissions" {
            return (.noPermissions, tokens.dropFirst(2))
        }
        return (ADBDevice.State(adbValue: first), tokens.dropFirst())
    }

    private func parseAttributes(from tokens: ArraySlice<String>) -> [String: String] {
        var attributes: [String: String] = [:]
        for token in tokens {
            if attributes["usb"] == nil, token.range(of: Self.bareUSBPathPattern, options: .regularExpression) != nil {
                attributes["usb"] = token
            } else if let (key, value) = splitKeyValue(token), Self.attributeKeys.contains(key) {
                attributes[key] = value
            }
        }
        return attributes
    }

    private func splitKeyValue(_ token: String) -> (String, String)? {
        guard let colon = token.firstIndex(of: ":") else { return nil }
        return (String(token[..<colon]), String(token[token.index(after: colon)...]))
    }

    /// `Pixel_6_Pro` -> `Pixel 6 Pro`
    private func makeReadable(_ value: String) -> String {
        value.replacingOccurrences(of: "_", with: " ")
    }
}
