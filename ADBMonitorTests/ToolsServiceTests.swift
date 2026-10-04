//
//  ToolsServiceTests.swift
//  ADBMonitorTests
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import XCTest
@testable import ADBMonitor

final class DeviceDetailsReadingTests: XCTestCase {

    private func makeService(_ results: [Result<ProcessOutput, ProcessError>],
                             located: String? = "/x/adb") -> (ADBService, SequencedProcessRunner) {
        let runner = SequencedProcessRunner(results)
        let service = ADBService(pathProvider: StubPathProvider(adbPath: nil),
                                 locator: StubLocator(result: located),
                                 parser: DeviceListParser(),
                                 runner: runner)
        return (service, runner)
    }

    private func read(_ service: ADBService) -> Result<DeviceDetails, ADBError>? {
        var result: Result<DeviceDetails, ADBError>?
        service.readDetails(of: "SER") { result = $0 }
        return result
    }

    func testReadsVersionAndBatteryWithOneShellCommand() throws {
        let (service, runner) = makeService([.success(output("12\nCurrent Battery Service state:\n  level: 87\n"))])
        XCTAssertEqual(try read(service)?.get(), DeviceDetails(androidVersion: "12", batteryLevel: 87))
        let command = "getprop ro.build.version.release; dumpsys battery 2>/dev/null; exit 0"
        XCTAssertEqual(runner.calls, [["-s", "SER", "shell", command]])
    }

    func testAFailingCommandIsAnError() {
        let (service, _) = makeService([.success(output(stderr: "error: device offline\n", exit: 1))])
        guard case .failure(let error)? = read(service) else { return XCTFail("expected a failure") }
        XCTAssertEqual(error, .commandFailed("error: device offline"))
    }

    func testAdbNotFound() {
        let (service, runner) = makeService([], located: nil)
        guard case .failure(let error)? = read(service) else { return XCTFail("expected a failure") }
        XCTAssertEqual(error, .notFound(customPath: nil))
        XCTAssertTrue(runner.calls.isEmpty)
    }
}

final class ADBServerRestartTests: XCTestCase {

    private func makeService(_ results: [Result<ProcessOutput, ProcessError>],
                             located: String? = "/x/adb") -> (ADBService, SequencedProcessRunner) {
        let runner = SequencedProcessRunner(results)
        let service = ADBService(pathProvider: StubPathProvider(adbPath: nil),
                                 locator: StubLocator(result: located),
                                 parser: DeviceListParser(),
                                 runner: runner)
        return (service, runner)
    }

    private func restart(_ service: ADBService) -> ADBError? {
        var result: Result<Void, ADBError>?
        service.restartServer { result = $0 }
        guard let result = result else { return .commandFailed("completion tidak dipanggil") }
        if case .failure(let error) = result { return error }
        return nil
    }

    func testKillsThenStartsTheServer() {
        let (service, runner) = makeService([.success(output()), .success(output("* daemon started successfully\n"))])
        XCTAssertNil(restart(service))
        XCTAssertEqual(runner.calls, [["kill-server"], ["start-server"]])
    }

    func testStopsWhenKillFails() {
        let (service, runner) = makeService([.success(output(stderr: "cannot kill\n", exit: 1))])
        XCTAssertEqual(restart(service), .commandFailed("cannot kill"))
        XCTAssertEqual(runner.calls, [["kill-server"]], "the server must not be started after a failed kill")
    }

    func testReportsAFailedStart() {
        let (service, _) = makeService([.success(output()), .success(output(stderr: "cannot bind\n", exit: 1))])
        XCTAssertEqual(restart(service), .commandFailed("cannot bind"))
    }

    func testTimeoutOnStart() {
        let (service, _) = makeService([.success(output()), .failure(.timedOut)])
        XCTAssertEqual(restart(service), .timedOut)
    }

    func testAdbNotFound() {
        let (service, runner) = makeService([], located: nil)
        XCTAssertEqual(restart(service), .notFound(customPath: nil))
        XCTAssertTrue(runner.calls.isEmpty)
    }
}

final class FastbootServiceTests: XCTestCase {

    private func makeService(_ result: Result<ProcessOutput, ProcessError>,
                             located: String? = "/x/fastboot",
                             locator: StubLocator? = nil) -> (FastbootService, FakeProcessRunner) {
        let runner = FakeProcessRunner(result)
        return (FastbootService(locator: locator ?? StubLocator(result: located), runner: runner), runner)
    }

