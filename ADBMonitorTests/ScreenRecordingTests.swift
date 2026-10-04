//
//  ScreenRecordingTests.swift
//  ADBMonitorTests
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import XCTest
@testable import ADBMonitor

@MainActor
final class ScrcpyRecorderTests: XCTestCase {

    private var launcher: FakeProcessLauncher!
    private var scheduler: FakeScheduler!
    private var results: [Result<Void, ADBError>] = []
    private let destination = URL(fileURLWithPath: "/Users/x/Desktop/ADB Recording P 2026-10-04 at 18.30.12.mp4")

    override func setUp() {
        super.setUp()
        launcher = FakeProcessLauncher()
        scheduler = FakeScheduler()
        results = []
    }

    private func makeRecorder(scrcpy: String? = "/opt/scrcpy", adb: String? = "/opt/adb",
                              profile: ScreenRecordingProfile = ScreenRecordingProfile()) -> ScrcpyRecorder {
        ScrcpyRecorder(scrcpyLocator: StubLocator(result: scrcpy), adbLocator: StubLocator(result: adb),
                       pathProvider: StubPathProvider(adbPath: nil), profile: profile, launcher: launcher,
                       scheduler: scheduler, stopGrace: 5)
    }

    private func start(_ recorder: ScrcpyRecorder, serial: String = "SER") {
        recorder.start(serial: serial, to: destination) { [unowned self] in results.append($0) }
    }

    private func error(at index: Int) -> ADBError? {
        guard results.indices.contains(index), case .failure(let error) = results[index] else { return nil }
        return error
    }

    // MARK: Profile

    func testTheDefaultProfileIsSmallAndPlaysEverywhere() {
        let arguments = ScreenRecordingProfile().arguments(serial: "192.168.1.3:5555", destination: destination)
        XCTAssertEqual(arguments, [
            "-s", "192.168.1.3:5555",
            "--record=/Users/x/Desktop/ADB Recording P 2026-10-04 at 18.30.12.mp4", "--record-format=mp4",
            "--max-size=854", "--video-bit-rate=1M", "--max-fps=24",
            "--time-limit=300",
            "--no-audio", "--no-playback",
        ])
    }

    func testTheRecordingIsLimitedToFiveMinutes() {
        XCTAssertEqual(ScreenRecordingProfile().timeLimit, 300)
    }

    func testTheProfileCanBeChanged() {
        let profile = ScreenRecordingProfile(maxSize: 640, bitRate: "2M", framesPerSecond: 30, timeLimit: 60)
        let arguments = profile.arguments(serial: "S", destination: destination)
        XCTAssertTrue(arguments.contains("--max-size=640"))
        XCTAssertTrue(arguments.contains("--video-bit-rate=2M"))
        XCTAssertTrue(arguments.contains("--max-fps=30"))
        XCTAssertTrue(arguments.contains("--time-limit=60"))
    }

    // MARK: Start

    func testStartsScrcpyWithTheProfileAndTheAdbPath() {
        let recorder = makeRecorder()
        start(recorder)
        XCTAssertEqual(launcher.launches.count, 1)
        XCTAssertEqual(launcher.launches[0].executable, "/opt/scrcpy")
        XCTAssertEqual(launcher.launches[0].arguments,
                       ScreenRecordingProfile().arguments(serial: "SER", destination: destination))
        XCTAssertEqual(launcher.launches[0].environment, ["ADB": "/opt/adb"])
        XCTAssertTrue(recorder.isRecording(serial: "SER"))
        XCTAssertTrue(results.isEmpty, "the answer comes when the recording ends")
    }

    func testScrcpyNotInstalled() {
        let recorder = makeRecorder(scrcpy: nil)
        start(recorder)
        XCTAssertEqual(error(at: 0), .toolNotFound("scrcpy"))
        XCTAssertFalse(recorder.isRecording(serial: "SER"))
    }

    func testAdbNotFound() {
        start(makeRecorder(adb: nil))
        XCTAssertEqual(error(at: 0), .notFound(customPath: nil))
        XCTAssertTrue(launcher.launches.isEmpty)
    }

    func testEmptySerialIsRefused() {
        start(makeRecorder(), serial: " ")
        XCTAssertNotNil(error(at: 0))
        XCTAssertTrue(launcher.launches.isEmpty)
    }

