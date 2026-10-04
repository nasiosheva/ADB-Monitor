//
//  ADBModelTests.swift
//  ADBMonitorTests
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import XCTest
@testable import ADBMonitor

final class ADBModelTests: XCTestCase {

    // MARK: ADBDevice

    func testDisplayNameFallbackOrder() {
        XCTAssertEqual(ADBDevice(serial: "S", state: .device, model: "M", product: "P", deviceName: "D",
                                 transportID: nil, usbPath: nil).displayName, "M")
        XCTAssertEqual(ADBDevice(serial: "S", state: .device, model: nil, product: "P", deviceName: "D",
                                 transportID: nil, usbPath: nil).displayName, "D")
        XCTAssertEqual(ADBDevice(serial: "S", state: .device, model: nil, product: "P", deviceName: nil,
                                 transportID: nil, usbPath: nil).displayName, "P")
        XCTAssertEqual(ADBDevice(serial: "S", state: .device, model: nil, product: nil, deviceName: nil,
                                 transportID: nil, usbPath: nil).displayName, "S")
    }

    func testConnectionDerivation() {
        XCTAssertEqual(Sample.device("emulator-5554").connection, .emulator)
        XCTAssertEqual(Sample.device("192.168.0.2:5555").connection, .network)
        XCTAssertEqual(Sample.device("adb-XYZ._adb-tls-connect._tcp").connection, .network)
        XCTAssertEqual(Sample.device("ABC", usbPath: "1-1").connection, .usb)
        XCTAssertEqual(Sample.device("ABC", usbPath: nil).connection, .unknown)
    }

    func testStateParsingFromAdbValue() {
        XCTAssertEqual(ADBDevice.State(adbValue: "device"), .device)
        XCTAssertEqual(ADBDevice.State(adbValue: "unauthorized"), .unauthorized)
        XCTAssertEqual(ADBDevice.State(adbValue: "weird"), .unknown("weird"))
    }

    func testEveryKnownStateHasALabelKeyAndUnknownHasNone() {
        let known: [ADBDevice.State] = [.device, .offline, .unauthorized, .noPermissions, .authorizing,
                                        .connecting, .recovery, .sideload, .bootloader]
        XCTAssertTrue(known.allSatisfy { $0.labelKey != nil })
        XCTAssertNil(ADBDevice.State.unknown("x").labelKey)
    }

    // MARK: ADBStatus

    func testStatusFromSuccessKeepsDevices() {
        let devices = [Sample.device()]
        XCTAssertEqual(ADBStatus(result: .success(devices)), .devices(devices))
    }

    func testStatusFromNotFoundKeepsCustomPath() {
        XCTAssertEqual(ADBStatus(result: .failure(.notFound(customPath: "/x"))), .adbNotFound(customPath: "/x"))
        XCTAssertEqual(ADBStatus(result: .failure(.notFound(customPath: nil))), .adbNotFound(customPath: nil))
    }

    func testStatusFromOtherErrorsKeepsTheError() {
        XCTAssertEqual(ADBStatus(result: .failure(.timedOut)), .failure(.timedOut))
        XCTAssertEqual(ADBStatus(result: .failure(.commandFailed("boom"))), .failure(.commandFailed("boom")))
    }

    // MARK: PowerAction

    func testPowerActionArguments() {
        XCTAssertEqual(PowerAction.restart.adbArguments, ["reboot"])
        XCTAssertEqual(PowerAction.shutdown.adbArguments, ["shell", "reboot", "-p"])
    }

    func testPowerActionAvailabilityMatrix() {
        let states: [ADBDevice.State] = [.device, .recovery, .offline, .unauthorized, .noPermissions,
                                         .authorizing, .connecting, .sideload, .bootloader, .unknown("x")]
        let restartable: Set<ADBDevice.State> = [.device, .recovery]
        let shutdownable: Set<ADBDevice.State> = [.device]
        for state in states {
            XCTAssertEqual(PowerAction.restart.isAvailable(for: state),
                           restartable.contains(state), "restart \(state)")
            XCTAssertEqual(PowerAction.shutdown.isAvailable(for: state),
                           shutdownable.contains(state), "shutdown \(state)")
        }
    }

    func testBootModeActionArguments() {
        XCTAssertEqual(PowerAction.rebootRecovery.adbArguments, ["reboot", "recovery"])
        XCTAssertEqual(PowerAction.rebootBootloader.adbArguments, ["reboot", "bootloader"])
        XCTAssertEqual(PowerAction.rebootDownload.adbArguments, ["reboot", "download"])
    }

    func testOnlyTheBootModeActionsAreBootModes() {
        let bootModes = PowerAction.allCases.filter(\.isBootMode)
        XCTAssertEqual(bootModes, [.rebootRecovery, .rebootBootloader, .rebootDownload])
    }

    func testBootModeAvailabilityMatrix() {
        let states: [ADBDevice.State] = [.device, .recovery, .offline, .unauthorized, .noPermissions,
                                         .authorizing, .connecting, .sideload, .bootloader, .unknown("x")]
        // Download mode is a Samsung feature that is entered from a running system only.
        let reachable: [PowerAction: Set<ADBDevice.State>] = [
            .rebootRecovery: [.device, .recovery],
            .rebootBootloader: [.device, .recovery],
            .rebootDownload: [.device],
        ]
        for (action, allowed) in reachable {
            for state in states {
                XCTAssertEqual(action.isAvailable(for: state), allowed.contains(state), "\(action) \(state)")
            }
        }
    }

    func testEveryPowerActionKeyExistsInEveryLanguage() {
        for language in AppLanguage.allCases {
            let table = Translations.table(for: language)
            for action in PowerAction.allCases {
                for key in [action.menuTitleKey, action.verbKey, action.confirmTitleKey,
                            action.confirmBodyKey, action.failureTitleKey] {
                    XCTAssertNotNil(table[key], "\(language) tidak punya \(key)")
                }
            }
        }
    }
}
