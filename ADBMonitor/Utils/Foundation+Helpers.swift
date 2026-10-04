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
    /// `true` if `path` is a regular file (not a directory) that can be executed.
    func isRunnableFile(atPath path: String) -> Bool {
        var isDirectory: ObjCBool = false
        return fileExists(atPath: path, isDirectory: &isDirectory)
            && !isDirectory.boolValue
            && isExecutableFile(atPath: path)
    }
}
