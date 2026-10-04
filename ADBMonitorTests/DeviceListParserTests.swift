//
//  DeviceListParserTests.swift
//  ADBMonitorTests
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import XCTest
@testable import ADBMonitor

final class DeviceListParserTests: XCTestCase {

    private let parser = DeviceListParser()

    private let fullSample = """
    * daemon not running; starting now at tcp:5037
    * daemon started successfully
    List of devices attached
    R58M123ABC             device usb:1-1 product:o1sxxx model:SM_G991B device:o1s transport_id:2
    R9CN4057BXJ            device 2-1 product:a10sxx model:SM_A107F device:a10s transport_id:1
    emulator-5554          offline transport_id:1
    192.168.1.5:5555       device product:x model:Pixel_6_Pro device:oriole transport_id:3
    0123456789ABCDEF       no permissions (user in plugdev group; are your udev rules wrong?); see [http://x.y/z]
    ZZ99                   unauthorized usb:1-2 transport_id:4

    """

    private func device(_ serial: String) throws -> ADBDevice {
        try XCTUnwrap(parser.parse(fullSample).first { $0.serial == serial }, "device \(serial) tidak ada")
    }

    func testParsesAllDevicesAndSkipsDaemonLines() {
        XCTAssertEqual(parser.parse(fullSample).count, 6)
    }

    func testBareUSBPathIsRecognizedAsUSB() throws {
        let d = try device("R9CN4057BXJ")
        XCTAssertEqual(d.usbPath, "2-1")
        XCTAssertEqual(d.connection, .usb)
    }

    func testPrefixedUSBPathIsRecognizedAsUSB() throws {
        let d = try device("R58M123ABC")
        XCTAssertEqual(d.usbPath, "1-1")
        XCTAssertEqual(d.connection, .usb)
    }

    func testUnderscoresInModelBecomeSpaces() throws {
        XCTAssertEqual(try device("192.168.1.5:5555").displayName, "Pixel 6 Pro")
    }

    func testNoPermissionsIsTwoWordState() throws {
        let d = try device("0123456789ABCDEF")
        XCTAssertEqual(d.state, .noPermissions)
        XCTAssertNil(d.model, "token berisi URL tidak boleh dianggap atribut")
    }

    func testStates() throws {
        XCTAssertEqual(try device("emulator-5554").state, .offline)
        XCTAssertEqual(try device("ZZ99").state, .unauthorized)
        XCTAssertEqual(try device("R58M123ABC").state, .device)
    }

    func testConnectionTypeFromSerial() throws {
        XCTAssertEqual(try device("emulator-5554").connection, .emulator)
        XCTAssertEqual(try device("192.168.1.5:5555").connection, .network)
    }

    func testDevicesAreSortedBySerial() {
        let serials = parser.parse(fullSample).map(\.serial)
        XCTAssertEqual(serials, serials.sorted { $0.localizedStandardCompare($1) == .orderedAscending })
    }

    func testEmptyListAndMissingHeader() {
        XCTAssertTrue(parser.parse("List of devices attached\n\n").isEmpty)
        XCTAssertTrue(parser.parse("garbage output").isEmpty)
        XCTAssertTrue(parser.parse("").isEmpty)
    }

    func testLineWithOnlySerialIsIgnored() {
        XCTAssertTrue(parser.parse("List of devices attached\nONLYSERIAL\n").isEmpty)
    }
}
