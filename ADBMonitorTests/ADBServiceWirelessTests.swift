//
//  ADBServiceWirelessTests.swift
//  ADBMonitorTests
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import XCTest
@testable import ADBMonitor

/// The `adb` results in these tests mimic behavior observed with adb 35.0.1 (see the comment on each test).
final class ADBServiceWirelessTests: XCTestCase {

    private func ok(_ stdout: String = "") -> Result<ProcessOutput, ProcessError> {
        .success(output(stdout))
    }

    private func failed(stderr: String, stdout: String = "", exit: Int32 = 1) -> Result<ProcessOutput, ProcessError> {
        .success(output(stdout, stderr: stderr, exit: exit))
    }

    private func makeService(_ results: [Result<ProcessOutput, ProcessError>]) -> (ADBService, SequencedProcessRunner) {
        let runner = SequencedProcessRunner(results)
        let service = ADBService(pathProvider: StubPathProvider(adbPath: nil),
                                 locator: StubLocator(result: "/x/adb"),
                                 parser: DeviceListParser(),
                                 runner: runner)
        return (service, runner)
    }

    /// Runs a `Result<Void, _>` operation and returns its error (`nil` = success).
    private func errorOf(_ operation: (@escaping (Result<Void, ADBError>) -> Void) -> Void) -> ADBError? {
        var result: Result<Void, ADBError>?
        operation { result = $0 }
        guard let result = result else { return .commandFailed("completion tidak dipanggil") }
        if case .failure(let error) = result { return error }
        return nil
    }

    // MARK: Discovery

    func testDiscoverRunsMdnsServicesAndParsesTheOutput() throws {
        let list = "List of discovered mdns services\nadb-X-aBcDeF\t_adb-tls-connect._tcp.\t192.168.1.5:37899\n"
        let (service, runner) = makeService([ok(list)])
        var services: [WirelessService] = []
        service.discoverWireless { services = (try? $0.get()) ?? [] }
        XCTAssertEqual(runner.calls, [["mdns", "services"]])
        XCTAssertEqual(services.map(\.address), ["192.168.1.5:37899"])
    }

    func testDiscoverFailureIsReported() {
        let (service, _) = makeService([failed(stderr: "error: mdns unavailable")])
        var result: Result<[WirelessService], ADBError>?
        service.discoverWireless { result = $0 }
        XCTAssertEqual(result, .failure(.commandFailed("error: mdns unavailable")))
    }

    // MARK: connect (adb connect always exits 0, the result is only in stdout)

    func testConnectSuccess() {
        let (service, runner) = makeService([ok("connected to 192.168.1.5:5555\n")])
        XCTAssertNil(errorOf { service.connect(to: "192.168.1.5:5555", completion: $0) })
        XCTAssertEqual(runner.calls, [["connect", "192.168.1.5:5555"]])
    }

    func testAlreadyConnectedCountsAsSuccess() {
        let (service, _) = makeService([ok("already connected to 192.168.1.5:5555\n")])
        XCTAssertNil(errorOf { service.connect(to: "192.168.1.5:5555", completion: $0) })
    }

    func testConnectFailureWithExitZeroIsStillAFailure() {
        let (service, _) = makeService([ok("failed to connect to '192.168.1.250:5555': No route to host\n")])
        XCTAssertEqual(errorOf { service.connect(to: "192.168.1.250:5555", completion: $0) },
                       .commandFailed("failed to connect to '192.168.1.250:5555': No route to host"))
    }

    func testConnectResolveFailure() {
        let text = "failed to resolve host: 'not-a-host': nodename nor servname provided, or not known"
        let (service, _) = makeService([ok(text + "\n")])
        XCTAssertEqual(errorOf { service.connect(to: "not-a-host", completion: $0) }, .commandFailed(text))
    }

    func testConnectAppliesTheDefaultPort() {
        let (service, runner) = makeService([ok("connected to 192.168.1.5:5555")])
        XCTAssertNil(errorOf { service.connect(to: " 192.168.1.5 ", completion: $0) })
        XCTAssertEqual(runner.calls, [["connect", "192.168.1.5:5555"]])
    }

