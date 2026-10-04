//
//  FastbootDeviceParser.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

protocol FastbootDeviceParsing {
    func parse(_ output: String) -> [FastbootDevice]
}

/// Parses the output of `fastboot devices`: one device per line, the serial and the mode separated by a tab
/// or spaces.
///
///     ZY22XXXXXX	fastboot
///     ZY22YYYYYY	fastbootd
struct FastbootDeviceParser: FastbootDeviceParsing {

    func parse(_ output: String) -> [FastbootDevice] {
        var seen = Set<String>()
        var devices: [FastbootDevice] = []
        for rawLine in output.split(whereSeparator: \.isNewline) {
            let tokens = rawLine.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
            // Skip waiting messages such as "< waiting for any device >", which have no separate mode token.
            guard tokens.count >= 2, !tokens[0].hasPrefix("<"), seen.insert(tokens[0]).inserted else { continue }
            devices.append(FastbootDevice(serial: tokens[0], mode: tokens[1]))
        }
        return devices.sorted { $0.serial.localizedStandardCompare($1.serial) == .orderedAscending }
    }
}
