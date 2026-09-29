//
//  CustomTheme+Presets.swift
//  ApexKey
//
//  Built-in CustomTheme presets
//

import AppKit
import Foundation
import SwiftUI

// MARK: - Custom Theme

extension CustomTheme {
    /// Default dark theme — native macOS dark palette (issue #2102)
    public static var darkDefault: CustomTheme {
        CustomTheme(
            metadata: ThemeMetadata(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                name: "Dark",
                version: "2.0",
                author: "Osaurus"
            ),
            colors: ThemeColors(
                primaryText: "#f5f5f7",
                secondaryText: "#d1d1d6",
                tertiaryText: "#98989d",
                primaryBackground: "#1c1c1e",
                secondaryBackground: "#2c2c2e",
                tertiaryBackground: "#3a3a3c",
                sidebarBackground: "#252527",
                sidebarSelectedBackground: "#0a3d70",
                accentColor: "#0a84ff",
                accentColorLight: "#64d2ff",
                primaryBorder: "#38383a",
                secondaryBorder: "#48484a",
                focusBorder: "#0a84ff",
                successColor: "#30d158",
                warningColor: "#ff9f0a",
                errorColor: "#ff453a",
                infoColor: "#64d2ff",
                cardBackground: "#2c2c2e",
                cardBorder: "#48484a",
                buttonBackground: "#3a3a3c",
                buttonBorder: "#545458",
                inputBackground: "#2c2c2e",
                inputBorder: "#545458",
                glassTintOverlay: "#00000050",
                codeBlockBackground: "#1c1c1e",
                shadowColor: "#000000",
                selectionColor: "#0a84ff45",
                cursorColor: "#0a84ff",
                placeholderText: "#8e8e93"
            ),
            background: .default,
            glass: ThemeGlass(
                enabled: true,
                sidebarEnabled: true,
                inputEnabled: false,
                material: .windowBackground,
                blurRadius: 20,
                opacityPrimary: 0.82,
                opacitySecondary: 0.68,
                opacityTertiary: 0.5,
                tintColor: "#000000",
                tintOpacity: 0.12,
                edgeLight: "#ffffff30",
                windowBackingOpacity: 0.94
            ),
            typography: ThemeTypography(
                primaryFont: "SF Pro",
                monoFont: "SF Mono",
                titleSize: 26,
                headingSize: 18,
                bodySize: 15,
                captionSize: 12,
                codeSize: 13
            ),
            animationConfig: ThemeAnimation(
                durationQuick: 0.15,
                durationMedium: 0.25,
                durationSlow: 0.35,
                springResponse: 0.35,
                springDamping: 0.82
            ),
            shadows: ThemeShadows(
                shadowOpacity: 0.32,
                cardShadowRadius: 10,
                cardShadowRadiusHover: 18,
                cardShadowY: 3,
                cardShadowYHover: 7
            ),
            messages: ThemeMessages(
                bubbleCornerRadius: 18,
                userBubbleOpacity: 0.2,
                assistantBubbleOpacity: 0.95,
                borderWidth: 0.5,
                showEdgeLight: true,
                showInlineAvatar: true,
                inlineAvatarSize: 24,
                showAgentName: true,
                agentNameSize: 13
            ),
            borders: ThemeBorders(
                defaultWidth: 1,
                cardCornerRadius: 10,
                inputCornerRadius: 7,
                borderOpacity: 0.5
            ),
            isBuiltIn: true,
            isDark: true,
            followsSystemAccent: true
        )
    }

