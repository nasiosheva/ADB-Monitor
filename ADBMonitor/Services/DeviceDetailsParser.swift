//
//  DeviceDetailsParser.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

protocol DeviceDetailsParsing {
    func parse(_ output: String) -> DeviceDetails
}

/// Parses the output of `getprop ro.build.version.release; dumpsys battery`:
///
///     10
///     Current Battery Service state:
///       AC powered: false
///       level: 100
///       scale: 100
///
/// The first line is the Android version. The battery level is the line that is exactly `level: <number>`;
/// vendors add many other lines to `dumpsys battery`, so the match is anchored to the whole line.
struct DeviceDetailsParser: DeviceDetailsParsing {

    private static let versionPattern = #"^[A-Za-z0-9]+(\.[A-Za-z0-9]+)*$"#
    private static let levelPattern = #"^level:\s*(\d{1,3})$"#

    func parse(_ output: String) -> DeviceDetails {
        let lines = output.split(whereSeparator: \.isNewline).map { $0.trimmed }.filter { !$0.isEmpty }
        return DeviceDetails(androidVersion: version(in: lines), batteryLevel: batteryLevel(in: lines))
    }

    /// The first line, if it looks like a version ("10", "12", "13.1") and not like an error or a heading.
    private func version(in lines: [String]) -> String? {
        guard let first = lines.first, first.range(of: Self.versionPattern, options: .regularExpression) != nil else {
            return nil
        }
        return first
    }

    private func batteryLevel(in lines: [String]) -> Int? {
        for line in lines {
            guard let match = line.range(of: Self.levelPattern, options: .regularExpression),
                  let digits = line[match].split(separator: ":").last,
                  let level = Int(digits.trimmed), (0...100).contains(level) else { continue }
            return level
        }
        return nil
    }
}
