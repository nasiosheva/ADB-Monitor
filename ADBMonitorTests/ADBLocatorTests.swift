//
//  ADBLocatorTests.swift
//  ADBMonitorTests
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import XCTest
@testable import ADBMonitor

final class ADBLocatorTests: XCTestCase {

    /// Direktori sementara berisi file `adb` yang bisa dieksekusi di `relativePath`.
    private func makeFakeADB(at relativePath: String = "adb") throws -> (root: URL, adb: String) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let file = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "#!/bin/sh\nexit 0\n".write(to: file, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.path)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return (root, file.path)
    }

    /// Hermetik: tanpa jalur "terkenal" (mis. `/opt/homebrew/bin/adb`) supaya hasil tidak bergantung pada mesin.
    private func locator(environment: [String: String] = [:],
                         home: String = "/nonexistent",
                         wellKnown: [String] = []) -> ADBLocator {
        ADBLocator(environment: environment, homeDirectory: home, wellKnownPaths: wellKnown)
    }

    func testValidCustomPathIsReturned() throws {
        let fake = try makeFakeADB()
        XCTAssertEqual(locator().locate(customPath: fake.adb), fake.adb)
    }

    func testInvalidCustomPathReturnsNilWithoutFallback() throws {
        let fake = try makeFakeADB()
        // PATH berisi adb yang valid, tetapi path kustom yang salah tidak boleh jatuh ke deteksi otomatis.
        let result = locator(environment: ["PATH": fake.root.path]).locate(customPath: "/nope/adb")
        XCTAssertNil(result)
    }

    func testDirectoryIsNotAcceptedAsExecutable() {
        XCTAssertNil(locator().locate(customPath: "/bin"))
    }

    func testNonExecutableFileIsRejected() throws {
        let fake = try makeFakeADB()
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: fake.adb)
        XCTAssertNil(locator().locate(customPath: fake.adb))
    }

    func testBlankCustomPathMeansAutoDetect() throws {
        let fake = try makeFakeADB()
        XCTAssertEqual(locator(environment: ["PATH": fake.root.path]).locate(customPath: "   "), fake.adb)
    }

    func testAutoDetectFindsAdbOnPATH() throws {
        let fake = try makeFakeADB()
        let environment = ["PATH": "/nonexistent:\(fake.root.path)"]
        XCTAssertEqual(locator(environment: environment).locate(customPath: nil), fake.adb)
    }

    func testAutoDetectFindsAndroidHome() throws {
        let fake = try makeFakeADB(at: "platform-tools/adb")
        let result = locator(environment: ["ANDROID_HOME": fake.root.path]).locate(customPath: nil)
        XCTAssertEqual(result, fake.adb)
    }

    func testAutoDetectFindsAndroidSDKRoot() throws {
        let fake = try makeFakeADB(at: "platform-tools/adb")
        let result = locator(environment: ["ANDROID_SDK_ROOT": fake.root.path]).locate(customPath: nil)
        XCTAssertEqual(result, fake.adb)
    }

    func testAutoDetectFindsDefaultSDKInHomeDirectory() throws {
        let fake = try makeFakeADB(at: "Library/Android/sdk/platform-tools/adb")
        XCTAssertEqual(locator(home: fake.root.path).locate(customPath: nil), fake.adb)
    }

    func testTildeInCustomPathIsExpanded() throws {
        let home = NSHomeDirectory()
        let relative = "adbmonitor-test-\(UUID().uuidString)"
        let fake = home + "/" + relative
        try "#!/bin/sh\n".write(toFile: fake, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fake)
        addTeardownBlock { try? FileManager.default.removeItem(atPath: fake) }
        XCTAssertEqual(locator().locate(customPath: "~/" + relative), fake)
    }

    func testNothingFoundReturnsNil() {
        XCTAssertNil(locator().locate(customPath: nil))
    }

    func testWellKnownPathIsUsed() throws {
        let fake = try makeFakeADB()
        XCTAssertEqual(locator(wellKnown: [fake.adb]).locate(customPath: nil), fake.adb)
    }

    func testSearchOrderIsPATHThenWellKnownThenSDK() throws {
        let onPath = try makeFakeADB()
        let wellKnown = try makeFakeADB()
        let sdk = try makeFakeADB(at: "platform-tools/adb")
        let env = ["PATH": onPath.root.path, "ANDROID_HOME": sdk.root.path]

        XCTAssertEqual(locator(environment: env, wellKnown: [wellKnown.adb]).locate(customPath: nil), onPath.adb)
        XCTAssertEqual(locator(environment: ["ANDROID_HOME": sdk.root.path], wellKnown: [wellKnown.adb])
                        .locate(customPath: nil), wellKnown.adb)
        XCTAssertEqual(locator(environment: ["ANDROID_HOME": sdk.root.path]).locate(customPath: nil), sdk.adb)
    }

    func testDefaultWellKnownPathsAreDocumented() {
        XCTAssertEqual(ADBLocator.defaultWellKnownPaths,
                       ["/opt/homebrew/bin/adb", "/usr/local/bin/adb", "/usr/bin/adb"])
    }

    func testStringTrimmedHelper() {
        XCTAssertEqual("  a b \n".trimmed, "a b")
        XCTAssertEqual(Substring(" x ").trimmed, "x")
    }

    func testIsRunnableFile() {
        XCTAssertTrue(FileManager.default.isRunnableFile(atPath: "/bin/ls"))
        XCTAssertFalse(FileManager.default.isRunnableFile(atPath: "/bin"))
        XCTAssertFalse(FileManager.default.isRunnableFile(atPath: "/does/not/exist"))
    }
}
