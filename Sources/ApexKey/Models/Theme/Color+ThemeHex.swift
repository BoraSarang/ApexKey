//
//  Color+ThemeHex.swift
//  ApexKey
//
//  Color(themeHex:) parsing with cache
//

import AppKit
import Foundation
import SwiftUI

// MARK: - Color Parsing Extension

extension Color {
    // Theme color accessors funnel through this initializer from view bodies
    // on every SwiftUI body evaluation, and each call pays for a CharacterSet
    // inversion plus a Scanner parse. Themes draw from a small fixed palette,
    // so parsed colors are memoized by their hex string.
    private static let themeHexCacheLock = NSLock()
    private nonisolated(unsafe) static var themeHexCache: [String: Color] = [:]

    /// Initialize from hex string with alpha support
    init(themeHex hex: String) {
        Color.themeHexCacheLock.lock()
        if let cached = Color.themeHexCache[hex] {
            Color.themeHexCacheLock.unlock()
            self = cached
            return
        }
        Color.themeHexCacheLock.unlock()

        let key = hex
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a: UInt64
        let r: UInt64
        let g: UInt64
        let b: UInt64
        switch hex.count {
        case 3:  // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  // RGBA (32-bit) — theme colors are authored web-style with
            // trailing alpha ("#3b82f680", accent+"45"). This previously read
            // ARGB, so the leading red byte became the alpha and colors like
            // the system-accent selection "#007aff26" resolved fully
            // transparent (invisible selection highlight, issue #2129).
            // Mirrors the same fix in Color(hex:) (Theme.swift).
            (r, g, b, a) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )

        Color.themeHexCacheLock.lock()
        // Safety-net cap (reset-on-overflow): the theme palette is small and
        // fixed, but custom themes contribute arbitrary hex strings over time.
        if Color.themeHexCache.count >= 512 { Color.themeHexCache.removeAll() }
        Color.themeHexCache[key] = self
        Color.themeHexCacheLock.unlock()
    }

    /// Convert Color to hex string
    func toHex(includeAlpha: Bool = false) -> String {
        // Convert to sRGB color space first for consistent round-trip with Color(themeHex:)
        let nsColor: NSColor
        if let converted = NSColor(self).usingColorSpace(.sRGB) {
            nsColor = converted
        } else if let converted = NSColor(self).usingColorSpace(.deviceRGB) {
            nsColor = converted
        } else {
            return "#000000"
        }

        let r = Int((nsColor.redComponent * 255).rounded())
        let g = Int((nsColor.greenComponent * 255).rounded())
        let b = Int((nsColor.blueComponent * 255).rounded())
        let a = Int((nsColor.alphaComponent * 255).rounded())

        if includeAlpha && a < 255 {
            return String(format: "#%02X%02X%02X%02X", a, r, g, b)
        }
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
