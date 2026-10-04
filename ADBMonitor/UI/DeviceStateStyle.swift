//
//  DeviceStateStyle.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import AppKit

/// Gaya tampilan untuk `ADBDevice.State`, dipisahkan dari model agar model tidak bergantung pada AppKit.
extension ADBDevice.State {

    var indicatorColor: NSColor {
        switch self {
        case .device: return .systemGreen
        case .unauthorized, .noPermissions, .authorizing, .connecting: return .systemOrange
        case .offline: return .systemRed
        case .recovery, .sideload, .bootloader, .unknown: return .systemGray
        }
    }

    /// Petunjuk untuk pengguna jika state memerlukan tindakan.
    var hint: String? {
        switch self {
        case .unauthorized: return "Accept the USB debugging prompt on the device."
        case .noPermissions: return "Check USB permissions / udev rules."
        case .offline: return "Reconnect the device or restart the adb server."
        default: return nil
        }
    }

    /// Titik berwarna; drawing handler dievaluasi ulang saat appearance berubah sehingga warna tetap benar di dark mode.
    func indicatorImage(size: CGFloat = 10) -> NSImage {
        let color = indicatorColor
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            color.setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1)).fill()
            return true
        }
        image.isTemplate = false
        return image
    }
}
