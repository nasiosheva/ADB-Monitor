//
//  DeviceDetails.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

/// Extra information read from a connected device, shown in its submenu.
struct DeviceDetails: Equatable {
    /// For example "12". `nil` when the device did not report one.
    var androidVersion: String?
    /// Battery charge in percent (0-100). `nil` when it could not be read.
    var batteryLevel: Int?

    var isEmpty: Bool { androidVersion == nil && batteryLevel == nil }
}