    func testConnectRejectsInvalidAddressesWithoutRunningAdb() {
        let (service, runner) = makeService([])
        for bad in ["", "bad host", "1.2.3.4:99999", "1.2.3.4;ls", "-x"] {
            XCTAssertEqual(errorOf { service.connect(to: bad, completion: $0) }, .invalidAddress, bad)
        }
        XCTAssertTrue(runner.calls.isEmpty)
    }

    func testConnectWithEmptyOutputIsAFailure() {
        let (service, _) = makeService([ok("")])
        XCTAssertEqual(errorOf { service.connect(to: "1.2.3.4", completion: $0) },
                       .commandFailed("adb connect failed."))
    }

    // MARK: disconnect (without an argument, adb drops ALL connections)

    func testDisconnectPassesTheSerial() {
        let (service, runner) = makeService([ok("disconnected 192.168.1.5:5555\n")])
        XCTAssertNil(errorOf { service.disconnect(serial: "192.168.1.5:5555", completion: $0) })
        XCTAssertEqual(runner.calls, [["disconnect", "192.168.1.5:5555"]])
    }

    func testDisconnectNeverRunsWithoutASerial() {
        let (service, runner) = makeService([])
        XCTAssertEqual(errorOf { service.disconnect(serial: "", completion: $0) }, .invalidAddress)
        XCTAssertEqual(errorOf { service.disconnect(serial: "   ", completion: $0) }, .invalidAddress)
        XCTAssertTrue(runner.calls.isEmpty, "`adb disconnect` tanpa argumen memutus semua koneksi")
    }

    func testDisconnectUnknownDeviceReportsAdbMessage() {
        let (service, _) = makeService([failed(stderr: "error: no such device '1.2.3.4:5555'\n")])
        XCTAssertEqual(errorOf { service.disconnect(serial: "1.2.3.4:5555", completion: $0) },
                       .commandFailed("error: no such device '1.2.3.4:5555'"))
    }

    // MARK: pair

    func testPairSuccess() {
        let text = "Successfully paired to 192.168.1.5:41223 [guid=adb-X-aBcDeF]\n"
        let (service, runner) = makeService([ok(text)])
        XCTAssertNil(errorOf { service.pair(address: "192.168.1.5:41223", code: " 123456 ", completion: $0) })
        XCTAssertEqual(runner.calls, [["pair", "192.168.1.5:41223", "123456"]])
    }

    func testPairRequiresAPortAndASixDigitCodeAndRunsNothingOtherwise() {
        let (service, runner) = makeService([])
        XCTAssertEqual(errorOf { service.pair(address: "192.168.1.5", code: "123456", completion: $0) },
                       .invalidAddress)
        XCTAssertEqual(errorOf { service.pair(address: "192.168.1.5:41223", code: "12345", completion: $0) },
                       .invalidPairingCode)
        XCTAssertEqual(errorOf { service.pair(address: "192.168.1.5:41223", code: "abcdef", completion: $0) },
                       .invalidPairingCode)
        XCTAssertTrue(runner.calls.isEmpty)
    }

    func testPairFailureUsesStderr() {
        let (service, _) = makeService([failed(stderr: "error: protocol fault (couldn't read status message)\n")])
        XCTAssertEqual(errorOf { service.pair(address: "1.2.3.4:5", code: "123456", completion: $0) },
                       .commandFailed("error: protocol fault (couldn't read status message)"))
    }

    func testPairWithExitZeroButNoSuccessTextIsAFailure() {
        let text = "Enter pairing code: \nFailed: Wrong password or connection was dropped.\n"
        let (service, _) = makeService([ok(text)])
        XCTAssertEqual(errorOf { service.pair(address: "1.2.3.4:5", code: "123456", completion: $0) },
                       .commandFailed("Failed: Wrong password or connection was dropped."))
    }

    // MARK: wifiAddress

