//
//  FastbootService.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

/// Lists devices that are in fastboot mode.
protocol FastbootListing {
    func listFastboot(completion: @escaping (Result<[FastbootDevice], ADBError>) -> Void)
}

/// Controls a device that is in fastboot mode.
protocol FastbootControlling {
    /// `fastboot -s <serial> reboot`: leaves fastboot and starts the device normally.
    func reboot(serial: String, completion: @escaping (Result<Void, ADBError>) -> Void)
}

/// Runs `fastboot`. It is found the same way as `adb` (the same locator class with another executable name),
/// and the custom ADB path of the user does not apply to it.
final class FastbootService: FastbootListing, FastbootControlling {

    private static let listTimeout: TimeInterval = 5
    private static let rebootTimeout: TimeInterval = 10

    private let locator: ADBLocating
    private let parser: FastbootDeviceParsing
    private let runner: ProcessRunning

    init(locator: ADBLocating, parser: FastbootDeviceParsing = FastbootDeviceParser(), runner: ProcessRunning) {
        self.locator = locator
        self.parser = parser
        self.runner = runner
    }

    func listFastboot(completion: @escaping (Result<[FastbootDevice], ADBError>) -> Void) {
        execute(["devices"], timeout: Self.listTimeout) { [parser] result in
            completion(result.map { parser.parse($0.stdout) })
        }
    }

    func reboot(serial: String, completion: @escaping (Result<Void, ADBError>) -> Void) {
        guard !serial.trimmed.isEmpty else {
            completion(.failure(.invalidAddress))
            return
        }
        execute(["-s", serial, "reboot"], timeout: Self.rebootTimeout) { result in
            completion(result.map { _ in () })
        }
    }

    private func execute(_ arguments: [String],
                         timeout: TimeInterval,
                         completion: @escaping (ADBService.CommandResult) -> Void) {
        guard let path = locator.locate(customPath: nil) else {
            completion(.failure(.notFound(customPath: nil)))
            return
        }
        runner.run(executable: path, arguments: arguments, timeout: timeout) { result in
            completion(ADBService.interpret(result, customPath: nil))
        }
    }
}