    /// Default light theme — native macOS light palette (issue #2102)
    public static var lightDefault: CustomTheme {
        CustomTheme(
            metadata: ThemeMetadata(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                name: "Light",
                version: "2.0",
                author: "Osaurus"
            ),
            colors: ThemeColors(
                primaryText: "#1d1d1f",
                secondaryText: "#515154",
                tertiaryText: "#6e6e73",
                primaryBackground: "#f5f5f7",
                secondaryBackground: "#ececf0",
                tertiaryBackground: "#f9f9fb",
                sidebarBackground: "#e9e9ed",
                sidebarSelectedBackground: "#d8e8ff",
                accentColor: "#007aff",
                accentColorLight: "#5ac8fa",
                primaryBorder: "#d1d1d6",
                secondaryBorder: "#c7c7cc",
                focusBorder: "#007aff",
                successColor: "#248a3d",
                warningColor: "#b26a00",
                errorColor: "#d70015",
                infoColor: "#007aff",
                cardBackground: "#ffffff",
                cardBorder: "#d1d1d6",
                buttonBackground: "#f6f6f7",
                buttonBorder: "#c7c7cc",
                inputBackground: "#ffffff",
                inputBorder: "#c7c7cc",
                glassTintOverlay: "#ffffff70",
                codeBlockBackground: "#f2f2f7",
                shadowColor: "#000000",
                selectionColor: "#007aff26",
                cursorColor: "#007aff",
                placeholderText: "#8e8e93"
            ),
            background: .default,
            glass: ThemeGlass(
                enabled: true,
                sidebarEnabled: true,
                inputEnabled: false,
                material: .windowBackground,
                blurRadius: 20,
                opacityPrimary: 0.78,
                opacitySecondary: 0.62,
                opacityTertiary: 0.45,
                tintColor: "#ffffff",
                tintOpacity: 0.08,
                edgeLight: "#ffffffcc",
                windowBackingOpacity: 0.92
            ),
            typography: ThemeTypography(
                primaryFont: "SF Pro",
                monoFont: "SF Mono",
                titleSize: 26,
                headingSize: 18,
                bodySize: 15,
                captionSize: 12,
                codeSize: 13
            ),
            animationConfig: ThemeAnimation(
                durationQuick: 0.15,
                durationMedium: 0.25,
                durationSlow: 0.35,
                springResponse: 0.35,
                springDamping: 0.82
            ),
            shadows: ThemeShadows(
                shadowOpacity: 0.12,
                cardShadowRadius: 8,
                cardShadowRadiusHover: 16,
                cardShadowY: 2,
                cardShadowYHover: 6
            ),
            messages: ThemeMessages(
                bubbleCornerRadius: 18,
                userBubbleOpacity: 0.16,
                assistantBubbleOpacity: 0.95,
                borderWidth: 0.5,
                showEdgeLight: true,
                showInlineAvatar: true,
                inlineAvatarSize: 24,
                showAgentName: true,
                agentNameSize: 13
            ),
            borders: ThemeBorders(
                defaultWidth: 1,
                cardCornerRadius: 10,
                inputCornerRadius: 7,
                borderOpacity: 0.45
            ),
            isBuiltIn: true,
            isDark: false,
            followsSystemAccent: true
        )
    }

    /// Osaurus Dark — the previous default dark palette, retained as a
    /// selectable built-in preset after the macOS-native defaults landed.
    public static var osaurusDarkPreset: CustomTheme {
        CustomTheme(
            metadata: ThemeMetadata(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000007")!,
                name: "Osaurus Dark",
                version: "1.1",
                author: "Osaurus"
            ),
            colors: ThemeColors(
                primaryText: "#ffffea",
                secondaryText: "#b8c4e8",
                tertiaryText: "#98a4d0",
                primaryBackground: "#0e1120",
                secondaryBackground: "#161a2c",
                tertiaryBackground: "#1e2238",
                sidebarBackground: "#0b0e1a",
                sidebarSelectedBackground: "#1c2035",
                accentColor: "#4a6de0",
                accentColorLight: "#7090f5",
                primaryBorder: "#2a3050",
                secondaryBorder: "#3a4260",
                focusBorder: "#4a6de0",
                successColor: "#68d735",
                warningColor: "#fbbf24",
                errorColor: "#ff5b32",
                infoColor: "#4a6de0",
                cardBackground: "#161a2c",
                cardBorder: "#2a3050",
                buttonBackground: "#1e2238",
                buttonBorder: "#3a4260",
                inputBackground: "#0e1120",
                inputBorder: "#3a4260",
                glassTintOverlay: "#0e112060",
                codeBlockBackground: "#0b0e1a",
                shadowColor: "#000000",
                selectionColor: "#4a6de040",
                cursorColor: "#ffffea",
                placeholderText: "#7888b8"
            ),
            background: .default,
            glass: ThemeGlass(
                enabled: false,
                material: .hudWindow,
                blurRadius: 30,
                opacityPrimary: 0.10,
                opacitySecondary: 0.08,
                opacityTertiary: 0.05,
                edgeLight: "#ffffff33",
                windowBackingOpacity: 0.55
            ),
            typography: .default,
            animationConfig: .default,
            shadows: ThemeShadows(
                shadowOpacity: 0.3,
                cardShadowRadius: 12,
                cardShadowRadiusHover: 20,
                cardShadowY: 4,
                cardShadowYHover: 8
            ),
            messages: ThemeMessages(
                bubbleCornerRadius: 20,
                userBubbleOpacity: 0.3,
                assistantBubbleOpacity: 0.85,
                borderWidth: 0.5,
                showEdgeLight: true
            ),
            borders: ThemeBorders(
                defaultWidth: 1,
                cardCornerRadius: 12,
                inputCornerRadius: 8,
                borderOpacity: 0.3
            ),
            isBuiltIn: true,
            isDark: true
        )
    }

