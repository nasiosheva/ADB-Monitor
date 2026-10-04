//
//  ScreenToolsTests.swift
//  ADBMonitorTests
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import XCTest
@testable import ADBMonitor

final class ScreenshotServiceTests: XCTestCase {

    private let remote = "/data/local/tmp/adbmonitor-screenshot.png"
    private let destination = URL(fileURLWithPath: "/Users/x/Desktop/shot one.png")

    private func makeService(_ results: [Result<ProcessOutput, ProcessError>],
                             located: String? = "/x/adb") -> (ADBService, SequencedProcessRunner) {
        let runner = SequencedProcessRunner(results)
        let service = ADBService(pathProvider: StubPathProvider(adbPath: nil), locator: StubLocator(result: located),
                                 parser: DeviceListParser(), runner: runner)
        return (service, runner)
    }

    private func capture(_ service: ADBService, serial: String = "SER") -> ADBError? {
        var result: Result<Void, ADBError>?
        service.takeScreenshot(of: serial, to: destination) { result = $0 }
        guard let result = result else { return .commandFailed("completion tidak dipanggil") }
        if case .failure(let error) = result { return error }
        return nil
    }

    func testCapturesPullsAndCleansUpInThatOrder() {
        let (service, runner) = makeService([.success(output()), .success(output("1 file pulled")), .success(output())])
        XCTAssertNil(capture(service))
        XCTAssertEqual(runner.calls, [
            ["-s", "SER", "shell", "screencap", "-p", remote],
            ["-s", "SER", "pull", remote, "/Users/x/Desktop/shot one.png"],
            ["-s", "SER", "shell", "rm", "-f", remote],
        ])
    }

    func testAFailedCaptureStopsBeforePulling() {
        let (service, runner) = makeService([.success(output(stderr: "screencap: not allowed\n", exit: 1))])
        XCTAssertEqual(capture(service), .commandFailed("screencap: not allowed"))
        XCTAssertEqual(runner.calls.count, 1)
    }

    func testAFailedPullIsReportedButTheDeviceFileIsStillRemoved() {
        let (service, runner) = makeService([.success(output()),
                                             .success(output(stderr: "adb: error: no space left\n", exit: 1)),
                                             .success(output())])
        XCTAssertEqual(capture(service), .commandFailed("adb: error: no space left"))
        XCTAssertEqual(runner.calls.last, ["-s", "SER", "shell", "rm", "-f", remote])
    }

    func testAFailedCleanupDoesNotFailTheScreenshot() {
        let (service, _) = makeService([.success(output()), .success(output()),
                                        .success(output(stderr: "rm: failed\n", exit: 1))])
        XCTAssertNil(capture(service))
    }

    func testTimeoutOnCapture() {
        let (service, _) = makeService([.failure(.timedOut)])
        XCTAssertEqual(capture(service), .timedOut)
    }

    func testEmptySerialIsRefused() {
        let (service, runner) = makeService([])
        XCTAssertNotNil(capture(service, serial: "  "))
        XCTAssertTrue(runner.calls.isEmpty)
    }

    func testAdbNotFound() {
        let (service, runner) = makeService([], located: nil)
        XCTAssertEqual(capture(service), .notFound(customPath: nil))
        XCTAssertTrue(runner.calls.isEmpty)
    }
}

@MainActor
final class ScrcpyMirrorTests: XCTestCase {

    private var launcher: FakeProcessLauncher!
    private var scheduler: FakeScheduler!
    private var results: [Result<Void, ADBError>] = []

    override func setUp() {
        super.setUp()
        launcher = FakeProcessLauncher()
        scheduler = FakeScheduler()
        results = []
    }

    private func makeMirror(scrcpy: String? = "/opt/scrcpy", adb: String? = "/opt/adb",
                            customPath: String? = nil) -> ScrcpyMirror {
        ScrcpyMirror(scrcpyLocator: StubLocator(result: scrcpy), adbLocator: StubLocator(result: adb),
                     pathProvider: StubPathProvider(adbPath: customPath), launcher: launcher,
                     scheduler: scheduler, startupGrace: 3)
    }

    private func start(_ mirror: ScrcpyMirror, serial: String = "SER") {
        mirror.mirror(serial: serial) { [unowned self] in results.append($0) }
    }

