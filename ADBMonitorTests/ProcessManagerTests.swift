//
//  ProcessManagerTests.swift
//  ADBMonitorTests
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import XCTest
@testable import ADBMonitor

/// Uses real processes (`/bin/sh`, `/usr/bin/yes`).
final class ProcessManagerTests: XCTestCase {

    private typealias Outcome = (result: Result<ProcessOutput, ProcessError>, seconds: TimeInterval)

    private func run(_ executable: String,
                     _ arguments: [String] = [],
                     timeout: TimeInterval = 10,
                     queue: DispatchQueue = .global(),
                     limit: TimeInterval = 15) -> Outcome? {
        let manager = ProcessManager(completionQueue: queue)
        let done = expectation(description: "selesai")
        var result: Result<ProcessOutput, ProcessError>?
        let start = Date()
        manager.run(executable: executable, arguments: arguments, timeout: timeout) {
            result = $0
            done.fulfill()
        }
        wait(for: [done], timeout: limit)
        return result.map { ($0, Date().timeIntervalSince(start)) }
    }

    func testCapturesStdoutStderrAndExitCode() throws {
        let r = try XCTUnwrap(run("/bin/sh", ["-c", "echo out; echo err >&2; exit 3"]))
        let out = try r.result.get()
        XCTAssertEqual(out.stdout.trimmed, "out")
        XCTAssertEqual(out.stderr.trimmed, "err")
        XCTAssertEqual(out.exitCode, 3)
    }

    func testLargeOutputDoesNotDeadlock() throws {
        let r = try XCTUnwrap(run("/bin/sh", ["-c", "head -c 3000000 /dev/zero | tr '\\0' a"]))
        XCTAssertEqual(try r.result.get().stdout.count, 3_000_000)
    }

    func testTimeoutTerminatesTheProcess() throws {
        let r = try XCTUnwrap(run("/usr/bin/yes", timeout: 1))
        XCTAssertEqual(r.result, .failure(.timedOut))
        XCTAssertLessThan(r.seconds, 6)
    }

    func testMissingExecutable() throws {
        let r = try XCTUnwrap(run("/nope/adb"))
        XCTAssertEqual(r.result, .failure(.executableNotFound("/nope/adb")))
    }

    func testDirectoryIsNotAnExecutable() throws {
        let r = try XCTUnwrap(run("/bin"))
        XCTAssertEqual(r.result, .failure(.executableNotFound("/bin")))
    }

    func testChildHoldingThePipeDoesNotBlockCompletion() throws {
        // The parent exits right away, the child (sleep 5) still holds the pipe end, like the adb daemon.
        let r = try XCTUnwrap(run("/bin/sh", ["-c", "(sleep 5 &) ; echo hi"]))
        XCTAssertEqual(try r.result.get().stdout.trimmed, "hi")
        XCTAssertLessThan(r.seconds, 3.5, "harus selesai di sekitar batas drain 1 detik, bukan menunggu 5 detik")
    }

    func testCompletionIsDeliveredOnTheRequestedQueue() throws {
        let key = DispatchSpecificKey<String>()
        let queue = DispatchQueue(label: "test.completion")
        queue.setSpecific(key: key, value: "mine")
        let manager = ProcessManager(completionQueue: queue)
        let done = expectation(description: "selesai")
        var marker: String?
        manager.run(executable: "/bin/echo", arguments: ["x"], timeout: 5) { _ in
            marker = DispatchQueue.getSpecific(key: key)
            done.fulfill()
        }
        wait(for: [done], timeout: 10)
        XCTAssertEqual(marker, "mine")
    }

    func testEnvironmentPathIncludesHomebrewDirectories() throws {
        let r = try XCTUnwrap(run("/bin/sh", ["-c", "echo $PATH"]))
        let path = try r.result.get().stdout
        XCTAssertTrue(path.contains("/opt/homebrew/bin"))
        XCTAssertTrue(path.contains("/usr/local/bin"))
    }
}
