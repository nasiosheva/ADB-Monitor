//
//  WirelessQRPairer.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

/// Waits for the phone to scan the QR code, then pairs with it.
@MainActor
protocol WirelessQRPairing: AnyObject {
    /// Starts waiting. `onPairing` is called when the phone is found and `adb pair` starts running;
    /// `completion` carries the pairing address on success. Not called if `cancel()` comes first.
    func start(credentials: PairingQRCredentials,
               onPairing: @escaping () -> Void,
               completion: @escaping (Result<String, ADBError>) -> Void)
    func cancel()
}

/// Polls `adb mdns services` until a pairing service with the same name as `credentials.name` appears,
/// then runs `adb pair <host:port> <password>`.
///
/// The next poll is scheduled after the current one finishes, so `adb` requests never pile up.
/// Discovery here does not depend on the "Detect devices on Wi-Fi" preference: the user asked for it explicitly.
@MainActor
final class WirelessQRPairer: WirelessQRPairing {

    private let discovery: WirelessDiscovering
    private let controller: WirelessControlling
    private let scheduler: Scheduling
    private let pollInterval: TimeInterval
    private let maxPolls: Int

    /// Incremented on every `start`/`cancel`; callbacks from an old session are dropped by comparing it.
    private var generation = 0
    private var pending: ScheduledTask?

    /// Default: 2 seconds x 60 = waits about 2 minutes.
    init(discovery: WirelessDiscovering,
         controller: WirelessControlling,
         scheduler: Scheduling,
         pollInterval: TimeInterval = 2,
         maxPolls: Int = 60) {
        self.discovery = discovery
        self.controller = controller
        self.scheduler = scheduler
        self.pollInterval = pollInterval
        self.maxPolls = maxPolls
    }

    func start(credentials: PairingQRCredentials,
               onPairing: @escaping () -> Void,
               completion: @escaping (Result<String, ADBError>) -> Void) {
        cancel()
        let session = generation
        poll(session: session, remaining: maxPolls, credentials: credentials,
             onPairing: onPairing, completion: completion)
    }

    func cancel() {
        generation += 1
        pending?.cancel()
        pending = nil
    }

    private func poll(session: Int,
                      remaining: Int,
                      credentials: PairingQRCredentials,
                      onPairing: @escaping () -> Void,
                      completion: @escaping (Result<String, ADBError>) -> Void) {
        discovery.discoverWireless { [weak self] result in
            guard let self = self, session == self.generation else { return }

            // A discovery failure (for example adb not ready yet) does not stop the wait; only the time limit does.
            let services = (try? result.get()) ?? []
            if let match = services.first(where: { $0.kind == .pairing && $0.name == credentials.name }) {
                self.pair(with: match, credentials: credentials, session: session,
                          onPairing: onPairing, completion: completion)
                return
            }
            if case .failure(let error) = result, Self.isFatal(error) {
                completion(.failure(error))
                return
            }
            guard remaining > 1 else {
                completion(.failure(.qrPairingTimedOut))
                return
            }
            self.pending = self.scheduler.schedule(after: self.pollInterval) { [weak self] in
                guard let self = self, session == self.generation else { return }
                self.poll(session: session, remaining: remaining - 1, credentials: credentials,
                          onPairing: onPairing, completion: completion)
            }
        }
    }

    private func pair(with service: WirelessService,
                      credentials: PairingQRCredentials,
                      session: Int,
                      onPairing: @escaping () -> Void,
                      completion: @escaping (Result<String, ADBError>) -> Void) {
        pending = nil
        onPairing()
        controller.pairWithQR(address: service.address, password: credentials.password) { [weak self] result in
            guard let self = self, session == self.generation else { return }
            completion(result.map { service.address })
        }
    }

    /// adb is missing or cannot be run: waiting longer will not help.
    private static func isFatal(_ error: ADBError) -> Bool {
        switch error {
        case .notFound, .launchFailed: return true
        default: return false
        }
    }
}
