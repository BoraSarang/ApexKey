//
//  ThemeColors.swift
//  ApexKey
//
//  Theme color palette and system accent derivation
//

import AppKit
import Foundation
import SwiftUI

// MARK: - Theme Colors

/// All customizable colors in a theme
public struct ThemeColors: Codable, Equatable, Sendable {
    // Primary colors
    public var primaryText: String
    public var secondaryText: String
    public var tertiaryText: String

    // Background colors
    public var primaryBackground: String
    public var secondaryBackground: String
    public var tertiaryBackground: String

    // Sidebar colors
    public var sidebarBackground: String
    public var sidebarSelectedBackground: String

    // Accent colors
    public var accentColor: String
    public var accentColorLight: String

    // Border colors
    public var primaryBorder: String
    public var secondaryBorder: String
    public var focusBorder: String

    // Status colors
    public var successColor: String
    public var warningColor: String
    public var errorColor: String
    public var infoColor: String

    // Component specific
    public var cardBackground: String
    public var cardBorder: String
    public var buttonBackground: String
    public var buttonBorder: String
    public var inputBackground: String
    public var inputBorder: String
    public var glassTintOverlay: String
    public var codeBlockBackground: String

    // Shadow
    public var shadowColor: String

    // Selection (text highlight)
    public var selectionColor: String

    // Placeholder
    public var placeholderText: String?

    // Cursor
    public var cursorColor: String

    // Default dark theme colors - WCAG AA compliant
    public init(
        primaryText: String = "#f9fafb",  // ~17:1 contrast ✓
        secondaryText: String = "#a1a1aa",  // ~8:1 contrast ✓ (was #9ca3af)
        tertiaryText: String = "#8b8b94",  // ~5.5:1 contrast ✓ (was #6b7280, ~3.5:1)
        primaryBackground: String = "#0f0f10",
        secondaryBackground: String = "#18181b",
        tertiaryBackground: String = "#27272a",
        sidebarBackground: String = "#141416",
        sidebarSelectedBackground: String = "#2a2a2e",
        accentColor: String = "#60a5fa",  // Higher contrast for links (was #3b82f6)
        accentColorLight: String = "#93c5fd",
        primaryBorder: String = "#3f3f46",  // Improved visibility (was #27272a)
        secondaryBorder: String = "#52525b",  // Improved visibility (was #3f3f46)
        focusBorder: String = "#60a5fa",  // Matches accentColor for consistency
        successColor: String = "#22c55e",  // Good contrast on dark ✓
        warningColor: String = "#fbbf24",  // Brighter for dark bg ✓ (was #f59e0b)
        errorColor: String = "#f87171",  // Brighter for dark bg ✓ (was #ef4444)
        infoColor: String = "#60a5fa",  // Brighter blue for dark bg (was #3b82f6)
        cardBackground: String = "#18181b",
        cardBorder: String = "#3f3f46",
        buttonBackground: String = "#18181b",
        buttonBorder: String = "#3f3f46",
        inputBackground: String = "#18181b",
        inputBorder: String = "#52525b",  // Improved visibility (was #3f3f46)
        glassTintOverlay: String = "#00000030",
        codeBlockBackground: String = "#00000059",
        shadowColor: String = "#000000",
        selectionColor: String = "#3b82f680",
        cursorColor: String = "#3b82f6",
        placeholderText: String? = "#a1a1aa"  // Matches secondaryText for better visibility
    ) {
        self.primaryText = primaryText
        self.secondaryText = secondaryText
        self.tertiaryText = tertiaryText
        self.primaryBackground = primaryBackground
        self.secondaryBackground = secondaryBackground
        self.tertiaryBackground = tertiaryBackground
        self.sidebarBackground = sidebarBackground
        self.sidebarSelectedBackground = sidebarSelectedBackground
        self.accentColor = accentColor
        self.accentColorLight = accentColorLight
        self.primaryBorder = primaryBorder
        self.secondaryBorder = secondaryBorder
        self.focusBorder = focusBorder
        self.successColor = successColor
        self.warningColor = warningColor
        self.errorColor = errorColor
        self.infoColor = infoColor
        self.cardBackground = cardBackground
        self.cardBorder = cardBorder
        self.buttonBackground = buttonBackground
        self.buttonBorder = buttonBorder
        self.inputBackground = inputBackground
        self.inputBorder = inputBorder
        self.glassTintOverlay = glassTintOverlay
        self.codeBlockBackground = codeBlockBackground
        self.shadowColor = shadowColor
        self.selectionColor = selectionColor
        self.cursorColor = cursorColor
        self.placeholderText = placeholderText
    }

    /// Create colors from dark theme defaults
    public static var darkDefaults: ThemeColors { ThemeColors() }

