//
//  WirelessModelTests.swift
//  ADBMonitorTests
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import XCTest
@testable import ADBMonitor

final class WirelessServiceTests: XCTestCase {

    private func service(_ name: String = "adb-R9CN4057BXJ-aBcDeF",
                         kind: WirelessService.Kind = .connect,
                         host: String = "192.168.1.5",
                         port: Int = 37899) -> WirelessService {
        WirelessService(name: name, kind: kind, host: host, port: port)
    }

    func testAddressJoinsHostAndPort() {
        XCTAssertEqual(service().address, "192.168.1.5:37899")
    }

    func testDisplayNameStripsPrefixAndRandomSuffix() {
        XCTAssertEqual(service("adb-R9CN4057BXJ-aBcDeF").displayName, "R9CN4057BXJ")
        XCTAssertEqual(service("adb-ABC-DEF-xyz123").displayName, "ABC-DEF", "serial yang berisi tanda hubung")
    }

    func testDisplayNameFallsBackToTheRawName() {
        XCTAssertEqual(service("my-phone").displayName, "my-phone")
        XCTAssertEqual(service("adb-NOSUFFIX").displayName, "NOSUFFIX")
    }

    func testConnectedByMdnsSerial() {
        let connected = [Sample.device("adb-R9CN4057BXJ-aBcDeF._adb-tls-connect._tcp")]
        XCTAssertTrue(service().isConnected(among: connected))
    }

    func testConnectedByManualAddress() {
        XCTAssertTrue(service().isConnected(among: [Sample.device("192.168.1.5:37899")]))
    }

    func testNotConnectedWhenNoDeviceMatches() {
        XCTAssertFalse(service().isConnected(among: []))
        XCTAssertFalse(service().isConnected(among: [Sample.device("R9CN4057BXJ"), Sample.device("192.168.1.9:5555")]))
    }

    func testPairingServiceIsNeverConsideredConnected() {
        let devices = [Sample.device("adb-R9CN4057BXJ-aBcDeF._adb-tls-connect._tcp")]
        XCTAssertFalse(service(kind: .pairing).isConnected(among: devices))
    }
}

final class WirelessAddressTests: XCTestCase {

    func testHostWithoutPortGetsTheDefaultPort() {
        XCTAssertEqual(WirelessAddress.normalized("192.168.1.5"), "192.168.1.5:5555")
        XCTAssertEqual(WirelessAddress.normalized("  phone.local  "), "phone.local:5555")
    }

    func testExplicitPortIsKept() {
        XCTAssertEqual(WirelessAddress.normalized("192.168.1.5:37899"), "192.168.1.5:37899")
    }

    func testPortIsRequiredForPairing() {
        XCTAssertNil(WirelessAddress.normalized("192.168.1.5", requirePort: true))
        XCTAssertEqual(WirelessAddress.normalized("192.168.1.5:41223", requirePort: true), "192.168.1.5:41223")
    }

    func testInvalidInputsAreRejected() {
        let invalid = ["", "   ", ":5555", "192.168.1.5:", "192.168.1.5:abc", "192.168.1.5:0", "192.168.1.5:65536",
                       "192.168.1.5:99999", "a:b:c", "has space", "192.168.1.5:55 55", "-evil", ".hidden",
                       "host;rm -rf /", "$(whoami)", "ho$t", "[::1]:5555", "tést"]
        for input in invalid {
            XCTAssertNil(WirelessAddress.normalized(input), "\"\(input)\" seharusnya ditolak")
        }
    }

    func testPortBoundaries() {
        XCTAssertEqual(WirelessAddress.normalized("h:1"), "h:1")
        XCTAssertEqual(WirelessAddress.normalized("h:65535"), "h:65535")
    }

    func testPairingCodeMustBeSixAsciiDigits() {
        XCTAssertTrue(WirelessAddress.isValidPairingCode("123456"))
        XCTAssertTrue(WirelessAddress.isValidPairingCode(" 123456 "))
        for bad in ["", "12345", "1234567", "12345a", "12 456", "١٢٣٤٥٦"] {
            XCTAssertFalse(WirelessAddress.isValidPairingCode(bad), "\"\(bad)\"")
        }
    }
}

