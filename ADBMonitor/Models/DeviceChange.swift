//
//  DeviceChange.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import Foundation

/// A device that appeared in or vanished from the list of connected devices.
enum DeviceChange: Equatable {
    case connected(ADBDevice)
    case disconnected(ADBDevice)
}