    private func error(at index: Int) -> ADBError? {
        guard results.indices.contains(index), case .failure(let error) = results[index] else { return nil }
        return error
    }

    func testStartsScrcpyOnTheSerialAndPassesTheAdbPathInTheEnvironment() {
        start(makeMirror(), serial: "192.168.1.3:5555")
        XCTAssertEqual(launcher.launches.count, 1)
        XCTAssertEqual(launcher.launches[0].executable, "/opt/scrcpy")
        XCTAssertEqual(launcher.launches[0].arguments, ["-s", "192.168.1.3:5555"])
        XCTAssertEqual(launcher.launches[0].environment, ["ADB": "/opt/adb"])
    }

    func testTheCustomAdbPathIsUsedToFindAdb() {
        let adbLocator = StubLocator(result: "/custom/adb")
        let mirror = ScrcpyMirror(scrcpyLocator: StubLocator(result: "/opt/scrcpy"), adbLocator: adbLocator,
                                  pathProvider: StubPathProvider(adbPath: "/custom/adb"), launcher: launcher,
                                  scheduler: scheduler)
        start(mirror)
        XCTAssertEqual(adbLocator.receivedCustomPaths.first ?? nil, "/custom/adb")
        XCTAssertEqual(launcher.launches.first?.environment["ADB"], "/custom/adb")
    }

    func testScrcpyNotInstalled() {
        start(makeMirror(scrcpy: nil))
        XCTAssertEqual(error(at: 0), .toolNotFound("scrcpy"))
        XCTAssertTrue(launcher.launches.isEmpty)
    }

    func testAdbNotFound() {
        start(makeMirror(adb: nil, customPath: "/bad/adb"))
        XCTAssertEqual(error(at: 0), .notFound(customPath: "/bad/adb"))
        XCTAssertTrue(launcher.launches.isEmpty)
    }

    func testEmptySerialIsRefused() {
        start(makeMirror(), serial: " ")
        XCTAssertNotNil(error(at: 0))
        XCTAssertTrue(launcher.launches.isEmpty)
    }

    func testStaysSuccessfulOnceItHasBeenUpForTheStartupTime() {
        start(makeMirror())
        XCTAssertTrue(results.isEmpty, "no answer before the startup time has passed")
        XCTAssertEqual(scheduler.scheduled.first?.interval, 3)
        scheduler.scheduled[0].action()
        XCTAssertEqual(results.count, 1)
        XCTAssertNil(error(at: 0))
    }

    func testAnEarlyFailureIsReportedWithTheErrorLinesAndWithoutTheInfoLines() {
        start(makeMirror())
        launcher.launches[0].onExit(1, "INFO: scrcpy 4.1\nERROR: Could not find any ADB device\nERROR: other\n")
        XCTAssertEqual(error(at: 0), .commandFailed("ERROR: Could not find any ADB device\nERROR: other"))
        XCTAssertTrue(scheduler.scheduled[0].task.isCancelled, "the startup timer must not fire later")
    }

    /// Captured from scrcpy 4.1 when asked for a serial that does not exist.
    func testTheRealScrcpyErrorKeepsTheListOfDevicesItFound() {
        let output = """
            ERROR: Could not find ADB device NO_SUCH_SERIAL_XYZ:
            ERROR:           (usb)  R9CN4057BXJ                     device  SM_A107F
            ERROR: Server connection failed
            """
        XCTAssertEqual(ScrcpyMirror.failure(1, output), .commandFailed(output))
    }

    func testAtMostFiveErrorLinesAreKept() {
        let output = (1...9).map { "ERROR: line \($0)" }.joined(separator: "\n")
        XCTAssertEqual(ScrcpyMirror.failure(1, output),
                       .commandFailed((1...5).map { "ERROR: line \($0)" }.joined(separator: "\n")))
    }

    func testAnEarlyFailureWithoutAnErrorLineUsesTheLastLineOrTheExitCode() {
        XCTAssertEqual(ScrcpyMirror.failure(1, "something\nlast line\n"), .commandFailed("last line"))
        XCTAssertEqual(ScrcpyMirror.failure(3, ""), .commandFailed("scrcpy exited with code 3."))
    }