    private func wifi(_ service: ADBService) -> Result<String, ADBError> {
        var result: Result<String, ADBError>?
        service.wifiAddress(of: "SER", completion: { result = $0 })
        return result ?? .failure(.commandFailed("completion tidak dipanggil"))
    }

    func testWifiAddressFromIpRouteGet() {
        let (service, runner) = makeService([ok("1.1.1.1 via 192.168.1.1 dev wlan0 src 192.168.1.23 uid 2000\n")])
        XCTAssertEqual(wifi(service), .success("192.168.1.23"))
        XCTAssertEqual(runner.calls, [["-s", "SER", "shell", "ip", "route", "get", "1.1.1.1"]])
    }

    func testWifiAddressFallsBackToTheInterfaceWhenRouteHasNoSource() {
        let iface = "    inet 10.0.0.42/24 brd 10.0.0.255 scope global wlan0\n"
        let (service, runner) = makeService([ok("unreachable\n"), ok(iface)])
        XCTAssertEqual(wifi(service), .success("10.0.0.42"))
        XCTAssertEqual(runner.calls.last, ["-s", "SER", "shell", "ip", "-f", "inet", "addr", "show", "wlan0"])
    }

    func testWifiAddressFallsBackWhenTheRouteCommandFails() {
        let iface = "inet 10.0.0.42/24 scope global wlan0"
        let (service, runner) = makeService([failed(stderr: "ip: bad argument"), ok(iface)])
        XCTAssertEqual(wifi(service), .success("10.0.0.42"))
        XCTAssertEqual(runner.calls.count, 2)
    }

    func testWifiAddressDoesNotFallBackOnTimeouts() {
        let (service, runner) = makeService([.failure(.timedOut)])
        XCTAssertEqual(wifi(service), .failure(.timedOut))
        XCTAssertEqual(runner.calls.count, 1)
    }

    func testWifiAddressReportsNoAddressWhenNothingIsFound() {
        let (service, _) = makeService([ok("unreachable\n"), ok("inet 127.0.0.1/8 scope host lo\n")])
        XCTAssertEqual(wifi(service), .failure(.noWiFiAddress))
    }

    func testWifiAddressReportsNoAddressWhenBothCommandsFail() {
        let (service, _) = makeService([failed(stderr: "a"), failed(stderr: "b")])
        XCTAssertEqual(wifi(service), .failure(.noWiFiAddress))
    }

    // MARK: enableTCPIP

    func testEnableTCPIPArguments() {
        let (service, runner) = makeService([ok("restarting in TCP mode port: 5555\n")])
        XCTAssertNil(errorOf { service.enableTCPIP(on: "SER", port: 5555, completion: $0) })
        XCTAssertEqual(runner.calls, [["-s", "SER", "tcpip", "5555"]])
    }

    func testEnableTCPIPRejectsInvalidPorts() {
        let (service, runner) = makeService([])
        XCTAssertEqual(errorOf { service.enableTCPIP(on: "SER", port: 0, completion: $0) }, .invalidAddress)
        XCTAssertEqual(errorOf { service.enableTCPIP(on: "SER", port: 70000, completion: $0) }, .invalidAddress)
        XCTAssertTrue(runner.calls.isEmpty)
    }

    func testEnableTCPIPFailure() {
        let (service, _) = makeService([failed(stderr: "error: device offline\n")])
        XCTAssertEqual(errorOf { service.enableTCPIP(on: "SER", port: 5555, completion: $0) },
                       .commandFailed("error: device offline"))
    }

    // MARK: General

    func testWirelessCommandsReportMissingAdb() {
        let service = ADBService(pathProvider: StubPathProvider(adbPath: "/custom"),
                                 locator: StubLocator(result: nil),
                                 parser: DeviceListParser(),
                                 runner: SequencedProcessRunner([]))
        XCTAssertEqual(errorOf { service.connect(to: "1.2.3.4", completion: $0) }, .notFound(customPath: "/custom"))
    }
}
