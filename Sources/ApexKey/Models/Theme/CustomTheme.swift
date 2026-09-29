//
//  CustomTheme.swift
//  ApexKey
//
//  Custom theme model
//

import AppKit
import Foundation
import SwiftUI

// MARK: - Custom Theme

/// Complete custom theme configuration
public struct CustomTheme: Codable, Equatable, Sendable {
    public var metadata: ThemeMetadata
    public var colors: ThemeColors
    public var background: ThemeBackground
    public var glass: ThemeGlass
    public var typography: ThemeTypography
    public var animationConfig: ThemeAnimation
    public var shadows: ThemeShadows
    public var messages: ThemeMessages
    public var borders: ThemeBorders
    public var inputStyle: ThemeInputStyle

    /// Syntax highlighting theme name (Highlightr). nil = auto (dark/light).
    public var codeHighlightTheme: String?

    /// Optional library provenance. Missing values are treated as local
    /// custom themes, while built-in presets are always classified as built-in.
    public var library: ThemeLibraryInfo?

    /// Whether this is a built-in theme (cannot be deleted)
    public var isBuiltIn: Bool
    public var isDark: Bool

    /// When true, accent-adjacent colors are re-derived from the user's
    /// system accent color (System Settings > Appearance) at theme-build
    /// time. The stored hex values act as the palette for the default
    /// (blue) accent. See `ThemeColors.applyingAccent(_:isDark:)`.
    public var followsSystemAccent: Bool

    public init(
        metadata: ThemeMetadata = ThemeMetadata(),
        colors: ThemeColors = ThemeColors(),
        background: ThemeBackground = .default,
        glass: ThemeGlass = ThemeGlass(),
        typography: ThemeTypography = ThemeTypography(),
        animationConfig: ThemeAnimation = ThemeAnimation(),
        shadows: ThemeShadows = ThemeShadows(),
        messages: ThemeMessages = ThemeMessages(),
        borders: ThemeBorders = ThemeBorders(),
        inputStyle: ThemeInputStyle = .gradient,
        codeHighlightTheme: String? = nil,
        library: ThemeLibraryInfo? = nil,
        isBuiltIn: Bool = false,
        isDark: Bool = true,
        followsSystemAccent: Bool = false
    ) {
        self.metadata = metadata
        self.colors = colors
        self.background = background
        self.glass = glass
        self.typography = typography
        self.animationConfig = animationConfig
        self.shadows = shadows
        self.messages = messages
        self.borders = borders
        self.inputStyle = inputStyle
        self.codeHighlightTheme = codeHighlightTheme
        self.library = library
        self.isBuiltIn = isBuiltIn
        self.isDark = isDark
        self.followsSystemAccent = followsSystemAccent
    }

    /// Backward-compatible decoding: new fields fall back to defaults if missing
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        metadata = try container.decode(ThemeMetadata.self, forKey: .metadata)
        colors = try container.decode(ThemeColors.self, forKey: .colors)
        background = try container.decode(ThemeBackground.self, forKey: .background)
        glass = try container.decode(ThemeGlass.self, forKey: .glass)
        typography = try container.decode(ThemeTypography.self, forKey: .typography)
        animationConfig = try container.decode(ThemeAnimation.self, forKey: .animationConfig)
        shadows = try container.decode(ThemeShadows.self, forKey: .shadows)
        messages = try container.decodeIfPresent(ThemeMessages.self, forKey: .messages) ?? ThemeMessages()
        borders = try container.decodeIfPresent(ThemeBorders.self, forKey: .borders) ?? ThemeBorders()
        inputStyle = try container.decodeIfPresent(ThemeInputStyle.self, forKey: .inputStyle) ?? .gradient
        codeHighlightTheme = try container.decodeIfPresent(String.self, forKey: .codeHighlightTheme)
        library = try container.decodeIfPresent(ThemeLibraryInfo.self, forKey: .library)
        isBuiltIn = try container.decode(Bool.self, forKey: .isBuiltIn)
        isDark = try container.decode(Bool.self, forKey: .isDark)
        followsSystemAccent = try container.decodeIfPresent(Bool.self, forKey: .followsSystemAccent) ?? false
    }
}
