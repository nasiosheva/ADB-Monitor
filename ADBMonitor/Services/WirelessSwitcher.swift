//
//  WirelessSwitcher.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

@MainActor
protocol WirelessSwitching: AnyObject {
    /// Memindahkan device yang tersambung lewat USB ke Wi-Fi. Hasil sukses berisi alamat `ip:port` yang tersambung.
    func switchToWireless(serial: String, completion: @escaping (Result<String, ADBError>) -> Void)
}

/// Alur beberapa langkah: cari IP Wi-Fi device, `adb tcpip`, lalu `adb connect` dengan percobaan ulang.
///
/// `adbd` perlu waktu untuk restart dalam mode TCP, jadi setiap percobaan connect didahului jeda
/// (lewat `Scheduling`, sehingga bisa diuji tanpa menunggu sungguhan).
///
/// Closure di sini memegang `self` dengan kuat, sengaja: alur yang sedang berjalan harus selesai dan
/// memanggil `completion` walaupun pemiliknya sudah melepas switcher (sebelumnya alur bisa mati diam-diam).
/// Tidak ada siklus retain karena switcher tidak menyimpan closure apa pun; seluruh rantai berakhir
/// saat alurnya selesai.
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
