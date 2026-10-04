//
//  ADBService+Settings.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

/// Opens a settings screen on the device. Kept apart from `ADBServicing` so the main protocol stays small.
protocol DeviceSettingsOpening {
    /// Opens the Developer options screen on the selected device.
    func openDeveloperOptions(on serial: String, completion: @escaping (Result<Void, ADBError>) -> Void)
}

extension ADBService: DeviceSettingsOpening {

    private static let startTimeout: TimeInterval = 10
    private static let developerOptionsAction = "android.settings.APPLICATION_DEVELOPMENT_SETTINGS"

    func openDeveloperOptions(on serial: String, completion: @escaping (Result<Void, ADBError>) -> Void) {
        let arguments = ["-s", serial, "shell", "am", "start", "-a", Self.developerOptionsAction]
        execute(arguments, timeout: Self.startTimeout) { result in
            completion(result.flatMap(Self.verifyStarted))
        }
    }

    /// `am start` always exits 0, even when no activity matches; the failure only shows up as the line
    /// `Error: Activity not started, unable to resolve Intent …` (on stderr on Android 12).
    private static func verifyStarted(_ output: ProcessOutput) -> Result<Void, ADBError> {
        let lines = (output.stdout + "\n" + output.stderr)
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmed }
        if let error = lines.first(where: { $0.hasPrefix("Error") }) {
            return .failure(.commandFailed(error))
        }
        return .success(())
    }
}