    /// Osaurus Light — the previous default light palette, retained as a
    /// selectable built-in preset after the macOS-native defaults landed.
    public static var osaurusLightPreset: CustomTheme {
        CustomTheme(
            metadata: ThemeMetadata(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000008")!,
                name: "Osaurus Light",
                version: "1.1",
                author: "Osaurus"
            ),
            colors: ThemeColors(
                primaryText: "#181e38",
                secondaryText: "#3d4f7a",
                tertiaryText: "#5a6b99",
                primaryBackground: "#ffffea",
                secondaryBackground: "#f5f5d8",
                tertiaryBackground: "#ebebc8",
                sidebarBackground: "#f8f8e0",
                sidebarSelectedBackground: "#ebebce",
                accentColor: "#214099",
                accentColorLight: "#3a5ab8",
                primaryBorder: "#8890aa",
                secondaryBorder: "#b8bcd0",
                focusBorder: "#214099",
                successColor: "#2d6e10",
                warningColor: "#a16207",
                errorColor: "#d44010",
                infoColor: "#214099",
                cardBackground: "#ffffea",
                cardBorder: "#8890aa",
                buttonBackground: "#214099",
                buttonBorder: "#214099",
                inputBackground: "#ffffff",
                inputBorder: "#8890aa",
                glassTintOverlay: "#ffffea50",
                codeBlockBackground: "#f0f0d4",
                shadowColor: "#214099",
                selectionColor: "#21409940",
                cursorColor: "#214099",
                placeholderText: "#8890aa"
            ),
            background: .default,
            glass: ThemeGlass(
                enabled: false,
                material: .hudWindow,
                blurRadius: 20,
                opacityPrimary: 0.15,
                opacitySecondary: 0.10,
                opacityTertiary: 0.05,
                edgeLight: "#ffffff4d",
                windowBackingOpacity: 0.65
            ),
            typography: .default,
            animationConfig: .default,
            shadows: ThemeShadows(
                shadowOpacity: 0.05,
                cardShadowRadius: 8,
                cardShadowRadiusHover: 16,
                cardShadowY: 2,
                cardShadowYHover: 6
            ),
            messages: ThemeMessages(
                bubbleCornerRadius: 20,
                userBubbleOpacity: 0.25,
                assistantBubbleOpacity: 0.9,
                borderWidth: 0.5,
                showEdgeLight: true
            ),
            borders: ThemeBorders(
                defaultWidth: 1,
                cardCornerRadius: 12,
                inputCornerRadius: 8,
                borderOpacity: 0.25
            ),
            isBuiltIn: true,
            isDark: false
        )
    }

