//
//  FastbootDevice.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

/// A device that is in fastboot mode (bootloader or fastbootd), as listed by `fastboot devices`.
/// adb does not see such a device.
struct FastbootDevice: Equatable, Hashable {
    let serial: String
    /// The mode word printed by fastboot, for example "fastboot" or "fastbootd".
    let mode: String
}