    func testLaunchFailures() {
        launcher.error = ProcessError.executableNotFound("/opt/scrcpy")
        start(makeRecorder())
        XCTAssertEqual(error(at: 0), .toolNotFound("scrcpy"))

        launcher.error = ProcessError.launchFailed("boom")
        start(makeRecorder())
        XCTAssertEqual(error(at: 1), .launchFailed("boom"))
    }

    func testASecondRequestForTheSameDeviceIsIgnored() {
        let recorder = makeRecorder()
        start(recorder)
        start(recorder)
        XCTAssertEqual(launcher.launches.count, 1)
        XCTAssertTrue(results.isEmpty, "no answer for the ignored request")
    }

    func testTwoDevicesCanBeRecordedAtTheSameTime() {
        let recorder = makeRecorder()
        start(recorder, serial: "A")
        start(recorder, serial: "B")
        XCTAssertEqual(launcher.launches.count, 2)
        XCTAssertTrue(recorder.isRecording(serial: "A") && recorder.isRecording(serial: "B"))
    }

    // MARK: End of a recording

    func testReachingTheTimeLimitIsASuccess() {
        let recorder = makeRecorder()
        start(recorder)
        launcher.launches[0].onExit(0, "")
        XCTAssertEqual(results.count, 1)
        XCTAssertNil(error(at: 0))
        XCTAssertFalse(recorder.isRecording(serial: "SER"))
    }

    func testAFailureReportsTheErrorLines() {
        let recorder = makeRecorder()   // kept alive: the exit handler only holds the recorder weakly
        start(recorder)
        launcher.launches[0].onExit(1, "ERROR: Device disconnected\n")
        XCTAssertEqual(error(at: 0), .commandFailed("ERROR: Device disconnected"))
    }

    func testTheDeviceCanBeRecordedAgainAfterTheRecordingEnded() {
        let recorder = makeRecorder()
        start(recorder)
        launcher.launches[0].onExit(0, "")
        start(recorder)
        XCTAssertEqual(launcher.launches.count, 2)
    }

    // MARK: Stop

    func testStopInterruptsTheProcessAndEndsAsASuccess() {
        let recorder = makeRecorder()
        start(recorder)
        recorder.stop(serial: "SER")
        XCTAssertEqual(launcher.launches[0].process.interrupts, 1)
        XCTAssertEqual(launcher.launches[0].process.terminations, 0)
        XCTAssertTrue(results.isEmpty, "the recording ends when the process exits, not when it is asked to")

        launcher.launches[0].onExit(0, "")
        XCTAssertEqual(results.count, 1)
        XCTAssertNil(error(at: 0))
    }

    func testAnExitCodeAfterAStopRequestStillCountsAsASuccess() {
        let recorder = makeRecorder()
        start(recorder)
        recorder.stop(serial: "SER")
        launcher.launches[0].onExit(2, "")
        XCTAssertNil(error(at: 0), "the user asked for it")
    }

    func testStopTerminatesAProcessThatDoesNotExit() {
        let recorder = makeRecorder()
        start(recorder)
        recorder.stop(serial: "SER")
        XCTAssertEqual(scheduler.scheduled.first?.interval, 5)
        scheduler.scheduled[0].action()
        XCTAssertEqual(launcher.launches[0].process.terminations, 1)
    }

    func testTheForcedStopIsCancelledWhenTheProcessExitsInTime() {
        let recorder = makeRecorder()
        start(recorder)
        recorder.stop(serial: "SER")
        launcher.launches[0].onExit(0, "")
        XCTAssertTrue(scheduler.scheduled[0].task.isCancelled)
    }

    func testStoppingTwiceInterruptsOnlyOnce() {
        let recorder = makeRecorder()
        start(recorder)
        recorder.stop(serial: "SER")
        recorder.stop(serial: "SER")
        XCTAssertEqual(launcher.launches[0].process.interrupts, 1)
        XCTAssertEqual(scheduler.scheduled.count, 1)
    }

    func testStoppingADeviceThatIsNotRecordingDoesNothing() {
        let recorder = makeRecorder()
        recorder.stop(serial: "NONE")
        XCTAssertTrue(launcher.launches.isEmpty)
        XCTAssertTrue(scheduler.scheduled.isEmpty)
    }
}

@MainActor
final class ScreenCoordinatorRecordingTests: XCTestCase {

