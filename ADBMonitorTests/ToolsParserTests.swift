//
//  ToolsParserTests.swift
//  ADBMonitorTests
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import XCTest
@testable import ADBMonitor

final class DeviceDetailsParserTests: XCTestCase {

    private let parser = DeviceDetailsParser()

    /// Output of `getprop ro.build.version.release; dumpsys battery` captured from a Samsung SM-A107F (Android 10).
    /// Samsung adds many vendor lines to `dumpsys battery`; only `level:` must be taken.
    private let samsungOutput = """
    10
    Current Battery Service state:
      AC powered: false
      USB powered: true
      Wireless powered: false
      Max charging current: 500000
      Charge counter: 2946000
      status: 5
      health: 2
      present: true
      level: 100
      scale: 100
      voltage: 4410
      temperature: 349
      technology: Li-ion
      LED Low Battery: true
      current now: 184500
    USE_FAKE_BATTERY: false
    LLB CURRENT: YEAR2026M10D4
    BatteryInfoBackUp
      mSavedBatteryAsoc: -1
    """

    func testParsesVersionAndBatteryFromARealSamsungDump() {
        XCTAssertEqual(parser.parse(samsungOutput), DeviceDetails(androidVersion: "10", batteryLevel: 100))
    }

    func testBatteryLevelOtherThan100() {
        XCTAssertEqual(parser.parse("12\nCurrent Battery Service state:\n  level: 37\n  scale: 100\n").batteryLevel, 37)
    }

    func testOnlyTheExactLevelLineCounts() {
        let output = "12\n  mSavedBatteryLevel: 55\n  level: 41\n  Charge level: 90\n  level:\n"
        XCTAssertEqual(parser.parse(output).batteryLevel, 41)
    }

    func testOutOfRangeBatteryIsIgnored() {
        XCTAssertNil(parser.parse("12\n  level: 150\n").batteryLevel)
        XCTAssertNil(parser.parse("12\n  level: -1\n").batteryLevel)
    }

    func testDottedAndLetterVersions() {
        XCTAssertEqual(parser.parse("13.1\n").androidVersion, "13.1")
        XCTAssertEqual(parser.parse("S\n").androidVersion, "S")
    }

    func testVersionWithoutBattery() {
        XCTAssertEqual(parser.parse("12\n"), DeviceDetails(androidVersion: "12", batteryLevel: nil))
    }

    func testAnErrorInTheFirstLineIsNotTakenAsAVersion() {
        XCTAssertNil(parser.parse("error: closed\n  level: 50\n").androidVersion)
        XCTAssertEqual(parser.parse("error: closed\n  level: 50\n").batteryLevel, 50)
    }

    func testEmptyAndGarbageOutput() {
        XCTAssertTrue(parser.parse("").isEmpty)
        XCTAssertTrue(parser.parse("\n\n   \n").isEmpty)
        XCTAssertTrue(parser.parse("Can't find service: battery\n").isEmpty)
    }
}

final class FastbootDeviceParserTests: XCTestCase {

    private let parser = FastbootDeviceParser()

    func testParsesTabSeparatedDevices() {
        let devices = parser.parse("ZY22XXXXXX\tfastboot\nZY22YYYYYY\tfastbootd\n")
        XCTAssertEqual(devices, [FastbootDevice(serial: "ZY22XXXXXX", mode: "fastboot"),
                                 FastbootDevice(serial: "ZY22YYYYYY", mode: "fastbootd")])
    }

    func testParsesSpaceSeparatedDevices() {
        XCTAssertEqual(parser.parse("ABC123   fastboot\n"), [FastbootDevice(serial: "ABC123", mode: "fastboot")])
    }

    func testEmptyOutputMeansNoDevices() {
        XCTAssertTrue(parser.parse("").isEmpty)
        XCTAssertTrue(parser.parse("\n\n").isEmpty)
    }

    func testWaitingMessagesAndLinesWithoutAModeAreIgnored() {
        XCTAssertTrue(parser.parse("< waiting for any device >\n").isEmpty)
        XCTAssertTrue(parser.parse("ONLYSERIAL\n").isEmpty)
    }

    func testDuplicatesAreCollapsedAndResultsSorted() {
        let devices = parser.parse("B2\tfastboot\nA10\tfastboot\nB2\tfastboot\nA9\tfastboot\n")
        XCTAssertEqual(devices.map(\.serial), ["A9", "A10", "B2"])
    }
}
