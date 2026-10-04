//
//  ADBService+Details.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

/// Reads extra information from a connected device. Kept apart from `ADBServicing` so the main protocol stays small.
protocol DeviceDetailsReading {
    func readDetails(of serial: String, completion: @escaping (Result<DeviceDetails, ADBError>) -> Void)
}

extension ADBService: DeviceDetailsReading {

    private static let detailsTimeout: TimeInterval = 8

    /// One shell command for both values. `exit 0` at the end keeps the Android version even when `dumpsys battery`
    /// fails (adb reports the exit status of the last command, and a non-zero status would drop the output).
    private static let detailsCommand = "getprop ro.build.version.release; dumpsys battery 2>/dev/null; exit 0"

    func readDetails(of serial: String, completion: @escaping (Result<DeviceDetails, ADBError>) -> Void) {
        execute(["-s", serial, "shell", Self.detailsCommand], timeout: Self.detailsTimeout) { [detailsParser] result in
            completion(result.map { detailsParser.parse($0.stdout) })
        }
    }
}
