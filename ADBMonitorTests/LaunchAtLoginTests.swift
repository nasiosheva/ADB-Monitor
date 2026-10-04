//
//  LaunchAtLoginTests.swift
//  ADBMonitorTests
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import XCTest
@testable import ADBMonitor

/// Sengaja tidak memanggil `register()` sungguhan: itu akan menambah login item yang menunjuk ke folder build.
final class LaunchAtLoginTests: XCTestCase {

    func testStatusIsOnMapping() {
        XCTAssertTrue(LaunchAtLoginStatus.enabled.isOn)
        XCTAssertTrue(LaunchAtLoginStatus.requiresApproval.isOn,
                      "menunggu persetujuan tetap berarti pengguna memintanya")
        XCTAssertFalse(LaunchAtLoginStatus.disabled.isOn)
        XCTAssertFalse(LaunchAtLoginStatus.unsupported.isOn)
    }

    func testUnsupportedImplementationReportsAndThrows() {
        let unsupported = UnsupportedLaunchAtLogin()
        XCTAssertEqual(unsupported.status, .unsupported)
        XCTAssertThrowsError(try unsupported.setEnabled(true)) { error in
            XCTAssertEqual(error as? LaunchAtLoginError, .unsupported)
        }
    }

    func testDefaultImplementationMatchesTheOperatingSystem() {
        let status = LaunchAtLogin.makeDefault().status
        if #available(macOS 13.0, *) {
            XCTAssertNotEqual(status, .unsupported)
        } else {
            XCTAssertEqual(status, .unsupported)
        }
    }
}

final class SchedulerTests: XCTestCase {

    func testScheduledActionRunsOnTheMainThread() {
        let ran = expectation(description: "dijalankan")
        _ = RunLoopScheduler().schedule(after: 0.05) {
            XCTAssertTrue(Thread.isMainThread)
            ran.fulfill()
        }
        wait(for: [ran], timeout: 2)
    }

    func testCancelledTaskNeverRuns() {
        let ran = expectation(description: "tidak boleh jalan")
        ran.isInverted = true
        let task = RunLoopScheduler().schedule(after: 0.05) { ran.fulfill() }
        task.cancel()
        wait(for: [ran], timeout: 0.4)
    }
}
