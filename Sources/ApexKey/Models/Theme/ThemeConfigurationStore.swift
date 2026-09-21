//
//  ThemeConfigurationStore.swift
//  ApexKey
//
//  Handles persistence of custom themes
//

import Foundation

/// Handles persistence of custom themes
@MainActor
public enum ThemeConfigurationStore {
    private static let activeThemeKey = "activeThemeId"
    private static let builtInThemeSchemaKey = "builtInThemeSchemaVersion"
    /// Increment whenever the built-in Dark/Light palette changes so existing
    /// installations receive updated colors on next launch.
    private static let currentBuiltInThemeSchema = 6
    private static var builtInThemesInstalled = false

    // MARK: - Active Theme

    static func loadActiveThemeId() -> UUID? {
        guard let string = UserDefaults.standard.string(forKey: activeThemeKey) else { return nil }
        return UUID(uuidString: string)
    }

    static func saveActiveThemeId(_ themeId: UUID?) {
        if let themeId = themeId {
            UserDefaults.standard.set(themeId.uuidString, forKey: activeThemeKey)
        } else {
            UserDefaults.standard.removeObject(forKey: activeThemeKey)
        }
    }

    static func loadActiveTheme() -> CustomTheme? {
        guard let themeId = loadActiveThemeId() else { return nil }
        return loadTheme(id: themeId)
    }

    // MARK: - Theme CRUD

    static func listThemes() -> [CustomTheme] {
        ensureThemesDirectoryAndBuiltIns()

        let themesDir = themesDirectoryURL()
        guard FileManager.default.fileExists(atPath: themesDir.path) else { return [] }

        do {
            let contents = try FileManager.default.contentsOfDirectory(at: themesDir, includingPropertiesForKeys: nil)
            return
                contents
                .filter { $0.pathExtension == "json" }
                .compactMap { url -> CustomTheme? in
                    do {
                        return try decodeTheme(from: url)
                    } catch {
                        handleCorruptedThemeFile(url)
                        return nil
                    }
                }
        } catch {
            return []
        }
    }

    /// Decode installed theme files without touching the install-cache guard.
    nonisolated static func listThemesFromDisk() -> [CustomTheme] {
        let themesDir = themesDirectoryURL()
        guard FileManager.default.fileExists(atPath: themesDir.path) else { return [] }

        do {
            let contents = try FileManager.default.contentsOfDirectory(at: themesDir, includingPropertiesForKeys: nil)
            return
                contents
                .filter { $0.pathExtension == "json" }
                .compactMap { url -> CustomTheme? in
                    try? decodeTheme(from: url)
                }
        } catch {
            return []
        }
    }

    static func loadTheme(id: UUID) -> CustomTheme? {
        let url = themeFileURL(for: id)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try? decodeTheme(from: url)
    }

    static func saveTheme(_ theme: CustomTheme) {
        do {
            try ensureExists(themesDirectoryURL())
            let normalizedTheme = normalizedForSave(theme)
            let data = try encodeTheme(normalizedTheme)
            try data.write(to: themeFileURL(for: normalizedTheme.metadata.id), options: .atomic)
        } catch {
            Logger.error("E-MAC-STORE-5001", "테마 저장 실패 '\(theme.metadata.name)': \(error.localizedDescription)")
        }
    }

    @discardableResult
    static func deleteTheme(id: UUID) -> Bool {
        // Don't allow deleting built-in themes
        if let theme = loadTheme(id: id), theme.isBuiltIn { return false }

        let url = themeFileURL(for: id)
        try? FileManager.default.removeItem(at: url)

        // Clear active reference if this was the active theme
        if loadActiveThemeId() == id {
            saveActiveThemeId(nil)
        }
        return true
    }

    // MARK: - Import/Export

    static func exportTheme(_ theme: CustomTheme, to url: URL) throws {
        let data = try encodeTheme(theme)
        try data.write(to: url, options: .atomic)
    }

    static func importTheme(from url: URL, libraryInfo: ThemeLibraryInfo? = nil) throws -> CustomTheme {
        let now = Date()
        var theme = try decodeTheme(from: url)
        theme.metadata.id = UUID()
        theme.metadata.createdAt = now
        theme.metadata.updatedAt = now
        theme.isBuiltIn = false
        theme.library =
            libraryInfo
            ?? ThemeLibraryInfo(
                source: .imported,
                importedAt: now,
                sourceDetail: url.lastPathComponent
            )
        saveTheme(theme)
        return theme
    }