    func testAnEarlyCleanExitCountsAsSuccess() {
        start(makeMirror())
        launcher.launches[0].onExit(0, "")
        XCTAssertEqual(results.count, 1)
        XCTAssertNil(error(at: 0))
    }

    func testExitAfterTheStartupTimeReportsNothingMore() {
        start(makeMirror())
        scheduler.scheduled[0].action()
        launcher.launches[0].onExit(1, "ERROR: lost the device")
        XCTAssertEqual(results.count, 1, "the user closed or lost the window long after it opened")
    }

    func testTheSameDeviceIsNotMirroredTwiceAtOnce() {
        let mirror = makeMirror()
        start(mirror)
        scheduler.scheduled[0].action()
        start(mirror)
        XCTAssertEqual(launcher.launches.count, 1)
        XCTAssertEqual(results.count, 2)
        XCTAssertNil(error(at: 1))
    }

    func testAnotherDeviceCanBeMirroredAtTheSameTime() {
        let mirror = makeMirror()
        start(mirror, serial: "A")
        start(mirror, serial: "B")
        XCTAssertEqual(launcher.launches.map(\.arguments), [["-s", "A"], ["-s", "B"]])
    }

    func testTheDeviceCanBeMirroredAgainAfterTheWindowWasClosed() {
        let mirror = makeMirror()
        start(mirror)
        scheduler.scheduled[0].action()
        launcher.launches[0].onExit(0, "")
        start(mirror)
        XCTAssertEqual(launcher.launches.count, 2)
    }

    func testAMissingExecutableAtLaunchMeansNotInstalled() {
        launcher.error = ProcessError.executableNotFound("/opt/scrcpy")
        start(makeMirror())
        XCTAssertEqual(error(at: 0), .toolNotFound("scrcpy"))
    }

    func testOtherLaunchErrors() {
        launcher.error = ProcessError.launchFailed("boom")
        start(makeMirror())
        XCTAssertEqual(error(at: 0), .launchFailed("boom"))
        XCTAssertTrue(scheduler.scheduled.isEmpty, "no startup timer for a process that did not start")
    }
}

@MainActor
final class ProcessLauncherTests: XCTestCase {

    private func launch(_ script: String, environment: [String: String] = [:]) throws -> (Int32, String) {
        let launcher = ProcessLauncher()
        let done = expectation(description: "exit")
        var outcome: (Int32, String)?
        try launcher.launch(executable: "/bin/sh", arguments: ["-c", script], environment: environment) { code, text in
            outcome = (code, text)
            done.fulfill()
        }
        wait(for: [done], timeout: 15)
        return try XCTUnwrap(outcome)
    }

    func testReportsTheExitCodeAndTheErrorOutput() throws {
        let (code, errors) = try launch("echo problem >&2; exit 4")
        XCTAssertEqual(code, 4)
        XCTAssertEqual(errors.trimmed, "problem")
    }

    func testPassesExtraEnvironmentVariablesAndKeepsTheRest() throws {
        let (code, errors) = try launch("echo \"$ADB_TEST|$HOME\" >&2", environment: ["ADB_TEST": "/x/adb"])
        XCTAssertEqual(code, 0)
        XCTAssertTrue(errors.hasPrefix("/x/adb|"))
        XCTAssertGreaterThan(errors.trimmed.count, "/x/adb|".count, "HOME is inherited")
    }

    func testThePathIncludesTheHomebrewDirectory() throws {
        let (_, errors) = try launch("echo \"$PATH\" >&2")
        XCTAssertTrue(errors.contains("/opt/homebrew/bin"))
    }

    func testALotOfStandardOutputDoesNotBlockTheProcess() throws {
        let (code, _) = try launch("head -c 3000000 /dev/zero | tr '\\0' a")
        XCTAssertEqual(code, 0)
    }

    func testOnlyTheLastPartOfTheErrorOutputIsKept() throws {
        let (code, errors) = try launch("head -c 100000 /dev/zero | tr '\\0' a >&2; echo END >&2")
        XCTAssertEqual(code, 0)
        XCTAssertLessThanOrEqual(errors.utf8.count, 4096)
        XCTAssertTrue(errors.hasSuffix("END\n"))
    }

