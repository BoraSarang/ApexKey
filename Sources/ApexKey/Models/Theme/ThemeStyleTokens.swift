//
//  ThemeStyleTokens.swift
//  ApexKey
//
//  Typography, animation, shadows, messages, borders, input style
//

import AppKit
import Foundation
import SwiftUI

// MARK: - Theme Typography

/// Typography configuration
public struct ThemeTypography: Codable, Equatable, Sendable {
    public var primaryFont: String
    public var monoFont: String
    public var titleSize: Double
    public var headingSize: Double
    public var bodySize: Double
    public var captionSize: Double
    public var codeSize: Double

    public init(
        primaryFont: String = "SF Pro",
        monoFont: String = "SF Mono",
        titleSize: Double = 28,
        headingSize: Double = 18,
        bodySize: Double = 14,
        captionSize: Double = 12,
        codeSize: Double = 13
    ) {
        self.primaryFont = primaryFont
        self.monoFont = monoFont
        self.titleSize = titleSize
        self.headingSize = headingSize
        self.bodySize = bodySize
        self.captionSize = captionSize
        self.codeSize = codeSize
    }

    public static var `default`: ThemeTypography { ThemeTypography() }
}

// MARK: - Theme Animation

/// Animation timing configuration
public struct ThemeAnimation: Codable, Equatable, Sendable {
    public var durationQuick: Double
    public var durationMedium: Double
    public var durationSlow: Double
    public var springResponse: Double
    public var springDamping: Double

    public init(
        durationQuick: Double = 0.2,
        durationMedium: Double = 0.3,
        durationSlow: Double = 0.4,
        springResponse: Double = 0.4,
        springDamping: Double = 0.8
    ) {
        self.durationQuick = durationQuick
        self.durationMedium = durationMedium
        self.durationSlow = durationSlow
        self.springResponse = springResponse
        self.springDamping = springDamping
    }

    public static var `default`: ThemeAnimation { ThemeAnimation() }

    /// SwiftUI Animation from spring config
    public var spring: Animation {
        .spring(response: springResponse, dampingFraction: springDamping)
    }
}

// MARK: - Theme Shadows

/// Shadow configuration
public struct ThemeShadows: Codable, Equatable, Sendable {
    public var shadowOpacity: Double
    public var cardShadowRadius: Double
    public var cardShadowRadiusHover: Double
    public var cardShadowY: Double
    public var cardShadowYHover: Double

    public init(
        shadowOpacity: Double = 0.3,
        cardShadowRadius: Double = 12,
        cardShadowRadiusHover: Double = 20,
        cardShadowY: Double = 4,
        cardShadowYHover: Double = 8
    ) {
        self.shadowOpacity = shadowOpacity
        self.cardShadowRadius = cardShadowRadius
        self.cardShadowRadiusHover = cardShadowRadiusHover
        self.cardShadowY = cardShadowY
        self.cardShadowYHover = cardShadowYHover
    }

    /// Dark theme shadow defaults
    public static var darkDefaults: ThemeShadows { ThemeShadows() }

    /// Light theme shadow defaults
    public static var lightDefaults: ThemeShadows {
        ThemeShadows(
            shadowOpacity: 0.05,
            cardShadowRadius: 8,
            cardShadowRadiusHover: 16,
            cardShadowY: 2,
            cardShadowYHover: 6
        )
    }
}

// MARK: - Theme Messages

/// Message bubble customization
public struct ThemeMessages: Codable, Equatable, Sendable {
    /// Corner radius for message bubbles
    public var bubbleCornerRadius: Double
    /// Opacity for user message bubble background
    public var userBubbleOpacity: Double
    /// Opacity for assistant message bubble background
    public var assistantBubbleOpacity: Double
    /// Override color for user bubbles (nil = use accentColor)
    public var userBubbleColor: String?
    /// Override color for assistant bubbles (nil = use secondaryBackground)
    public var assistantBubbleColor: String?
    /// Border width for message bubbles
    public var borderWidth: Double
    /// Whether to show edge light effect on bubbles
    public var showEdgeLight: Bool
    /// Whether the agent avatar is shown inline next to assistant messages.
    /// When false, the inline header drops the avatar and the name slides
    /// flush left.
    public var showInlineAvatar: Bool
    /// Diameter (in points) of the inline avatar shown beside assistant
    /// messages. Clamped at consumption time to a sensible range.
    public var inlineAvatarSize: Double
    /// Whether the agent's display name is shown next to the avatar.
    /// When false, only the avatar identifies the assistant in the header.
    public var showAgentName: Bool
    /// Font size (in points) of the agent's display name in the header.
    public var agentNameSize: Double

