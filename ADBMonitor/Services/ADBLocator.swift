//
//  ADBLocator.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

protocol ADBLocating {
    /// Path of an executable `adb`, or `nil`.
    /// If `customPath` is set, only that path is checked (no fallback to auto-detection).
    func locate(customPath: String?) -> String?
}

struct ADBLocator: ADBLocating {

    static let defaultWellKnownPaths = wellKnownPaths(for: "adb")

    /// The usual install locations of an Android platform tool such as `adb` or `fastboot`.
    static func wellKnownPaths(for executableName: String) -> [String] {
        ["/opt/homebrew/bin/\(executableName)", "/usr/local/bin/\(executableName)", "/usr/bin/\(executableName)"]
    }

    private let environment: [String: String]
    private let fileManager: FileManager
    private let homeDirectory: String
    private let wellKnownPaths: [String]
    private let executableName: String

    /// `wellKnownPaths` can be replaced so the search result does not depend on what is on disk (used by tests).
    /// `executableName` lets the same search find another platform tool, for example `fastboot`.
    init(environment: [String: String] = ProcessInfo.processInfo.environment,
         fileManager: FileManager = .default,
         homeDirectory: String = NSHomeDirectory(),
         wellKnownPaths: [String]? = nil,
         executableName: String = "adb") {
        self.environment = environment
        self.fileManager = fileManager
        self.homeDirectory = homeDirectory
        self.executableName = executableName
        self.wellKnownPaths = wellKnownPaths ?? Self.wellKnownPaths(for: executableName)
    }

    func locate(customPath: String?) -> String? {
        if let customPath = customPath?.trimmed, !customPath.isEmpty {
            let expanded = (customPath as NSString).expandingTildeInPath
            return fileManager.isRunnableFile(atPath: expanded) ? expanded : nil
        }
        return autoDetectCandidates().first(where: fileManager.isRunnableFile(atPath:))
    }

    private func autoDetectCandidates() -> [String] {
        let searchPath = (environment["PATH"] ?? "").split(separator: ":").map { "\($0)/\(executableName)" }
        let sdkRoots = ["ANDROID_HOME", "ANDROID_SDK_ROOT"]
            .compactMap { environment[$0] }
            .filter { !$0.isEmpty }
            .map { "\($0)/platform-tools/\(executableName)" }
        let defaultSDK = "\(homeDirectory)/Library/Android/sdk/platform-tools/\(executableName)"

        return searchPath + wellKnownPaths + sdkRoots + [defaultSDK]
    }
}