    /// Cyberpunk Neon theme - vibrant colors on dark background (WCAG AA compliant)
    public static var neonPreset: CustomTheme {
        CustomTheme(
            metadata: ThemeMetadata(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
                name: "Neon",
                author: "Osaurus"
            ),
            colors: ThemeColors(
                primaryText: "#f0f0f0",  // ~18:1 contrast ✓
                secondaryText: "#b0b0b0",  // ~9:1 contrast ✓ (was #a0a0a0)
                tertiaryText: "#909090",  // ~5.5:1 contrast ✓ (was #707070, ~3.2:1)
                primaryBackground: "#0a0a14",
                secondaryBackground: "#12121f",
                tertiaryBackground: "#1a1a2e",
                sidebarBackground: "#0e0e1a",
                sidebarSelectedBackground: "#1f1f35",
                accentColor: "#ff00ff",
                accentColorLight: "#ff66ff",
                primaryBorder: "#3a3a55",  // Improved visibility (was #2a2a40)
                secondaryBorder: "#4a4a65",  // Improved visibility (was #3a3a55)
                focusBorder: "#ff00ff",
                successColor: "#00ff88",  // High contrast on dark ✓
                warningColor: "#ffcc00",  // Brighter yellow ✓ (was #ffaa00)
                errorColor: "#ff6688",  // Brighter for visibility (was #ff3366)
                infoColor: "#00ddff",  // Brighter cyan (was #00ccff)
                cardBackground: "#12121f",
                cardBorder: "#3a3a55",  // Improved visibility
                buttonBackground: "#1a1a2e",
                buttonBorder: "#4a4a65",  // Improved visibility
                inputBackground: "#0e0e1a",
                inputBorder: "#3a3a55",  // Improved visibility (was #2a2a40)
                glassTintOverlay: "#ff00ff15",
                codeBlockBackground: "#00000050",
                shadowColor: "#ff00ff",
                selectionColor: "#ff00ff60",
                cursorColor: "#ff00ff"
            ),
            background: .default,
            glass: ThemeGlass(
                material: .hudWindow,
                blurRadius: 35,
                opacityPrimary: 0.12,
                opacitySecondary: 0.08,
                opacityTertiary: 0.04,
                tintColor: "#ff00ff",
                tintOpacity: 0.03,
                edgeLight: "#ff00ff40"
            ),
            typography: .default,
            animationConfig: ThemeAnimation(
                durationQuick: 0.15,
                durationMedium: 0.25,
                durationSlow: 0.35,
                springResponse: 0.35,
                springDamping: 0.75
            ),
            shadows: ThemeShadows(
                shadowOpacity: 0.4,
                cardShadowRadius: 16,
                cardShadowRadiusHover: 24,
                cardShadowY: 6,
                cardShadowYHover: 10
            ),
            messages: ThemeMessages(
                bubbleCornerRadius: 24,
                userBubbleOpacity: 0.4,
                assistantBubbleOpacity: 0.8,
                borderWidth: 0.5,
                showEdgeLight: true
            ),
            borders: ThemeBorders(
                defaultWidth: 1.0,
                cardCornerRadius: 16,
                inputCornerRadius: 10,
                borderOpacity: 0.35
            ),
            isBuiltIn: true,
            isDark: true
        )
    }

    /// Nord theme - Arctic, north-bluish color palette (WCAG AA compliant)
    public static var nordPreset: CustomTheme {
        CustomTheme(
            metadata: ThemeMetadata(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
                name: "Nord",
                author: "Osaurus"
            ),
            colors: ThemeColors(
                primaryText: "#eceff4",  // ~10:1 contrast ✓
                secondaryText: "#d8dee9",  // ~7:1 contrast ✓
                tertiaryText: "#b8c4d4",  // ~5:1 contrast ✓ (was #a3b1c2, ~4.2:1)
                primaryBackground: "#2e3440",
                secondaryBackground: "#3b4252",
                tertiaryBackground: "#434c5e",
                sidebarBackground: "#2e3440",
                sidebarSelectedBackground: "#434c5e",
                accentColor: "#88c0d0",  // Good contrast on Nord backgrounds
                accentColorLight: "#8fbcbb",
                primaryBorder: "#5c667a",  // Improved visibility (was #4c566a)
                secondaryBorder: "#4c566a",  // (was #434c5e)
                focusBorder: "#88c0d0",
                successColor: "#a3be8c",  // Good contrast ✓
                warningColor: "#ebcb8b",  // Good on dark ✓
                errorColor: "#d08770",  // Better contrast (was #bf616a)
                infoColor: "#88c0d0",  // Better visibility (was #81a1c1)
                cardBackground: "#3b4252",
                cardBorder: "#5c667a",  // Improved visibility
                buttonBackground: "#434c5e",
                buttonBorder: "#5c667a",  // Improved visibility
                inputBackground: "#3b4252",
                inputBorder: "#5c667a",  // Improved visibility (was #4c566a)
                glassTintOverlay: "#88c0d010",
                codeBlockBackground: "#2e344080",
                shadowColor: "#000000",
                selectionColor: "#88c0d060",
                cursorColor: "#88c0d0"
            ),
            background: .default,
            glass: ThemeGlass(
                material: .hudWindow,
                blurRadius: 25,
                opacityPrimary: 0.12,
                opacitySecondary: 0.08,
                opacityTertiary: 0.05,
                tintColor: "#88c0d0",
                tintOpacity: 0.02,
                edgeLight: "#eceff420"
            ),
            typography: .default,
            animationConfig: .default,
            shadows: ThemeShadows(
                shadowOpacity: 0.25,
                cardShadowRadius: 10,
                cardShadowRadiusHover: 18,
                cardShadowY: 3,
                cardShadowYHover: 7
            ),
            messages: ThemeMessages(
                bubbleCornerRadius: 18,
                userBubbleOpacity: 0.3,
                assistantBubbleOpacity: 0.85,
                borderWidth: 0.5,
                showEdgeLight: true
            ),
            borders: .default,
            isBuiltIn: true,
            isDark: true
        )
    }