    public init(
        bubbleCornerRadius: Double = 20,
        userBubbleOpacity: Double = 0.3,
        assistantBubbleOpacity: Double = 0.85,
        userBubbleColor: String? = nil,
        assistantBubbleColor: String? = nil,
        borderWidth: Double = 0.5,
        showEdgeLight: Bool = true,
        showInlineAvatar: Bool = true,
        inlineAvatarSize: Double = 24,
        showAgentName: Bool = true,
        agentNameSize: Double = 13
    ) {
        self.bubbleCornerRadius = bubbleCornerRadius
        self.userBubbleOpacity = userBubbleOpacity
        self.assistantBubbleOpacity = assistantBubbleOpacity
        self.userBubbleColor = userBubbleColor
        self.assistantBubbleColor = assistantBubbleColor
        self.borderWidth = borderWidth
        self.showEdgeLight = showEdgeLight
        self.showInlineAvatar = showInlineAvatar
        self.inlineAvatarSize = inlineAvatarSize
        self.showAgentName = showAgentName
        self.agentNameSize = agentNameSize
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bubbleCornerRadius = try c.decodeIfPresent(Double.self, forKey: .bubbleCornerRadius) ?? 20
        userBubbleOpacity = try c.decodeIfPresent(Double.self, forKey: .userBubbleOpacity) ?? 0.3
        assistantBubbleOpacity = try c.decodeIfPresent(Double.self, forKey: .assistantBubbleOpacity) ?? 0.85
        userBubbleColor = try c.decodeIfPresent(String.self, forKey: .userBubbleColor)
        assistantBubbleColor = try c.decodeIfPresent(String.self, forKey: .assistantBubbleColor)
        borderWidth = try c.decodeIfPresent(Double.self, forKey: .borderWidth) ?? 0.5
        showEdgeLight = try c.decodeIfPresent(Bool.self, forKey: .showEdgeLight) ?? true
        showInlineAvatar = try c.decodeIfPresent(Bool.self, forKey: .showInlineAvatar) ?? true
        inlineAvatarSize = try c.decodeIfPresent(Double.self, forKey: .inlineAvatarSize) ?? 24
        showAgentName = try c.decodeIfPresent(Bool.self, forKey: .showAgentName) ?? true
        agentNameSize = try c.decodeIfPresent(Double.self, forKey: .agentNameSize) ?? 13
    }

    public static var `default`: ThemeMessages { ThemeMessages() }
}

// MARK: - Theme Borders

/// Border and corner radius customization
public struct ThemeBorders: Codable, Equatable, Sendable {
    /// Default border width for UI elements
    public var defaultWidth: Double
    /// Corner radius for card-style elements
    public var cardCornerRadius: Double
    /// Corner radius for input fields
    public var inputCornerRadius: Double
    /// Default border opacity applied to border colors
    public var borderOpacity: Double

    public init(
        defaultWidth: Double = 1.0,
        cardCornerRadius: Double = 12,
        inputCornerRadius: Double = 8,
        borderOpacity: Double = 0.3
    ) {
        self.defaultWidth = defaultWidth
        self.cardCornerRadius = cardCornerRadius
        self.inputCornerRadius = inputCornerRadius
        self.borderOpacity = borderOpacity
    }

    public static var `default`: ThemeBorders { ThemeBorders() }
}

public enum ThemeInputStyle: String, Codable, Sendable { case gradient, shadow }

