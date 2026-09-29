import AppKit
import SwiftUI

// MARK: - Appearance Mode

public enum AppearanceMode: String, Codable, CaseIterable, Sendable {
    case system = "system"
    case light = "light"
    case dark = "dark"
}
