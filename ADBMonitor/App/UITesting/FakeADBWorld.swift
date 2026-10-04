//
//  FakeADBWorld.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

#if DEBUG
import Foundation

/// Simulated `adb` world: answers commands like the real adb and changes as commands run
/// (connect adds a device, disconnect removes it, pair moves a service, and so on).
/// Output formats mimic what was observed with adb 35.0.1.
final class FakeADBWorld {

    struct Device {
        var serial: String
        var state: String
        var product: String
        var model: String
        var deviceName: String
        var usbPath: String?
    }

    struct Service {
        var name: String
        var type: String
        var address: String
    }

    static let pixelSerial = "PIXEL3A001"
    static let samsungSerial = "SAMSUNG0001"
    static let tabletAddress = "192.168.1.7:5555"
    /// Address whose `adb connect` always fails, used to test the error dialog.
    static let unreachableHost = "10.0.0.99"
    static let validPairingCode = "123456"
    static let pixelWifiAddress = "192.168.1.50"

    private(set) var devices: [Device]
    private(set) var services: [Service]
    private let scenario: UITestScenario
    private var nextTransportID = 1

    init(scenario: UITestScenario) {
        self.scenario = scenario
        switch scenario {
        case .devices:
            devices = [
                Device(serial: Self.pixelSerial, state: "device", product: "sargo", model: "Pixel_3a",
                       deviceName: "sargo", usbPath: "1-1"),
                Device(serial: Self.samsungSerial, state: "unauthorized", product: "a10sxx", model: "SM_A107F",
                       deviceName: "a10s", usbPath: "2-1"),
                Device(serial: Self.tabletAddress, state: "device", product: "tab", model: "Galaxy_Tab",
                       deviceName: "gts", usbPath: nil),
            ]
            services = [
                Service(name: "adb-TABLET9-aBcDeF", type: "_adb-tls-connect._tcp.", address: "192.168.1.20:37899"),
                Service(name: "adb-PHONE77-xYz123", type: "_adb-tls-pairing._tcp.", address: "192.168.1.21:41223"),
            ]
        case .empty, .adbMissing, .adbError:
            devices = []
            services = []
        }
    }

    // MARK: - Commands

    struct Output {
        var stdout: String = ""
        var stderr: String = ""
        var exitCode: Int32 = 0
    }

    /// Runs one adb command (arguments without the executable name) and returns its output.
    func run(_ arguments: [String]) -> Output {
        if scenario == .adbError { return Output(stderr: "adb server version (40) doesn't match this client (41)\n", exitCode: 1) }

        var args = arguments
        var serial: String?
        if args.first == "-s", args.count >= 2 {
            serial = args[1]
            args.removeFirst(2)
        }

        switch (serial, args.first ?? "") {
        case (nil, "devices"): return listDevices()
        case (nil, "mdns"): return listServices()
        case (nil, "connect"): return connect(args.dropFirst().first ?? "")
        case (nil, "disconnect"): return disconnect(args.dropFirst().first ?? "")
        case (nil, "pair"): return pair(Array(args.dropFirst()))
        case (let serial?, "reboot"): return Output(stdout: knows(serial) ? "" : "", exitCode: knows(serial) ? 0 : 1)
        case (let serial?, "tcpip"): return Output(stdout: "restarting in TCP mode port: \(args.dropFirst().first ?? "")\n",
                                                   exitCode: knows(serial) ? 0 : 1)
        case (let serial?, "shell"): return shell(serial: serial, Array(args.dropFirst()))
        default: return Output(stderr: "adb: unknown command \(args.first ?? "")\n", exitCode: 1)
        }
    }

    private func knows(_ serial: String) -> Bool { devices.contains { $0.serial == serial } }

    private func listDevices() -> Output {
        var lines = ["List of devices attached"]
        for (index, device) in devices.enumerated() {
            var line = "\(device.serial)    \(device.state)"
            if let usb = device.usbPath { line += " \(usb)" }
            if device.state == "device" {
                line += " product:\(device.product) model:\(device.model) device:\(device.deviceName)"
            }
            lines.append(line + " transport_id:\(index + 1)")
        }
        return Output(stdout: lines.joined(separator: "\n") + "\n")
    }

    private func listServices() -> Output {
        let rows = services.map { "\($0.name)\t\($0.type)\t\($0.address)" }
        return Output(stdout: (["List of discovered mdns services"] + rows).joined(separator: "\n") + "\n")
    }

    private func connect(_ address: String) -> Output {
        if address.hasPrefix(Self.unreachableHost) {
            return Output(stdout: "failed to connect to '\(address)': Connection refused\n")   // exit 0, as in real adb
        }
        if devices.contains(where: { $0.serial == address }) {
            return Output(stdout: "already connected to \(address)\n")
        }
        devices.append(Device(serial: address, state: "device", product: "wifi", model: "Wi-Fi_Device",
                              deviceName: "wifi", usbPath: nil))
        services.removeAll { $0.address == address && $0.type.contains("connect") }
        return Output(stdout: "connected to \(address)\n")
    }

    private func disconnect(_ serial: String) -> Output {
        guard devices.contains(where: { $0.serial == serial }) else {
            return Output(stderr: "error: no such device '\(serial)'\n", exitCode: 1)
        }
        devices.removeAll { $0.serial == serial }
        return Output(stdout: "disconnected \(serial)\n")
    }

    private func pair(_ args: [String]) -> Output {
        guard args.count == 2 else { return Output(stderr: "adb: No pairing code provided\n", exitCode: 1) }
        let (address, code) = (args[0], args[1])
        guard code == Self.validPairingCode,
              let service = services.first(where: { $0.address == address && $0.type.contains("pairing") }) else {
            return Output(stdout: "Enter pairing code: \nFailed: Wrong password or connection was dropped.\n")
        }
        services.removeAll { $0.address == address }
        let host = address.split(separator: ":").first.map(String.init) ?? address
        services.append(Service(name: service.name, type: "_adb-tls-connect._tcp.", address: "\(host):37001"))
        return Output(stdout: "Successfully paired to \(address) [guid=\(service.name)]\n")
    }

    private func shell(serial: String, _ args: [String]) -> Output {
        guard knows(serial) else { return Output(stderr: "adb: device '\(serial)' not found\n", exitCode: 1) }
        switch args.prefix(2).joined(separator: " ") {
        case "reboot -p":
            return Output()
        case "am start":
            return Output(stdout: "Starting: Intent { act=android.settings.APPLICATION_DEVELOPMENT_SETTINGS }\n")
        case "ip route":
            return Output(stdout: "1.1.1.1 via 192.168.1.1 dev wlan0 src \(Self.pixelWifiAddress) uid 2000\n")
        default:
            return Output()
        }
    }
}
#endif