final class WirelessServiceParserTests: XCTestCase {

    private let parser = WirelessServiceParser()

    private let sample = """
    List of discovered mdns services
    adb-R9CN4057BXJ-aBcDeF\t_adb-tls-connect._tcp.\t192.168.1.5:37899
    adb-R9CN4057BXJ-xYz123\t_adb-tls-pairing._tcp.\t192.168.1.5:41223
    adb-94GAY0NRYY-qwerty\t_adb-tls-connect._tcp.\t192.168.1.9:40001
    """

    func testParsesConnectAndPairingServices() {
        let services = parser.parse(sample)
        XCTAssertEqual(services.count, 3)
        XCTAssertEqual(services.filter { $0.kind == .pairing }.map(\.address), ["192.168.1.5:41223"])
        XCTAssertEqual(services.filter { $0.kind == .connect }.map(\.address),
                       ["192.168.1.9:40001", "192.168.1.5:37899"])
    }

    func testResultsAreSortedByName() {
        XCTAssertEqual(parser.parse(sample).map(\.name),
                       ["adb-94GAY0NRYY-qwerty", "adb-R9CN4057BXJ-aBcDeF", "adb-R9CN4057BXJ-xYz123"])
    }

    func testLegacyAdbServiceTypeCountsAsConnect() {
        let output = "List of discovered mdns services\nphone\t_adb._tcp.\t192.168.1.7:5555\n"
        XCTAssertEqual(parser.parse(output).first?.kind, .connect)
    }

    func testDuplicateLinesAreCollapsed() {
        let line = "adb-X-aBcDeF\t_adb-tls-connect._tcp.\t192.168.1.5:37899"
        XCTAssertEqual(parser.parse("List of discovered mdns services\n\(line)\n\(line)\n").count, 1)
    }

    func testIgnoresUnknownTypesAndMalformedLines() {
        let output = """
        List of discovered mdns services
        printer\t_ipp._tcp.\t192.168.1.20:631
        broken line
        adb-X-aBcDeF\t_adb-tls-connect._tcp.\tno-port
        adb-X-aBcDeF\t_adb-tls-connect._tcp.\t192.168.1.5:99999
        adb-X-aBcDeF\t_adb-tls-connect._tcp.\t:5555
        """
        XCTAssertTrue(parser.parse(output).isEmpty)
    }

    func testEmptyOutputs() {
        XCTAssertTrue(parser.parse("").isEmpty)
        XCTAssertTrue(parser.parse("List of discovered mdns services\n\n").isEmpty)
    }
}

final class WiFiAddressParserTests: XCTestCase {

    func testParsesIpRouteGet() {
        let output = "1.1.1.1 via 192.168.1.1 dev wlan0 src 192.168.1.23 uid 2000 \\    cache"
        XCTAssertEqual(WiFiAddressParser.ipv4(in: output), "192.168.1.23")
    }

    func testParsesInterfaceAddress() {
        let output = """
        24: wlan0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 3000
            inet 10.0.0.42/24 brd 10.0.0.255 scope global wlan0
               valid_lft forever preferred_lft forever
        """
        XCTAssertEqual(WiFiAddressParser.ipv4(in: output), "10.0.0.42")
    }

    func testIgnoresLoopbackAndZeroAddresses() {
        XCTAssertNil(WiFiAddressParser.ipv4(in: "inet 127.0.0.1/8 scope host lo"))
        XCTAssertNil(WiFiAddressParser.ipv4(in: "x dev lo src 0.0.0.0"))
    }

    func testIgnoresOutOfRangeOctets() {
        XCTAssertNil(WiFiAddressParser.ipv4(in: "inet 999.1.1.1/24"))
    }

    func testNoMatchReturnsNil() {
        XCTAssertNil(WiFiAddressParser.ipv4(in: ""))
        XCTAssertNil(WiFiAddressParser.ipv4(in: "Network is unreachable"))
    }

    func testSkipsLoopbackButKeepsALaterRealAddress() {
        let output = "inet 127.0.0.1/8 scope host lo\ninet 192.168.0.8/24 scope global wlan0"
        XCTAssertEqual(WiFiAddressParser.ipv4(in: output), "192.168.0.8")
    }
}