    static func duplicateTheme(_ theme: CustomTheme, newName: String) -> CustomTheme {
        let now = Date()
        var newTheme = theme
        newTheme.metadata.id = UUID()
        newTheme.metadata.name = newName
        newTheme.metadata.createdAt = now
        newTheme.metadata.updatedAt = now
        newTheme.isBuiltIn = false
        newTheme.library = ThemeLibraryInfo(
            source: .local,
            sourceDetail: "Duplicated from \(theme.metadata.name)"
        )
        saveTheme(newTheme)
        return newTheme
    }

    @discardableResult
    static func markThemeShared(id: UUID, hash: String, serverURL: URL, sharedAt: Date = Date()) -> CustomTheme? {
        guard var theme = loadTheme(id: id), !theme.isBuiltIn else { return nil }

        var library = theme.library ?? ThemeLibraryInfo(source: .local)
        library.source = .shared
        library.sharedAt = sharedAt
        library.remoteHash = hash.lowercased()
        library.remoteURL = serverURL.absoluteString
        theme.library = library
        theme.metadata.updatedAt = sharedAt

        saveTheme(theme)
        return theme
    }

    @discardableResult
    static func rollbackActiveThemeToDefault() -> UUID? {
        let previous = loadActiveThemeId()
        saveActiveThemeId(nil)
        installBuiltInThemesIfNeeded()
        return previous
    }

    // MARK: - Built-in Themes

    static func installBuiltInThemesIfNeeded() {
        guard (try? ensureExists(themesDirectoryURL())) != nil else { return }

        let storedSchema = UserDefaults.standard.integer(forKey: builtInThemeSchemaKey)
        if storedSchema < currentBuiltInThemeSchema {
            // Schema bumped — force-reinstall so existing users get updated palettes
            for theme in CustomTheme.allBuiltInPresets {
                saveTheme(theme)
            }
            UserDefaults.standard.set(currentBuiltInThemeSchema, forKey: builtInThemeSchemaKey)
        } else {
            for theme in CustomTheme.allBuiltInPresets {
                let url = themeFileURL(for: theme.metadata.id)
                if !FileManager.default.fileExists(atPath: url.path) {
                    saveTheme(theme)
                }
            }
        }
        builtInThemesInstalled = true
    }

    static func forceReinstallBuiltInThemes() {
        guard (try? ensureExists(themesDirectoryURL())) != nil else { return }

        for theme in CustomTheme.allBuiltInPresets {
            saveTheme(theme)
        }
        builtInThemesInstalled = true
    }

    // MARK: - Private Helpers

    private static func ensureThemesDirectoryAndBuiltIns() {
        if !builtInThemesInstalled {
            installBuiltInThemesIfNeeded()
        }
    }

    private static func handleCorruptedThemeFile(_ url: URL) {
        let filename = url.deletingPathExtension().lastPathComponent
        guard let uuid = UUID(uuidString: filename) else {
            try? FileManager.default.removeItem(at: url)
            return
        }

        if let builtInTheme = CustomTheme.allBuiltInPresets.first(where: { $0.metadata.id == uuid }) {
            try? FileManager.default.removeItem(at: url)
            saveTheme(builtInTheme)
        } else {
            try? FileManager.default.removeItem(at: url)
        }
    }

    nonisolated private static func themesDirectoryURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return appSupport.appendingPathComponent("com.borasarang.ApexKey", isDirectory: true)
            .appendingPathComponent("themes", isDirectory: true)
    }

    private static func themeFileURL(for id: UUID) -> URL {
        themesDirectoryURL().appendingPathComponent("\(id.uuidString).json")
    }

    nonisolated private static func decodeTheme(from url: URL) throws -> CustomTheme {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(CustomTheme.self, from: data)
    }

    private static func encodeTheme(_ theme: CustomTheme) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(theme)
    }

    private static func normalizedForSave(_ theme: CustomTheme) -> CustomTheme {
        var normalized = theme
        if normalized.isBuiltIn {
            normalized.library = nil
        } else if normalized.library == nil {
            normalized.library = ThemeLibraryInfo(source: .local)
        }
        return normalized
    }

    private static func ensureExists(_ url: URL) throws {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        if !fm.fileExists(atPath: url.path, isDirectory: &isDir) {
            try fm.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
}
