//
//  ADBServiceSettingsTests.swift
//  ADBMonitorTests
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import XCTest
@testable import ADBMonitor

/// Keluaran `am start` di sini meniru yang teramati pada Android 12 (Pixel 3a, adb 35.0.1).
final class ADBServiceSettingsTests: XCTestCase {

    private func makeService(_ result: Result<ProcessOutput, ProcessError>,
                             located: String? = "/x/adb") -> (ADBService, SequencedProcessRunner) {
        let runner = SequencedProcessRunner([result])
        let service = ADBService(pathProvider: StubPathProvider(adbPath: nil),
                                 locator: StubLocator(result: located),
                                 parser: DeviceListParser(),
                                 runner: runner)
        return (service, runner)
    }

    private func errorOf(_ service: ADBService, serial: String = "SER") -> ADBError? {
        var result: Result<Void, ADBError>?
        service.openDeveloperOptions(on: serial) { result = $0 }
        guard let result = result else { return .commandFailed("completion tidak dipanggil") }
        if case .failure(let error) = result { return error }
        return nil
    }

    func testRunsTheDevelopmentSettingsIntentOnTheSelectedDevice() {
        let started = "Starting: Intent { act=android.settings.APPLICATION_DEVELOPMENT_SETTINGS }"
        let (service, runner) = makeService(.success(output(started)))
        XCTAssertNil(errorOf(service, serial: "94GAY0NRYY"))
        XCTAssertEqual(runner.calls,
                       [["-s", "94GAY0NRYY", "shell", "am", "start", "-a",
                         "android.settings.APPLICATION_DEVELOPMENT_SETTINGS"]])
    }

    func testSuccessWhenOnlyTheStartingLineIsPrinted() {
        let (service, _) = makeService(.success(output("Starting: Intent { act=x }\n")))
        XCTAssertNil(errorOf(service))
    }

    /// `am start` exit 0 walau gagal; kegagalannya hanya berupa baris "Error: …" (diamati di stderr).
    func testAnErrorLineOnStderrIsAFailureEvenWithExitZero() {
        let message = "Error: Activity not started, unable to resolve Intent { act=android.settings.X flg=0x10000000 }"
        let (service, _) = makeService(.success(output("Starting: Intent { act=x }", stderr: message)))
        XCTAssertEqual(errorOf(service), .commandFailed(message))
    }

    func testAnErrorLineOnStdoutIsAlsoAFailure() {
        let (service, _) = makeService(.success(output("Error type 3\nError: Activity class does not exist.")))
        XCTAssertEqual(errorOf(service), .commandFailed("Error type 3"))
    }

    func testNonZeroExitUsesTheStderrMessage() {
        let (service, _) = makeService(.success(output(stderr: "error: device 'SER' not found\n", exit: 1)))
        XCTAssertEqual(errorOf(service), .commandFailed("error: device 'SER' not found"))
    }

    func testTimeoutAndMissingAdbAreReported() {
        XCTAssertEqual(errorOf(makeService(.failure(.timedOut)).0), .timedOut)
        let (service, runner) = makeService(.success(output()), located: nil)
        XCTAssertEqual(errorOf(service), .notFound(customPath: nil))
        XCTAssertTrue(runner.calls.isEmpty)
    }
}
