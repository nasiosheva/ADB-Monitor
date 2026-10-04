//
//  ADBLocator.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

protocol ADBLocating {
    /// Path `adb` yang bisa dieksekusi, atau `nil`.
    /// Jika `customPath` diisi, hanya path itu yang diperiksa (tanpa fallback ke deteksi otomatis).
    func locate(customPath: String?) -> String?
}

struct ADBLocator: ADBLocating {

    static let defaultWellKnownPaths = [
        "/opt/homebrew/bin/adb",
        "/usr/local/bin/adb",
        "/usr/bin/adb",
    ]

    private let environment: [String: String]
    private let fileManager: FileManager
    private let homeDirectory: String
    private let wellKnownPaths: [String]

    /// `wellKnownPaths` bisa diganti agar hasil pencarian tidak bergantung pada isi disk (dipakai oleh pengujian).
    init(environment: [String: String] = ProcessInfo.processInfo.environment,
         fileManager: FileManager = .default,
         homeDirectory: String = NSHomeDirectory(),
         wellKnownPaths: [String] = ADBLocator.defaultWellKnownPaths) {
        self.environment = environment
        self.fileManager = fileManager
        self.homeDirectory = homeDirectory
        self.wellKnownPaths = wellKnownPaths
    }

    func locate(customPath: String?) -> String? {
        if let customPath = customPath?.trimmed, !customPath.isEmpty {
            let expanded = (customPath as NSString).expandingTildeInPath
            return fileManager.isRunnableFile(atPath: expanded) ? expanded : nil
        }
        return autoDetectCandidates().first(where: fileManager.isRunnableFile(atPath:))
    }

    private func autoDetectCandidates() -> [String] {
        let searchPath = (environment["PATH"] ?? "").split(separator: ":").map { "\($0)/adb" }
        let sdkRoots = ["ANDROID_HOME", "ANDROID_SDK_ROOT"]
            .compactMap { environment[$0] }
            .filter { !$0.isEmpty }
            .map { "\($0)/platform-tools/adb" }
        let defaultSDK = "\(homeDirectory)/Library/Android/sdk/platform-tools/adb"

        return searchPath + wellKnownPaths + sdkRoots + [defaultSDK]
    }
}
