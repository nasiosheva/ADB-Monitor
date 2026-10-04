//
//  PairingQRWindowTests.swift
//  ADBMonitorTests
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import AppKit
import XCTest
@testable import ADBMonitor

/// Checks the QR window layout without showing it: every subview must have a real size and sit inside the window,
/// in every language (the texts differ in length, and the layout is computed from them).
@MainActor
final class PairingQRWindowTests: XCTestCase {

    private let payload = PairingQRCredentials(name: "adbmonitor-Ab3dEf9h", password: "Zx81Qw0Lm2Ns").payload

    private func makePanel(_ language: AppLanguage) -> NSPanel {
        let localizer = Localizer(provider: StubLanguage(languagePreference: .explicit(language)),
                                  notificationCenter: NotificationCenter())
        return AppKitPairingQRPresenter(localizer: localizer).makePanel(payload: payload)
    }

    func testEverySubviewHasASizeAndFitsInsideTheWindowInEveryLanguage() throws {
        for language in AppLanguage.allCases {
            let panel = makePanel(language)
            let content = try XCTUnwrap(panel.contentView)
            XCTAssertEqual(content.subviews.count, 5, "\(language)")
            for view in content.subviews {
                XCTAssertGreaterThan(view.frame.width, 0, "\(language) \(type(of: view)) width")
                XCTAssertGreaterThan(view.frame.height, 0, "\(language) \(type(of: view)) height")
                XCTAssertTrue(content.bounds.contains(view.frame), "\(language) \(type(of: view)) \(view.frame)")
            }
        }
    }

    func testTheQRImageIsShownAtFullSize() throws {
        let content = try XCTUnwrap(makePanel(.english).contentView)
        let imageView = try XCTUnwrap(content.subviews.compactMap { $0 as? NSImageView }.first)
        XCTAssertNotNil(imageView.image)
        XCTAssertEqual(imageView.frame.size, NSSize(width: AppKitPairingQRPresenter.qrSide,
                                                    height: AppKitPairingQRPresenter.qrSide))
    }

    func testSubviewsDoNotOverlap() throws {
        let content = try XCTUnwrap(makePanel(.english).contentView)
        let frames = content.subviews.map(\.frame)
        for (i, a) in frames.enumerated() {
            for b in frames[(i + 1)...] { XCTAssertFalse(a.intersects(b), "\(a) overlaps \(b)") }
        }
    }
}