    /// `scrcpy` finishes its MP4 file when it receives SIGINT, so the launcher must be able to send it.
    func testInterruptSendsSIGINTLikeCtrlC() throws {
        let launcher = ProcessLauncher()
        let started = expectation(description: "started")
        let done = expectation(description: "exit")
        var outcome: (Int32, String)?
        let script = "trap 'echo got-int >&2; exit 7' INT; echo ready; while :; do sleep 0.05; done"
        let process = try launcher.launch(executable: "/bin/sh", arguments: ["-c", script], environment: [:]) {
            code, text in
            outcome = (code, text)
            done.fulfill()
        }
        // Give the shell time to install its trap before the signal is sent.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { started.fulfill() }
        wait(for: [started], timeout: 5)
        process.interrupt()
        wait(for: [done], timeout: 15)
        XCTAssertEqual(outcome?.0, 7)
        XCTAssertEqual(outcome?.1.trimmed, "got-int")
    }

    func testTerminateStopsAProcessThatIgnoresInterrupt() throws {
        let launcher = ProcessLauncher()
        let started = expectation(description: "started")
        let done = expectation(description: "exit")
        var code: Int32?
        let process = try launcher.launch(executable: "/bin/sh",
                                          arguments: ["-c", "trap '' INT; while :; do sleep 0.05; done"],
                                          environment: [:]) { exitCode, _ in
            code = exitCode
            done.fulfill()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { started.fulfill() }
        wait(for: [started], timeout: 5)
        process.interrupt()
        process.terminate()
        wait(for: [done], timeout: 15)
        XCTAssertNotEqual(code, 0, "killed by SIGTERM")
    }

    func testInterruptAfterTheProcessEndedDoesNothing() throws {
        let launcher = ProcessLauncher()
        let done = expectation(description: "exit")
        let process = try launcher.launch(executable: "/bin/sh", arguments: ["-c", "exit 0"],
                                          environment: [:]) { _, _ in
            done.fulfill()
        }
        wait(for: [done], timeout: 15)
        process.interrupt()
        process.terminate()
    }

    func testAMissingExecutableThrows() {
        let launcher = ProcessLauncher()
        XCTAssertThrowsError(try launcher.launch(executable: "/nonexistent/tool", arguments: [], environment: [:],
                                                 onExit: { _, _ in })) { error in
            XCTAssertEqual(error as? ProcessError, .executableNotFound("/nonexistent/tool"))
        }
    }

    func testTheProcessKeepsRunningAfterLaunchReturns() throws {
        let launcher = ProcessLauncher()
        let done = expectation(description: "exit")
        let start = Date()
        try launcher.launch(executable: "/bin/sh", arguments: ["-c", "sleep 1"], environment: [:]) { _, _ in
            done.fulfill()
        }
        XCTAssertLessThan(Date().timeIntervalSince(start), 0.5, "launch must not wait for the process")
        wait(for: [done], timeout: 15)
    }
}

@MainActor
final class ScreenCoordinatorTests: XCTestCase {

    private var screenshots: FakeScreenshotService!
    private var mirror: FakeMirror!
    private var recorder: FakeRecorder!
    private var files: FakeFileRevealer!
    private var alerts: FakeAlerts!
    private var coordinator: ScreenCoordinator!

    private let directory = URL(fileURLWithPath: "/Users/x/Desktop", isDirectory: true)
    /// 2026-10-04 11:30:12 UTC
    private let moment = Date(timeIntervalSince1970: 1_791_113_412)

    override func setUp() {
        super.setUp()
        screenshots = FakeScreenshotService()
        mirror = FakeMirror()
        recorder = FakeRecorder()
        files = FakeFileRevealer()
        alerts = FakeAlerts()
        let localizer = Localizer(provider: StubLanguage(languagePreference: .explicit(.english)),
                                  notificationCenter: NotificationCenter())
        coordinator = ScreenCoordinator(screenshots: screenshots, recorder: recorder, mirror: mirror, files: files,
                                        alerts: alerts, localizer: localizer, directory: directory,
                                        now: { [unowned self] in moment }, timeZone: TimeZone(identifier: "UTC")!)
    }

    func testScreenshotIsSavedOnTheDesktopWithADatedName() {
        coordinator.statusMenu(didRequestScreenshotOf: Sample.device("SER1", model: "Pixel_3a"))
        let expected = directory.appendingPathComponent("ADB Screenshot Pixel_3a 2026-10-04 at 11.30.12.png")
        XCTAssertEqual(screenshots.requests.first?.serial, "SER1")
        XCTAssertEqual(screenshots.requests.first?.destination, expected)
    }

