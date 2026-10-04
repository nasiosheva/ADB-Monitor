//
//  ADBServiceTests.swift
//  ADBMonitorTests
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import XCTest
@testable import ADBMonitor

final class ADBServiceTests: XCTestCase {

    private let sample = """
    List of devices attached
    AAA   device usb:1-1 model:Pixel_3a transport_id:1
    BBB   offline transport_id:2
    """

    private func makeService(runner: FakeProcessRunner,
                             located: String? = "/x/adb",
                             custom: String? = nil,
                             locator: StubLocator? = nil) -> ADBService {
        ADBService(pathProvider: StubPathProvider(adbPath: custom),
                   locator: locator ?? StubLocator(result: located),
                   parser: DeviceListParser(),
                   runner: runner)
    }

    private func list(_ service: ADBService) -> Result<[ADBDevice], ADBError> {
        var result: Result<[ADBDevice], ADBError>?
        service.listDevices { result = $0 }
        return result ?? .failure(.commandFailed("completion tidak dipanggil"))
    }

    /// `Result<Void, _>` tidak bisa `Equatable`, jadi dikembalikan sebagai error-nya saja (`nil` = sukses).
    private func power(_ service: ADBService, _ action: PowerAction) -> ADBError? {
        var result: Result<Void, ADBError>?
        service.perform(action, on: "SER", completion: { result = $0 })
        guard let result = result else { return .commandFailed("completion tidak dipanggil") }
        if case .failure(let error) = result { return error }
        return nil
    }

    // MARK: listDevices

    func testListParsesStdoutAndUsesCorrectArguments() throws {
        let runner = FakeProcessRunner(.success(output(sample)))
        let devices = try list(makeService(runner: runner)).get()
        XCTAssertEqual(devices.map(\.serial), ["AAA", "BBB"])
        XCTAssertEqual(runner.calls.first?.executable, "/x/adb")
        XCTAssertEqual(runner.calls.first?.arguments, ["devices", "-l"])
        XCTAssertEqual(runner.calls.first?.timeout, 10)
    }

    func testListPassesCustomPathToLocator() {
        let locator = StubLocator(result: "/custom/adb")
        let runner = FakeProcessRunner(.success(output(sample)))
        _ = list(makeService(runner: runner, custom: "/custom/adb", locator: locator))
        XCTAssertEqual(locator.receivedCustomPaths.count, 1)
        XCTAssertEqual(locator.receivedCustomPaths.first ?? nil, "/custom/adb")
    }

    func testListWhenADBNotLocatedReturnsNotFoundWithCustomPath() {
        let runner = FakeProcessRunner(.success(output(sample)))
        let result = list(makeService(runner: runner, located: nil, custom: "/bad"))
        XCTAssertEqual(result, .failure(.notFound(customPath: "/bad")))
        XCTAssertTrue(runner.calls.isEmpty, "adb tidak boleh dijalankan bila lokasinya tidak ketemu")
    }

    func testListMapsRunnerErrors() {
        XCTAssertEqual(list(makeService(runner: FakeProcessRunner(.failure(.timedOut)))), .failure(.timedOut))
        XCTAssertEqual(list(makeService(runner: FakeProcessRunner(.failure(.launchFailed("x"))))),
                       .failure(.launchFailed("x")))
        let missing = FakeProcessRunner(.failure(.executableNotFound("/x/adb")))
        XCTAssertEqual(list(makeService(runner: missing, custom: "/c")), .failure(.notFound(customPath: "/c")))
    }

    func testListUsesFirstNonEmptyStderrLineOnFailure() {
        let runner = FakeProcessRunner(.success(output(stderr: "\n  adb server version mismatch  \nmore", exit: 1)))
        XCTAssertEqual(list(makeService(runner: runner)), .failure(.commandFailed("adb server version mismatch")))
    }

    func testListFallsBackToExitCodeWhenStderrIsEmpty() {
        let runner = FakeProcessRunner(.success(output(exit: 7)))
        XCTAssertEqual(list(makeService(runner: runner)), .failure(.commandFailed("adb exited with code 7.")))
    }

    // MARK: perform

    func testRestartArguments() {
        let runner = FakeProcessRunner(.success(output()))
        XCTAssertNil(power(makeService(runner: runner), .restart))
        XCTAssertEqual(runner.calls.first?.arguments, ["-s", "SER", "reboot"])
        XCTAssertEqual(runner.calls.first?.timeout, 15)
    }

    func testShutdownArguments() {
        let runner = FakeProcessRunner(.success(output()))
        XCTAssertNil(power(makeService(runner: runner), .shutdown))
        XCTAssertEqual(runner.calls.first?.arguments, ["-s", "SER", "shell", "reboot", "-p"])
    }

    func testPowerFailureCarriesAdbMessage() {
        let runner = FakeProcessRunner(.success(output(stderr: "error: device 'SER' not found\n", exit: 1)))
        XCTAssertEqual(power(makeService(runner: runner), .restart),
                       .commandFailed("error: device 'SER' not found"))
    }

    func testPowerWhenADBNotLocated() {
        let error = power(makeService(runner: FakeProcessRunner(.success(output())), located: nil), .restart)
        XCTAssertEqual(error, .notFound(customPath: nil))
    }
}
