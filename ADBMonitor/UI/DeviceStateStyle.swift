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

    /// Judul menu dengan titik berwarna di depan, misalnya "● Pixel 3a (…) — Connected".
    ///
    /// Warna dibawa oleh judul beratribut, bukan `NSMenuItem.image`: macOS tidak menampilkan gambar kustom
    /// pada item menu ini (SF Symbol, bitmap, maupun drawing handler tidak muncul), sedangkan warna pada teks
    /// tampil dan mengikuti light/dark mode lewat warna sistem dinamis.
    func menuTitle(_ text: String) -> NSAttributedString {
        let font = NSFont.menuFont(ofSize: 0)
        let dot: [NSAttributedString.Key: Any] = [.foregroundColor: indicatorColor, .font: font]
        let title = NSMutableAttributedString(string: "● ", attributes: dot)
        title.append(NSAttributedString(string: text, attributes: [.font: font]))
        return title
    }
}