    func testTheFileIsShownInFinderWhenTheScreenshotSucceeds() {
        coordinator.statusMenu(didRequestScreenshotOf: Sample.device())
        XCTAssertTrue(files.revealed.isEmpty, "not before the screenshot is done")
        screenshots.complete(.success(()))
        XCTAssertEqual(files.revealed, [screenshots.requests[0].destination])
        XCTAssertTrue(alerts.errors.isEmpty)
    }

    func testAFailedScreenshotShowsAnErrorAndRevealsNothing() {
        coordinator.statusMenu(didRequestScreenshotOf: Sample.device("S", model: "Pixel 3a"))
        screenshots.complete(.failure(.commandFailed("screencap: not allowed")))
        XCTAssertTrue(files.revealed.isEmpty)
        XCTAssertEqual(alerts.errors.first?.title, "Could not take a screenshot of Pixel 3a")
        XCTAssertEqual(alerts.errors.first?.message, "screencap: not allowed")
    }

    func testASecondClickWhileCapturingIsIgnoredButAnotherDeviceIsNot() {
        coordinator.statusMenu(didRequestScreenshotOf: Sample.device("A"))
        coordinator.statusMenu(didRequestScreenshotOf: Sample.device("A"))
        coordinator.statusMenu(didRequestScreenshotOf: Sample.device("B"))
        XCTAssertEqual(screenshots.requests.map(\.serial), ["A", "B"])
    }

    func testTheDeviceCanBeCapturedAgainAfterTheFirstScreenshotEnded() {
        coordinator.statusMenu(didRequestScreenshotOf: Sample.device("A"))
        screenshots.complete(.failure(.timedOut))
        coordinator.statusMenu(didRequestScreenshotOf: Sample.device("A"))
        XCTAssertEqual(screenshots.requests.count, 2)
    }

    func testFileNamesAreSafeForAnySerial() {
        let wifi = Sample.device("192.168.1.3:5555", model: nil)
        XCTAssertEqual(coordinator.fileName(for: Sample.device("X", model: "A/B:C*D"), at: moment),
                       "ADB Screenshot A-B-C-D 2026-10-04 at 11.30.12.png")
        XCTAssertFalse(coordinator.fileName(for: wifi, at: moment).contains(":"))
    }

    func testFileNamesUseTheConfiguredTimeZone() {
        let jakarta = ScreenCoordinator(screenshots: screenshots, recorder: recorder, mirror: mirror, files: files,
                                        alerts: alerts,
                                        localizer: Localizer(provider: StubLanguage(languagePreference: .system),
                                                             notificationCenter: NotificationCenter()),
                                        directory: directory, timeZone: TimeZone(identifier: "Asia/Jakarta")!)
        XCTAssertTrue(jakarta.fileName(for: Sample.device("X", model: "P"), at: moment).hasSuffix("18.30.12.png"))
    }

    func testMirrorStartsOnTheSerialWithoutAnyAlertOnSuccess() {
        coordinator.statusMenu(didRequestMirror: Sample.device("SER9"))
        XCTAssertEqual(mirror.serials, ["SER9"])
        XCTAssertTrue(alerts.errors.isEmpty)
        XCTAssertTrue(alerts.generalConfirmations.isEmpty, "mirroring changes nothing, so no confirmation")
    }

    func testMirrorFailureShowsTheErrorWithTheDeviceName() {
        mirror.result = .failure(.commandFailed("ERROR: no device"))
        coordinator.statusMenu(didRequestMirror: Sample.device("S", model: "Pixel 3a"))
        XCTAssertEqual(alerts.errors.first?.title, "Could not mirror the screen of Pixel 3a")
        XCTAssertEqual(alerts.errors.first?.message, "ERROR: no device")
    }

    func testAMissingScrcpyExplainsHowToInstallIt() {
        mirror.result = .failure(.toolNotFound("scrcpy"))
        coordinator.statusMenu(didRequestMirror: Sample.device())
        XCTAssertEqual(alerts.errors.first?.message,
                       "scrcpy was not found. Install it with Homebrew: brew install scrcpy")
    }
}
