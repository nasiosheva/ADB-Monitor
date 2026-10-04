//
//  Foundation+Helpers.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

extension StringProtocol {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension FileManager {
    /// `true` jika `path` adalah file biasa (bukan direktori) yang bisa dieksekusi.
    func isRunnableFile(atPath path: String) -> Bool {
        var isDirectory: ObjCBool = false
        return fileExists(atPath: path, isDirectory: &isDirectory)
            && !isDirectory.boolValue
            && isExecutableFile(atPath: path)
    }
}