    /// Create colors from light theme defaults - WCAG AA compliant
    public static var lightDefaults: ThemeColors {
        ThemeColors(
            primaryText: "#1a1a1a",  // ~17:1 contrast ✓
            secondaryText: "#525252",  // ~7:1 contrast ✓ (was #6b7280, ~5:1)
            tertiaryText: "#6b6b6b",  // ~5.5:1 contrast ✓ (was #9ca3af, ~2.7:1)
            primaryBackground: "#ffffff",
            secondaryBackground: "#f9fafb",
            tertiaryBackground: "#f3f4f6",
            sidebarBackground: "#f5f5f7",
            sidebarSelectedBackground: "#e8e8ed",
            accentColor: "#1d4ed8",  // Darker blue for better contrast (was #2563eb)
            accentColorLight: "#3b82f6",
            primaryBorder: "#d1d5db",  // Improved visibility (was #e5e7eb)
            secondaryBorder: "#e5e7eb",  // Decorative (was #f3f4f6)
            focusBorder: "#2563eb",
            successColor: "#15803d",  // ~4.5:1 on white ✓ (was #10b981, ~2.5:1)
            warningColor: "#a16207",  // ~4.5:1 on white ✓ (was #f59e0b, ~2.1:1)
            errorColor: "#dc2626",  // ~4.5:1 on white ✓ (was #ef4444, ~3.1:1)
            infoColor: "#1d4ed8",  // ~7:1 on white ✓ (was #3b82f6, ~3.8:1)
            cardBackground: "#ffffff",
            cardBorder: "#d1d5db",  // Improved visibility
            buttonBackground: "#ffffff",
            buttonBorder: "#9ca3af",  // ~3:1 for UI ✓ (was #d1d5db, ~1.5:1)
            inputBackground: "#ffffff",
            inputBorder: "#9ca3af",  // ~3:1 for UI ✓ (was #d1d5db, ~1.5:1)
            glassTintOverlay: "#0000001f",
            codeBlockBackground: "#00000014",
            shadowColor: "#000000",
            selectionColor: "#2563eb50",
            cursorColor: "#2563eb",
            placeholderText: "#525252"  // Matches secondaryText for better visibility
        )
    }
}

// MARK: - System Accent Derivation

extension ThemeColors {
    /// Returns a copy with the accent-adjacent colors re-derived from
    /// `accentHex`. Everything else (backgrounds, text, status colors, …)
    /// is left untouched.
    ///
    /// When `accentHex` already matches the stored `accentColor` the
    /// receiver is returned unchanged, so themes hand-tuned against the
    /// default accent keep their exact authored values.
    public func applyingAccent(_ accentHex: String, isDark: Bool) -> ThemeColors {
        guard let accent = Self.parseHexRGB(accentHex),
            Self.normalizedHex(accentHex) != Self.normalizedHex(accentColor)
        else { return self }

        let accentString = Self.formatHexRGB(accent)
        let white: (Double, Double, Double) = (255, 255, 255)
        let black: (Double, Double, Double) = (0, 0, 0)

        var derived = self
        derived.accentColor = accentString
        derived.focusBorder = accentString
        derived.cursorColor = accentString
        derived.accentColorLight = Self.formatHexRGB(Self.blend(accent, toward: white, fraction: 0.4))
        // Keep the canonical selection alphas (see darkDefault/lightDefault).
        derived.selectionColor = accentString + (isDark ? "45" : "26")
        if isDark {
            // Factors tuned so the default blue accent lands close to the
            // hand-picked #0a3d70 / #d8e8ff selected-row colors.
            derived.sidebarSelectedBackground = Self.formatHexRGB(Self.blend(accent, toward: black, fraction: 0.55))
            derived.infoColor = derived.accentColorLight
        } else {
            derived.sidebarSelectedBackground = Self.formatHexRGB(Self.blend(accent, toward: white, fraction: 0.84))
            derived.infoColor = accentString
        }
        return derived
    }

    private static func normalizedHex(_ hex: String) -> String {
        let trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
    }

    private static func parseHexRGB(_ hex: String) -> (Double, Double, Double)? {
        let body = normalizedHex(hex)
        guard body.count == 6, body.allSatisfy(\.isHexDigit) else { return nil }
        var int: UInt64 = 0
        Scanner(string: body).scanHexInt64(&int)
        return (Double(int >> 16 & 0xFF), Double(int >> 8 & 0xFF), Double(int & 0xFF))
    }

    private static func formatHexRGB(_ rgb: (Double, Double, Double)) -> String {
        String(
            format: "#%02x%02x%02x",
            Int(rgb.0.rounded()),
            Int(rgb.1.rounded()),
            Int(rgb.2.rounded())
        )
    }

    private static func blend(
        _ from: (Double, Double, Double),
        toward target: (Double, Double, Double),
        fraction: Double
    ) -> (Double, Double, Double) {
        (
            from.0 + (target.0 - from.0) * fraction,
            from.1 + (target.1 - from.1) * fraction,
            from.2 + (target.2 - from.2) * fraction
        )
    }
}

