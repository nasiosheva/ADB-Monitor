//
//  UncheckedSendable.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

/// Carries a non-Sendable value across a `@Sendable` boundary.
///
/// Only used in two places whose invariants are guaranteed and documented where it is used:
/// a closure that is called exactly once, and a closure that only runs on the main run loop.
struct UncheckedSendable<Value>: @unchecked Sendable {
    let value: Value

    init(_ value: Value) {
        self.value = value
    }
}
