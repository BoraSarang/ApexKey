//
//  ThemeMetadata.swift
//  ApexKey
//
//  Theme metadata and library provenance
//

import AppKit
import Foundation
import SwiftUI

// MARK: - Theme Metadata

/// Metadata for a custom theme
public struct ThemeMetadata: Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var version: String
    public var author: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String = "Custom Theme",
        version: String = "1.0",
        author: String = "User",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.author = author
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        version = try container.decode(String.self, forKey: .version)
        author = try container.decode(String.self, forKey: .author)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}

// MARK: - Theme Library Metadata

/// Where a theme entered the local library. This is intentionally persisted
/// with custom themes so the library can distinguish hand-authored themes
/// from file imports and share-link installs after relaunch.
public enum ThemeLibrarySource: String, Codable, CaseIterable, Sendable {
    case builtIn
    case local
    case imported
    case shared
}

public struct ThemeLibraryInfo: Codable, Equatable, Sendable {
    public var source: ThemeLibrarySource
    public var importedAt: Date?
    public var sharedAt: Date?
    public var remoteHash: String?
    public var remoteURL: String?
    public var sourceDetail: String?

    public init(
        source: ThemeLibrarySource = .local,
        importedAt: Date? = nil,
        sharedAt: Date? = nil,
        remoteHash: String? = nil,
        remoteURL: String? = nil,
        sourceDetail: String? = nil
    ) {
        self.source = source
        self.importedAt = importedAt
        self.sharedAt = sharedAt
        self.remoteHash = remoteHash
        self.remoteURL = remoteURL
        self.sourceDetail = sourceDetail
    }
}

