//
//  ADBService+Server.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

/// Restarts the adb server. Kept apart from `ADBServicing` so the main protocol stays small.
protocol ADBServerControlling {
    func restartServer(completion: @escaping (Result<Void, ADBError>) -> Void)
}

extension ADBService: ADBServerControlling {

    private static let serverTimeout: TimeInterval = 10

    /// `adb kill-server`, then `adb start-server`. Killing a server that is not running is not an error
    /// (it exits 0), so the restart also works when the server had already stopped.
    func restartServer(completion: @escaping (Result<Void, ADBError>) -> Void) {
        execute(["kill-server"], timeout: Self.serverTimeout) { [weak self] killed in
            if case .failure(let error) = killed {
                completion(.failure(error))
                return
            }
            self?.execute(["start-server"], timeout: Self.serverTimeout) { started in
                completion(started.map { _ in () })
            }
        }
    }
}
