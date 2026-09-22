//
//  ThemeGlass.swift
//  ApexKey
//
//  Theme glass / materials
//

import AppKit
import Foundation
import SwiftUI

// MARK: - Theme Glass

/// Glass effect configuration
public struct ThemeGlass: Codable, Equatable, Sendable {
    public enum GlassMaterial: String, Codable, Sendable {
        case titlebar
        case selection
        case menu
        case popover
        case sidebar
        case headerView
        case sheet
        case windowBackground
        case hudWindow
        case fullScreenUI
        case toolTip
        case contentBackground
        case underWindowBackground
        case underPageBackground

        public var nsMaterial: NSVisualEffectView.Material {
            switch self {
            case .titlebar: return .titlebar
            case .selection: return .selection
            case .menu: return .menu
            case .popover: return .popover
            case .sidebar: return .sidebar
            case .headerView: return .headerView
            case .sheet: return .sheet
            case .windowBackground: return .windowBackground
            case .hudWindow: return .hudWindow
            case .fullScreenUI: return .fullScreenUI
            case .toolTip: return .toolTip
            case .contentBackground: return .contentBackground
            case .underWindowBackground: return .underWindowBackground
            case .underPageBackground: return .underPageBackground
            }
        }
    }

    /// Whether glass effect is enabled for the chat area background.
    public var enabled: Bool
    /// Whether glass effect is enabled for the chat session sidebar.
    public var sidebarEnabled: Bool
    /// Whether glass effect is enabled for the prompt/input card.
    public var inputEnabled: Bool
    public var material: GlassMaterial
    public var blurRadius: Double
    public var opacityPrimary: Double
    public var opacitySecondary: Double
    public var opacityTertiary: Double
    public var tintColor: String?
    public var tintOpacity: Double?
    public var edgeLight: String
    public var edgeLightWidth: Double?
    public var windowBackingOpacity: Double

    public init(
        enabled: Bool = false,
        sidebarEnabled: Bool = false,
        inputEnabled: Bool = false,
        material: GlassMaterial = .hudWindow,
        blurRadius: Double = 30,
        opacityPrimary: Double = 0.10,
        opacitySecondary: Double = 0.08,
        opacityTertiary: Double = 0.05,
        tintColor: String? = nil,
        tintOpacity: Double? = nil,
        edgeLight: String = "#ffffff33",
        edgeLightWidth: Double? = nil,
        windowBackingOpacity: Double = 0.55
    ) {
        self.enabled = enabled
        self.sidebarEnabled = sidebarEnabled
        self.inputEnabled = inputEnabled
        self.material = material
        self.blurRadius = blurRadius
        self.opacityPrimary = opacityPrimary
        self.opacitySecondary = opacitySecondary
        self.opacityTertiary = opacityTertiary
        self.tintColor = tintColor
        self.tintOpacity = tintOpacity
        self.edgeLight = edgeLight
        self.edgeLightWidth = edgeLightWidth
        self.windowBackingOpacity = windowBackingOpacity
    }

    /// Dark theme glass defaults
    public static var darkDefaults: ThemeGlass { ThemeGlass() }

    /// Light theme glass defaults
    public static var lightDefaults: ThemeGlass {
        ThemeGlass(
            enabled: false,
            material: .hudWindow,
            blurRadius: 20,
            opacityPrimary: 0.15,
            opacitySecondary: 0.10,
            opacityTertiary: 0.05,
            edgeLight: "#ffffff4d",
            windowBackingOpacity: 0.65
        )
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decode(Bool.self, forKey: .enabled)
        sidebarEnabled = try container.decodeIfPresent(Bool.self, forKey: .sidebarEnabled) ?? false
        inputEnabled = try container.decodeIfPresent(Bool.self, forKey: .inputEnabled) ?? false
        material = try container.decode(GlassMaterial.self, forKey: .material)
        blurRadius = try container.decode(Double.self, forKey: .blurRadius)
        opacityPrimary = try container.decode(Double.self, forKey: .opacityPrimary)
        opacitySecondary = try container.decode(Double.self, forKey: .opacitySecondary)
        opacityTertiary = try container.decode(Double.self, forKey: .opacityTertiary)
        tintColor = try container.decodeIfPresent(String.self, forKey: .tintColor)
        tintOpacity = try container.decodeIfPresent(Double.self, forKey: .tintOpacity)
        edgeLight = try container.decode(String.self, forKey: .edgeLight)
        edgeLightWidth = try container.decodeIfPresent(Double.self, forKey: .edgeLightWidth)
        windowBackingOpacity = try container.decodeIfPresent(Double.self, forKey: .windowBackingOpacity) ?? 0.55
    }
}