    private var recorder: FakeRecorder!
    private var files: FakeFileRevealer!
    private var alerts: FakeAlerts!
    private var coordinator: ScreenCoordinator!
    private var changes: [Set<String>] = []

    private let directory = URL(fileURLWithPath: "/Users/x/Desktop", isDirectory: true)
    /// 2026-10-04 11:30:12 UTC
    private let moment = Date(timeIntervalSince1970: 1_791_113_412)

    override func setUp() {
        super.setUp()
        recorder = FakeRecorder()
        files = FakeFileRevealer()
        alerts = FakeAlerts()
        changes = []
        let localizer = Localizer(provider: StubLanguage(languagePreference: .explicit(.english)),
                                  notificationCenter: NotificationCenter())
        coordinator = ScreenCoordinator(screenshots: FakeScreenshotService(), recorder: recorder,
                                        mirror: FakeMirror(), files: files, alerts: alerts, localizer: localizer,
                                        directory: directory, now: { [unowned self] in moment },
                                        timeZone: TimeZone(identifier: "UTC")!)
        coordinator.onRecordingChange = { [unowned self] in changes.append($0) }
    }

    func testTheFirstRequestStartsARecordingWithAnMp4NameOnTheDesktop() {
        coordinator.statusMenu(didRequestToggleRecordingOf: Sample.device("SER1", model: "Pixel_3a"))
        XCTAssertEqual(recorder.started.count, 1)
        XCTAssertEqual(recorder.started[0].serial, "SER1")
        XCTAssertEqual(recorder.started[0].destination,
                       directory.appendingPathComponent("ADB Recording Pixel_3a 2026-10-04 at 11.30.12.mp4"))
        XCTAssertTrue(recorder.stopped.isEmpty)
    }

    func testTheMenuIsToldThatTheDeviceIsRecording() {
        coordinator.statusMenu(didRequestToggleRecordingOf: Sample.device("SER1"))
        XCTAssertEqual(changes, [["SER1"]])
    }

    func testTheNextRequestWhileRecordingStopsIt() {
        let device = Sample.device("SER1")
        coordinator.statusMenu(didRequestToggleRecordingOf: device)
        coordinator.statusMenu(didRequestToggleRecordingOf: device)
        XCTAssertEqual(recorder.started.count, 1, "no second recording")
        XCTAssertEqual(recorder.stopped, ["SER1"])
    }

    func testWhenTheRecordingEndsTheFileIsShownAndTheMenuIsUpdated() {
        coordinator.statusMenu(didRequestToggleRecordingOf: Sample.device("SER1"))
        recorder.finish(serial: "SER1", .success(()))
        XCTAssertEqual(files.revealed, [recorder.started[0].destination])
        XCTAssertEqual(changes, [["SER1"], []])
        XCTAssertTrue(alerts.errors.isEmpty)
    }

    func testAFailedRecordingShowsAnErrorAndRevealsNothing() {
        coordinator.statusMenu(didRequestToggleRecordingOf: Sample.device("S", model: "Pixel 3a"))
        recorder.finish(serial: "S", .failure(.commandFailed("ERROR: Device disconnected")))
        XCTAssertTrue(files.revealed.isEmpty)
        XCTAssertEqual(alerts.errors.first?.title, "Could not record the screen of Pixel 3a")
        XCTAssertEqual(alerts.errors.first?.message, "ERROR: Device disconnected")
        XCTAssertEqual(changes.last, [])
    }

    func testARecordingThatCannotStartShowsTheErrorAndLeavesTheMenuAlone() {
        recorder.startError = .toolNotFound("scrcpy")
        coordinator.statusMenu(didRequestToggleRecordingOf: Sample.device("S", model: "Pixel 3a"))
        XCTAssertEqual(alerts.errors.first?.message,
                       "scrcpy was not found. Install it with Homebrew: brew install scrcpy")
        XCTAssertEqual(changes.last, [], "not left in the recording state")
    }

    func testTwoDevicesAreTrackedSeparately() {
        coordinator.statusMenu(didRequestToggleRecordingOf: Sample.device("A"))
        coordinator.statusMenu(didRequestToggleRecordingOf: Sample.device("B"))
        XCTAssertEqual(changes.last, ["A", "B"])
        recorder.finish(serial: "A", .success(()))
        XCTAssertEqual(changes.last, ["B"])
    }
}