    private func list(_ service: FastbootService) -> Result<[FastbootDevice], ADBError>? {
        var result: Result<[FastbootDevice], ADBError>?
        service.listFastboot { result = $0 }
        return result
    }

    private func reboot(_ service: FastbootService, serial: String = "ZY22") -> ADBError? {
        var result: Result<Void, ADBError>?
        service.reboot(serial: serial) { result = $0 }
        guard let result = result else { return .commandFailed("completion tidak dipanggil") }
        if case .failure(let error) = result { return error }
        return nil
    }

    func testListParsesStdoutAndUsesCorrectArguments() throws {
        let (service, runner) = makeService(.success(output("ZY22\tfastboot\n")))
        XCTAssertEqual(try list(service)?.get(), [FastbootDevice(serial: "ZY22", mode: "fastboot")])
        XCTAssertEqual(runner.calls.first?.executable, "/x/fastboot")
        XCTAssertEqual(runner.calls.first?.arguments, ["devices"])
        XCTAssertEqual(runner.calls.first?.timeout, 5)
    }

    func testListWithNoDevicesIsEmpty() throws {
        let (service, _) = makeService(.success(output("")))
        XCTAssertEqual(try list(service)?.get(), [])
    }

    func testTheCustomAdbPathIsNeverPassedToTheLocator() {
        let locator = StubLocator(result: "/x/fastboot")
        let (service, _) = makeService(.success(output()), locator: locator)
        _ = list(service)
        _ = reboot(service)
        XCTAssertEqual(locator.receivedCustomPaths.count, 2)
        XCTAssertTrue(locator.receivedCustomPaths.allSatisfy { $0 == nil })
    }

    func testFastbootNotFound() {
        let (service, runner) = makeService(.success(output()), located: nil)
        guard case .failure(let error)? = list(service) else { return XCTFail("expected a failure") }
        XCTAssertEqual(error, .notFound(customPath: nil))
        XCTAssertEqual(reboot(service), .notFound(customPath: nil))
        XCTAssertTrue(runner.calls.isEmpty)
    }

    func testRebootRunsFastbootRebootOnTheSerial() {
        let (service, runner) = makeService(.success(output(stderr: "Rebooting...\n")))
        XCTAssertNil(reboot(service, serial: "ZY22"))
        XCTAssertEqual(runner.calls.first?.arguments, ["-s", "ZY22", "reboot"])
        XCTAssertEqual(runner.calls.first?.timeout, 10)
    }

    func testRebootRefusesAnEmptySerial() {
        let (service, runner) = makeService(.success(output()))
        XCTAssertEqual(reboot(service, serial: "  "), .invalidAddress)
        XCTAssertTrue(runner.calls.isEmpty)
    }

    func testRebootFailureUsesTheStderrMessage() {
        let (service, _) = makeService(.success(output(stderr: "error: device not found\n", exit: 1)))
        XCTAssertEqual(reboot(service), .commandFailed("error: device not found"))
    }

    func testRebootTimeout() {
        let (service, _) = makeService(.failure(.timedOut))
        XCTAssertEqual(reboot(service), .timedOut)
    }
}

final class FastbootLocatorTests: XCTestCase {

    private func makeFake(named name: String) throws -> (root: URL, path: String) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let file = root.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try "#!/bin/sh\nexit 0\n".write(to: file, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.path)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return (root, file.path)
    }

    func testFindsFastbootOnPATHAndNotAdb() throws {
        let adb = try makeFake(named: "adb")
        let fastboot = try makeFake(named: "fastboot")
        let environment = ["PATH": "\(adb.root.path):\(fastboot.root.path)"]
        let locator = ADBLocator(environment: environment, homeDirectory: "/nonexistent", wellKnownPaths: [],
                                 executableName: "fastboot")
        XCTAssertEqual(locator.locate(customPath: nil), fastboot.path)
    }

    func testAdbIsNotFoundByAFastbootLocator() throws {
        let adb = try makeFake(named: "adb")
        let locator = ADBLocator(environment: ["PATH": adb.root.path], homeDirectory: "/nonexistent",
                                 wellKnownPaths: [], executableName: "fastboot")
        XCTAssertNil(locator.locate(customPath: nil))
    }

    func testWellKnownPathsFollowTheExecutableName() {
        XCTAssertEqual(ADBLocator.wellKnownPaths(for: "fastboot"),
                       ["/opt/homebrew/bin/fastboot", "/usr/local/bin/fastboot", "/usr/bin/fastboot"])
    }
}
