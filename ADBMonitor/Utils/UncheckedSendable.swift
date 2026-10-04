//
//  UncheckedSendable.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

/// Membawa nilai non-Sendable melewati batas `@Sendable`.
///
/// Hanya dipakai di dua titik yang invariannya terjamin dan terdokumentasi di tempat pemakaian:
/// closure yang dipanggil tepat sekali, dan closure yang hanya dijalankan di main run loop.
struct UncheckedSendable<Value>: @unchecked Sendable {
    let value: Value

    init(_ value: Value) {
        self.value = value
    }
}
