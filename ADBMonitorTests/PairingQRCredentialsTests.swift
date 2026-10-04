//
//  PairingQRCredentialsTests.swift
//  ADBMonitorTests
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import CoreImage
import XCTest
@testable import ADBMonitor

final class PairingQRCredentialsTests: XCTestCase {

    func testPayloadUsesTheAndroidWifiFormat() {
        let credentials = PairingQRCredentials(name: "adbmonitor-Ab3dEf9h", password: "Zx81Qw0Lm2Ns")
        XCTAssertEqual(credentials.payload, "WIFI:T:ADB;S:adbmonitor-Ab3dEf9h;P:Zx81Qw0Lm2Ns;;")
    }

    func testRandomCredentialsAreAlphanumericAndNeverRepeat() {
        let all = (0..<50).map { _ in PairingQRCredentials.random() }
        XCTAssertEqual(Set(all.map(\.password)).count, 50)
        XCTAssertEqual(Set(all.map(\.name)).count, 50)
        for credentials in all {
            XCTAssertTrue(credentials.name.hasPrefix("adbmonitor-"))
            XCTAssertEqual(credentials.password.count, 12)
            XCTAssertTrue(WirelessAddress.isValidQRPassword(credentials.password))
            // Nothing that needs escaping in the `WIFI:` format may appear in the name or the password.
            XCTAssertTrue((credentials.name + credentials.password).allSatisfy {
                $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-")
            }, "no WIFI: special characters")
        }
    }

    func testQRPasswordValidation() {
        XCTAssertTrue(WirelessAddress.isValidQRPassword("Zx81Qw0Lm2Ns"))
        XCTAssertFalse(WirelessAddress.isValidQRPassword(""))
        XCTAssertFalse(WirelessAddress.isValidQRPassword("-h"))
        XCTAssertFalse(WirelessAddress.isValidQRPassword("a b"))
        XCTAssertFalse(WirelessAddress.isValidQRPassword("abc;def"))
        XCTAssertFalse(WirelessAddress.isValidQRPassword(String(repeating: "a", count: 65)))
    }
}

final class QRCodeRendererTests: XCTestCase {

    func testTheImageIsSquareAndDecodesBackToTheSamePayload() throws {
        let payload = PairingQRCredentials(name: "adbmonitor-Ab3dEf9h", password: "Zx81Qw0Lm2Ns").payload
        let image = try XCTUnwrap(QRCodeRenderer.image(for: payload, side: 240))
        XCTAssertEqual(image.size.width, image.size.height)
        XCTAssertLessThanOrEqual(image.size.width, 240)
        XCTAssertGreaterThan(image.size.width, 150, "scaled up, not one pixel per module")

        let cgImage = try XCTUnwrap(image.cgImage(forProposedRect: nil, context: nil, hints: nil))
        let detector = try XCTUnwrap(CIDetector(ofType: CIDetectorTypeQRCode, context: nil,
                                                options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]))
        let features = detector.features(in: CIImage(cgImage: cgImage)).compactMap { $0 as? CIQRCodeFeature }
        XCTAssertEqual(features.first?.messageString, payload)
    }
}