    /// Paper theme - Warm, sepia-toned light theme (WCAG AA compliant)
    public static var paperPreset: CustomTheme {
        CustomTheme(
            metadata: ThemeMetadata(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
                name: "Paper",
                author: "Osaurus"
            ),
            colors: ThemeColors(
                primaryText: "#3d3d3d",  // ~9:1 contrast ✓
                secondaryText: "#555555",  // ~7:1 contrast ✓ (was #6b6b6b, ~5:1)
                tertiaryText: "#737373",  // ~5:1 contrast ✓ (was #9a9a9a, ~2.8:1)
                primaryBackground: "#faf8f5",
                secondaryBackground: "#f5f2ed",
                tertiaryBackground: "#ebe7e0",
                sidebarBackground: "#f0ece5",
                sidebarSelectedBackground: "#e5e0d8",
                accentColor: "#9a7b30",  // Darker gold ~4.5:1 ✓ (was #c9a959, ~2.5:1)
                accentColorLight: "#b8923f",
                primaryBorder: "#c5c0b8",  // Improved visibility (was #e0dcd5)
                secondaryBorder: "#d5d0c8",  // (was #ebe7e0)
                focusBorder: "#9a7b30",
                successColor: "#4d7c3a",  // ~4.5:1 on cream ✓ (was #7fb069, ~2.5:1)
                warningColor: "#9a6a1a",  // ~4.5:1 on cream ✓ (was #e6a23c, ~2.3:1)
                errorColor: "#b54545",  // ~4.5:1 on cream ✓ (was #d56060, ~3.2:1)
                infoColor: "#4a7899",  // ~4.5:1 on cream ✓ (was #6b9bc3, ~3:1)
                cardBackground: "#ffffff",
                cardBorder: "#c5c0b8",  // Improved visibility
                buttonBackground: "#f5f2ed",
                buttonBorder: "#a5a099",  // ~3:1 for UI ✓ (was #d5d0c8, ~1.6:1)
                inputBackground: "#ffffff",
                inputBorder: "#a5a099",  // ~3:1 for UI ✓ (was #d5d0c8, ~1.6:1)
                glassTintOverlay: "#9a7b3010",
                codeBlockBackground: "#f0ece520",
                shadowColor: "#8b7355",
                selectionColor: "#9a7b3050",
                cursorColor: "#9a7b30"
            ),
            background: .default,
            glass: ThemeGlass(
                enabled: false,
                material: .sheet,
                blurRadius: 18,
                opacityPrimary: 0.18,
                opacitySecondary: 0.12,
                opacityTertiary: 0.06,
                tintColor: "#c9a959",
                tintOpacity: 0.02,
                edgeLight: "#ffffff50"
            ),
            typography: ThemeTypography(
                primaryFont: "Georgia",
                monoFont: "Courier New",
                titleSize: 26,
                headingSize: 18,
                bodySize: 15,
                captionSize: 12,
                codeSize: 13
            ),
            animationConfig: ThemeAnimation(
                durationQuick: 0.25,
                durationMedium: 0.35,
                durationSlow: 0.5,
                springResponse: 0.45,
                springDamping: 0.85
            ),
            shadows: ThemeShadows(
                shadowOpacity: 0.08,
                cardShadowRadius: 6,
                cardShadowRadiusHover: 12,
                cardShadowY: 2,
                cardShadowYHover: 5
            ),
            messages: ThemeMessages(
                bubbleCornerRadius: 16,
                userBubbleOpacity: 0.2,
                assistantBubbleOpacity: 0.9,
                borderWidth: 0.5,
                showEdgeLight: false
            ),
            borders: ThemeBorders(
                defaultWidth: 1.0,
                cardCornerRadius: 10,
                inputCornerRadius: 6,
                borderOpacity: 0.2
            ),
            isBuiltIn: true,
            isDark: false
        )
    }

