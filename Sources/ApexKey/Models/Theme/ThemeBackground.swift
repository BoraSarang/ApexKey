//
//  ThemeBackground.swift
//  ApexKey
//
//  Theme background (solid/gradient/image)
//

import AppKit
import Foundation
import SwiftUI

// MARK: - Theme Background

/// Background configuration for the theme
public struct ThemeBackground: Codable, Equatable, Sendable {
    public enum BackgroundType: String, Codable, Sendable {
        case solid
        case gradient
        case image
    }

    public enum ImageFit: String, Codable, Sendable {
        case fill
        case fit
        case stretch
        case tile
    }

    public var type: BackgroundType
    public var solidColor: String?
    public var gradientColors: [String]?
    public var gradientAngle: Double?
    public var imageData: String?  // Base64 encoded image data
    public var imageFit: ImageFit?
    public var imageOpacity: Double?
    public var overlayColor: String?
    public var overlayOpacity: Double?

    public init(
        type: BackgroundType = .solid,
        solidColor: String? = nil,
        gradientColors: [String]? = nil,
        gradientAngle: Double? = nil,
        imageData: String? = nil,
        imageFit: ImageFit? = nil,
        imageOpacity: Double? = nil,
        overlayColor: String? = nil,
        overlayOpacity: Double? = nil
    ) {
        self.type = type
        self.solidColor = solidColor
        self.gradientColors = gradientColors
        self.gradientAngle = gradientAngle
        self.imageData = imageData
        self.imageFit = imageFit
        self.imageOpacity = imageOpacity
        self.overlayColor = overlayColor
        self.overlayOpacity = overlayOpacity
    }

    /// Default solid background (uses theme's primary background)
    public static var `default`: ThemeBackground {
        ThemeBackground(type: .solid)
    }

    /// Process-wide cache of decoded background images, keyed by their base64
    /// payload. `CustomizableTheme.backgroundImage` reads `decodedImage()` from
    /// SwiftUI body getters, so without this every render of a themed surface
    /// re-ran a full base64 + `NSImage(data:)` decode of a potentially
    /// wallpaper-sized image on the main thread — enough to trip the app-hang
    /// watchdog. Keying on the payload means edits (new base64) miss naturally;
    /// `NSCache` evicts under memory pressure so no manual invalidation is needed.
    /// `nonisolated(unsafe)` is sound here: `NSCache` performs its own internal
    /// locking, so concurrent `object(forKey:)` / `setObject(_:forKey:)` from any
    /// actor is safe despite the type not being `Sendable`.
    private nonisolated(unsafe) static let decodedImageCache = NSCache<NSString, NSImage>()

    /// Decode base64 image data to NSImage (memoized by payload).
    public func decodedImage() -> NSImage? {
        guard let imageData, !imageData.isEmpty else { return nil }
        let key = imageData as NSString
        if let cached = Self.decodedImageCache.object(forKey: key) { return cached }
        guard let data = Data(base64Encoded: imageData),
            let image = NSImage(data: data)
        else { return nil }
        Self.decodedImageCache.setObject(image, forKey: key)
        return image
    }
}

