//
//  ADBStatus.swift
//  ADBMonitor
//

import Foundation

/// Keadaan yang ditampilkan UI hasil polling terakhir.
enum ADBStatus: Equatable {
    case devices([ADBDevice])
    case adbNotFound(customPath: String?)
    case failure(String)

    init(result: Result<[ADBDevice], ADBError>) {
        switch result {
        case .success(let devices):
            self = .devices(devices)
        case .failure(.notFound(let customPath)):
            self = .adbNotFound(customPath: customPath)
        case .failure(let error):
            self = .failure(error.message)
        }
    }
}
