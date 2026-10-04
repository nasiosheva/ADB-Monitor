//
//  QRCodeRenderer.swift
//  ADBMonitor
//
//  Copyright © 2026 Mories Deo Hutapea,S.E.,S.Kom
//

import AppKit
import CoreImage

/// Draws a string as a QR code bitmap.
enum QRCodeRenderer {

    /// Quiet zone around the code, in QR modules. The spec asks for 4; scanners cope with fewer, but not none.
    private static let quietZoneModules = 4

    /// A square image of `side` points: black modules on white, with a quiet zone, scaled without smoothing.
    /// Returns `nil` if the string cannot be encoded.
    static func image(for text: String, side: CGFloat) -> NSImage? {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(Data(text.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage,
              let code = CIContext().createCGImage(output, from: output.extent) else { return nil }

        // The CI image has one pixel per module. Pick a whole-number scale so modules stay crisp.
        let modules = code.width
        let totalModules = modules + 2 * quietZoneModules
        let scale = max(1, Int(side) / totalModules)
        let pixels = totalModules * scale

        guard let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: CGColorSpaceCreateDeviceGray(),
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: pixels, height: pixels))
        context.interpolationQuality = .none
        let inset = quietZoneModules * scale
        context.draw(code, in: CGRect(x: inset, y: inset, width: modules * scale, height: modules * scale))

        guard let rendered = context.makeImage() else { return nil }
        return NSImage(cgImage: rendered, size: NSSize(width: pixels, height: pixels))
    }
}
