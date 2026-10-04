//
//  WirelessPrompterTests.swift
//  ADBMonitorTests
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import AppKit
import XCTest
@testable import ADBMonitor

/// Checks the dialog layout without showing it. Regression: the text field once collapsed to width 0
/// (inside an `NSStackView`), so the "Connect to IP Address" dialog could not be typed into.
@MainActor
final class WirelessPrompterTests: XCTestCase {

    private func makePrompter(_ language: AppLanguage = .english) -> AppKitWirelessPrompter {
        let localizer = Localizer(provider: StubLanguage(languagePreference: .explicit(language)),
                                  notificationCenter: NotificationCenter())
        return AppKitWirelessPrompter(localizer: localizer)
    }

    /// Forces `NSAlert` to lay itself out, as it does before `runModal()`.
    private func laidOut(_ dialog: PromptDialog) -> PromptDialog {
        dialog.alert.layout()
        return dialog
    }

    private func assertUsable(_ field: NSTextField, in dialog: PromptDialog,
                              file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(field.frame.width, AppKitWirelessPrompter.fieldWidth, "lebar kolom", file: file, line: line)
        XCTAssertEqual(field.frame.height, AppKitWirelessPrompter.fieldHeight, "tinggi kolom", file: file, line: line)
        XCTAssertTrue(field.isEditable, "kolom harus bisa diketik", file: file, line: line)
        XCTAssertTrue(field.isDescendant(of: dialog.alert.window.contentView ?? NSView()),
                      "kolom harus berada di dalam jendela dialog", file: file, line: line)
    }

    // MARK: Connect

    func testConnectDialogHasOneFullWidthEditableField() {
        let dialog = laidOut(makePrompter().makeConnectDialog())
        XCTAssertEqual(dialog.fields.count, 1)
        assertUsable(dialog.fields[0], in: dialog)
    }

    func testConnectDialogTextAndButtons() {
        let dialog = makePrompter().makeConnectDialog()
        XCTAssertEqual(dialog.alert.messageText, "Connect over Wi-Fi")
        XCTAssertEqual(dialog.alert.buttons.map(\.title), ["Connect", "Cancel"])
        XCTAssertEqual(dialog.fields[0].placeholderString, "192.168.1.5:5555")
        XCTAssertEqual(dialog.fields[0].stringValue, "")
    }

    // MARK: Pairing

    func testPairingDialogHasTwoFullWidthFields() {
        let dialog = laidOut(makePrompter().makePairingDialog(prefilledAddress: nil))
        XCTAssertEqual(dialog.fields.count, 2)
        dialog.fields.forEach { assertUsable($0, in: dialog) }
    }

    func testPairingFieldsAreStackedWithoutOverlapAndAddressIsOnTop() {
        let dialog = laidOut(makePrompter().makePairingDialog(prefilledAddress: nil))
        let address = dialog.fields[0].frame
        let code = dialog.fields[1].frame
        XCTAssertGreaterThanOrEqual(address.minY, code.maxY + AppKitWirelessPrompter.fieldSpacing - 0.5,
                                    "alamat di atas kode, dengan jarak")
        XCTAssertEqual(address.minX, code.minX)
    }

    func testPairingDialogPrefillsTheAddress() {
        let dialog = makePrompter().makePairingDialog(prefilledAddress: "192.168.1.5:41223")
        XCTAssertEqual(dialog.fields[0].stringValue, "192.168.1.5:41223")
        XCTAssertEqual(dialog.fields[1].stringValue, "")
    }

    func testPairingDialogTextAndButtons() {
        let dialog = makePrompter().makePairingDialog(prefilledAddress: nil)
        XCTAssertEqual(dialog.alert.buttons.map(\.title), ["Pair", "Cancel"])
        XCTAssertEqual(dialog.fields[1].placeholderString, "6-digit pairing code")
    }

    // MARK: All languages

    func testEveryLanguageProducesUsableDialogs() {
        for language in AppLanguage.allCases {
            let prompter = makePrompter(language)
            let dialogs = [prompter.makeConnectDialog(), prompter.makePairingDialog(prefilledAddress: nil)]
            for dialog in dialogs.map(laidOut) {
                XCTAssertFalse(dialog.alert.messageText.isEmpty, "\(language.rawValue) judul")
                XCTAssertFalse(dialog.alert.informativeText.isEmpty, "\(language.rawValue) isi")
                XCTAssertTrue(dialog.alert.buttons.allSatisfy { !$0.title.isEmpty }, "\(language.rawValue) tombol")
                dialog.fields.forEach { assertUsable($0, in: dialog) }
            }
        }
    }
}
