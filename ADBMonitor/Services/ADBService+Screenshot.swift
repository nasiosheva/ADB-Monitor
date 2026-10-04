//
//  ADBService+Screenshot.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

/// Captures the screen of a device into a PNG file on the Mac.
protocol ScreenshotTaking {
    func takeScreenshot(of serial: String, to destination: URL, completion: @escaping (Result<Void, ADBError>) -> Void)
}

extension ADBService: ScreenshotTaking {

    private static let captureTimeout: TimeInterval = 20
    private static let pullTimeout: TimeInterval = 30
    private static let cleanupTimeout: TimeInterval = 10

    /// A fixed place the `shell` user can always write to. `adb exec-out screencap -p` would avoid the temporary
    /// file, but the process layer reads output as text, which would corrupt the PNG bytes.
    private static let remotePath = "/data/local/tmp/adbmonitor-screenshot.png"

    /// `screencap -p <file>` on the device, `pull` to the Mac, then delete the file on the device again.
    func takeScreenshot(of serial: String,
                        to destination: URL,
                        completion: @escaping (Result<Void, ADBError>) -> Void) {
        guard !serial.trimmed.isEmpty else {
            completion(.failure(.commandFailed("Missing serial number.")))
            return
        }
        let remote = Self.remotePath
        execute(["-s", serial, "shell", "screencap", "-p", remote], timeout: Self.captureTimeout) { captured in
            if case .failure(let error) = captured {
                completion(.failure(error))
                return
            }
            self.execute(["-s", serial, "pull", remote, destination.path], timeout: Self.pullTimeout) { pulled in
                // The result of the cleanup does not matter: the screenshot is already on the Mac (or the pull failed).
                self.execute(["-s", serial, "shell", "rm", "-f", remote], timeout: Self.cleanupTimeout) { _ in
                    completion(pulled.map { _ in () })
                }
            }
        }
    }
}
