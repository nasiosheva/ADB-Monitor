//
//  WirelessSwitcher.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

@MainActor
protocol WirelessSwitching: AnyObject {
    /// Moves a device connected over USB to Wi-Fi. On success the result holds the connected `ip:port` address.
    func switchToWireless(serial: String, completion: @escaping (Result<String, ADBError>) -> Void)
}

/// Multi-step flow: find the device's Wi-Fi IP, `adb tcpip`, then `adb connect` with retries.
///
/// `adbd` needs time to restart in TCP mode, so each connect attempt is preceded by a delay
/// (through `Scheduling`, so it can be tested without really waiting).
///
/// The closures here hold `self` strongly on purpose: a running flow must finish and call
/// `completion` even if its owner has released the switcher (the flow used to die silently before).
/// There is no retain cycle because the switcher stores no closure; the whole chain ends
/// when the flow finishes.
@MainActor
final class WirelessSwitcher: WirelessSwitching {

    private let controller: WirelessControlling
    private let scheduler: Scheduling
    private let port: Int
    private let retryDelay: TimeInterval
    private let maxAttempts: Int

    init(controller: WirelessControlling,
         scheduler: Scheduling,
         port: Int = WirelessAddress.defaultPort,
         retryDelay: TimeInterval = 1,
         maxAttempts: Int = 6) {
        self.controller = controller
        self.scheduler = scheduler
        self.port = port
        self.retryDelay = retryDelay
        self.maxAttempts = maxAttempts
    }

    func switchToWireless(serial: String, completion: @escaping (Result<String, ADBError>) -> Void) {
        controller.wifiAddress(of: serial) { result in
            switch result {
            case .failure(let error): completion(.failure(error))
            case .success(let ip): self.enableTCPIP(serial: serial, ip: ip, completion: completion)
            }
        }
    }

    private func enableTCPIP(serial: String, ip: String, completion: @escaping (Result<String, ADBError>) -> Void) {
        controller.enableTCPIP(on: serial, port: port) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success:
                let address = "\(ip):\(self.port)"
                self.connect(to: address, attemptsLeft: self.maxAttempts, completion: completion)
            }
        }
    }

    private func connect(to address: String,
                         attemptsLeft: Int,
                         completion: @escaping (Result<String, ADBError>) -> Void) {
        _ = scheduler.schedule(after: retryDelay) {
            self.controller.connect(to: address) { result in
                switch result {
                case .success:
                    completion(.success(address))
                case .failure where attemptsLeft > 1:
                    self.connect(to: address, attemptsLeft: attemptsLeft - 1, completion: completion)
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
}
