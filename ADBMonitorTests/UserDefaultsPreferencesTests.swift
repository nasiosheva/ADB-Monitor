//
//  UserDefaultsPreferencesTests.swift
//  ADBMonitorTests
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import XCTest
@testable import ADBMonitor

final class UserDefaultsPreferencesTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!
    private var center: NotificationCenter!
    private var preferences: UserDefaultsPreferences!

    override func setUp() {
        super.setUp()
        suiteName = "adbmonitor.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        center = NotificationCenter()
        preferences = UserDefaultsPreferences(defaults: defaults, notificationCenter: center)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testDefaults() {
        XCTAssertNil(preferences.adbPath)
        XCTAssertEqual(preferences.refreshInterval, RefreshIntervalLimits.default)
        XCTAssertEqual(preferences.languagePreference, .system)
    }

    func testSaveTrimsPath() {
        preferences.save(adbPath: "  /a/adb \n", refreshInterval: 3, language: .system, wirelessDiscovery: true)
        XCTAssertEqual(preferences.adbPath, "/a/adb")
    }

    func testBlankPathClearsTheStoredValue() {
        preferences.save(adbPath: "/a/adb", refreshInterval: 3, language: .system, wirelessDiscovery: true)
        preferences.save(adbPath: "   ", refreshInterval: 3, language: .system, wirelessDiscovery: true)
        XCTAssertNil(preferences.adbPath)
        XCTAssertNil(defaults.string(forKey: "adbPath"))
    }

    func testRefreshIntervalIsClamped() {
        preferences.save(adbPath: nil, refreshInterval: 999, language: .system, wirelessDiscovery: true)
        XCTAssertEqual(preferences.refreshInterval, 60)
        preferences.save(adbPath: nil, refreshInterval: 0.1, language: .system, wirelessDiscovery: true)
        XCTAssertEqual(preferences.refreshInterval, 1)
        preferences.save(adbPath: nil, refreshInterval: 7, language: .system, wirelessDiscovery: true)
        XCTAssertEqual(preferences.refreshInterval, 7)
    }

    func testClampingAlsoAppliesToValuesWrittenByOthers() {
        defaults.set(5000.0, forKey: "refreshInterval")
        XCTAssertEqual(preferences.refreshInterval, 60)
    }

    func testLanguageRoundTripAndSystemRemovesTheKey() {
        for language in AppLanguage.allCases {
            preferences.save(adbPath: nil, refreshInterval: 3, language: .explicit(language), wirelessDiscovery: true)
            XCTAssertEqual(preferences.languagePreference, .explicit(language))
        }
        preferences.save(adbPath: nil, refreshInterval: 3, language: .system, wirelessDiscovery: true)
        XCTAssertEqual(preferences.languagePreference, .system)
        XCTAssertNil(defaults.string(forKey: "language"))
    }

    func testUnknownStoredLanguageFallsBackToSystem() {
        defaults.set("klingon", forKey: "language")
        XCTAssertEqual(preferences.languagePreference, .system)
    }

    func testWirelessDiscoveryIsOnByDefaultAndPersists() {
        XCTAssertTrue(preferences.wirelessDiscoveryEnabled)
        preferences.save(adbPath: nil, refreshInterval: 3, language: .system, wirelessDiscovery: false)
        XCTAssertFalse(preferences.wirelessDiscoveryEnabled)
        preferences.save(adbPath: nil, refreshInterval: 3, language: .system, wirelessDiscovery: true)
        XCTAssertTrue(preferences.wirelessDiscoveryEnabled)
    }

    func testSavePostsOneNotification() {
        var count = 0
        let token = center.addObserver(forName: .preferencesDidChange, object: nil, queue: nil) { _ in count += 1 }
        defer { center.removeObserver(token) }
        preferences.save(adbPath: nil, refreshInterval: 3, language: .system, wirelessDiscovery: true)
        XCTAssertEqual(count, 1)
    }
}