    /// Terminal theme - Classic CRT terminal aesthetic with phosphor green on black
    public static var terminalPreset: CustomTheme {
        CustomTheme(
            metadata: ThemeMetadata(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000006")!,
                name: "Terminal",
                author: "Osaurus"
            ),
            colors: ThemeColors(
                primaryText: "#00ff41",  // Classic phosphor green
                secondaryText: "#00cc33",  // Slightly dimmer green
                tertiaryText: "#00aa2a",  // Even dimmer for tertiary
                primaryBackground: "#0c0c0c",  // Rich black
                secondaryBackground: "#0f0f0f",  // Slightly lighter black
                tertiaryBackground: "#141414",  // Card/elevated surfaces
                sidebarBackground: "#0a0a0a",  // Deepest black for sidebar
                sidebarSelectedBackground: "#1a1a1a",  // Subtle highlight
                accentColor: "#00ff41",  // Phosphor green accent
                accentColorLight: "#33ff66",  // Brighter green for hover
                primaryBorder: "#1a3a1a",  // Dark green border
                secondaryBorder: "#0d1f0d",  // Subtle green border
                focusBorder: "#00ff41",  // Bright green focus
                successColor: "#00ff41",  // Green (matches theme)
                warningColor: "#ffb000",  // Amber (classic terminal warning)
                errorColor: "#ff3333",  // Red error
                infoColor: "#00cc33",  // Green info
                cardBackground: "#111111",  // Slightly elevated
                cardBorder: "#1a3a1a",  // Green-tinted border
                buttonBackground: "#0f0f0f",
                buttonBorder: "#00ff41",  // Green border for buttons
                inputBackground: "#0a0a0a",  // Deep black input
                inputBorder: "#1a3a1a",  // Green-tinted border
                glassTintOverlay: "#00ff4108",  // Subtle green tint
                codeBlockBackground: "#0a0a0a",  // Deep black for code
                shadowColor: "#00ff41",  // Green glow for shadows
                selectionColor: "#00ff4140",  // Green selection
                cursorColor: "#00ff41",  // Bright green cursor
                placeholderText: "#00aa2a"  // Dim green placeholder
            ),
            background: .default,
            glass: ThemeGlass(
                enabled: false,  // Solid backgrounds for authentic terminal look
                material: .hudWindow,
                blurRadius: 0,
                opacityPrimary: 0.0,
                opacitySecondary: 0.0,
                opacityTertiary: 0.0,
                tintColor: "#00ff41",
                tintOpacity: 0.02,
                edgeLight: "#00ff4120"  // Subtle green edge glow
            ),
            typography: ThemeTypography(
                primaryFont: "SF Mono",  // Monospace for all text
                monoFont: "SF Mono",
                titleSize: 24,
                headingSize: 16,
                bodySize: 14,
                captionSize: 12,
                codeSize: 14
            ),
            animationConfig: ThemeAnimation(
                durationQuick: 0.1,  // Snappy, instant feel
                durationMedium: 0.2,
                durationSlow: 0.3,
                springResponse: 0.3,
                springDamping: 0.9  // Minimal bounce
            ),
            shadows: ThemeShadows(
                shadowOpacity: 0.5,  // Stronger for glow effect
                cardShadowRadius: 12,  // Soft green glow
                cardShadowRadiusHover: 20,
                cardShadowY: 0,  // No vertical offset (glow, not drop shadow)
                cardShadowYHover: 0
            ),
            messages: ThemeMessages(
                bubbleCornerRadius: 4,
                userBubbleOpacity: 0.25,
                assistantBubbleOpacity: 0.7,
                borderWidth: 1.0,
                showEdgeLight: true
            ),
            borders: ThemeBorders(
                defaultWidth: 1.0,
                cardCornerRadius: 4,
                inputCornerRadius: 4,
                borderOpacity: 0.4
            ),
            isBuiltIn: true,
            isDark: true
        )
    }

    /// All built-in theme presets
    public static var allBuiltInPresets: [CustomTheme] {
        [
            .darkDefault, .lightDefault, .neonPreset, .nordPreset, .paperPreset, .terminalPreset,
            .osaurusDarkPreset, .osaurusLightPreset,
        ]
    }
}
