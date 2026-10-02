import AppKit
import Foundation

/// 클립보드 기록 항목 — 텍스트/이미지/파일 3종.
/// 이미지는 썸네일(≤160px)만 JSON 옆 파일로, 원본은 상한 내 별도 보관한다.
struct ClipboardEntry: Identifiable, Codable, Hashable {
    enum Kind: String, Codable {
        case text
        case image
        case file
    }

    var id: UUID
    var kind: Kind
    /// 텍스트 본문 (text) / 파일명 (file) / "" (image)
    var text: String
    /// 이미지 원본 바이트 수 (image만)
    var byteCount: Int
    /// 이미지 크기 "WxH" (image만)
    var dimensions: String
    /// 썸네일 PNG 파일명 (images/ 하위, image만)
    var thumbnailFile: String?
    /// 원본 이미지 PNG 파일명 (images/ 하위, 상한 내 보관 시)
    var fullFile: String?
    /// 파일 URL 문자열 (file만, 북마크 아님 — 샌드박스 밖 경로는 재접근 불가 가능)
    var fileURLString: String?
    var sourceApp: String
    var createdAt: Date
    var pinned: Bool

    init(
        id: UUID = UUID(),
        kind: Kind,
        text: String = "",
        byteCount: Int = 0,
        dimensions: String = "",
        thumbnailFile: String? = nil,
        fullFile: String? = nil,
        fileURLString: String? = nil,
        sourceApp: String = "",
        createdAt: Date = Date(),
        pinned: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.byteCount = byteCount
        self.dimensions = dimensions
        self.thumbnailFile = thumbnailFile
        self.fullFile = fullFile
        self.fileURLString = fileURLString
        self.sourceApp = sourceApp
        self.createdAt = createdAt
        self.pinned = pinned
    }
}

/// 클립보드 기록 저장소 — UserDefaults 오염 없이 Application Support 파일 영속.
/// 텍스트는 JSON 인라인, 이미지는 옆 `images/` 디렉터리 PNG로 분리 보관한다.
final class ClipboardHistory {
    static let maxItems = 100
    static let retentionDays = 30
    static let maxImageBytes = 5 * 1024 * 1024
    static let maxTotalBytes: Int64 = 200 * 1024 * 1024
    static let thumbnailMaxPixel: CGFloat = 160

    /// 기록 제외 앱 (비번 관리자 등) — 복사 출처가 여기면 저장하지 않는다.
    static let ignoredBundleIDs: Set<String> = [
        "com.apple.keychainaccess",
        "com.agilebits.onepassword7",
        "com.agilebits.onepassword8",
        "com.1password.1password",
        "com.lastpass.lastpass",
        "com.dashlane.dashlane",
        "com.bitwarden.desktop",
        "com.enpass.enpass",
    ]

    private let directory: URL
    private let imagesDirectory: URL
    private let indexURL: URL
    private let lock = NSLock()
    private var entries: [ClipboardEntry] = []

    /// - Parameter directory: 기록 루트. nil이면 Application Support/com.borasarang.ApexKey/Clipboard.
    init(directory: URL? = nil) {
        let dir = directory
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                .map { $0.appendingPathComponent("com.borasarang.ApexKey/Clipboard", isDirectory: true) }
            ?? FileManager.default.temporaryDirectory
        self.directory = dir
        self.imagesDirectory = dir.appendingPathComponent("images", isDirectory: true)
        self.indexURL = dir.appendingPathComponent("index.json")
        try? FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        load()
    }

    // MARK: - 조회

    func all() -> [ClipboardEntry] {
        lock.lock()
        defer { lock.unlock() }
        return entries
    }

    func pinned() -> [ClipboardEntry] {
        all().filter { $0.pinned }
    }

    func recents() -> [ClipboardEntry] {
        all().filter { !$0.pinned }
    }

    /// 텍스트/파일명/출처앱 검색 (초성 포함).
    func search(_ query: String) -> [ClipboardEntry] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return all() }
        return all().filter {
            PaletteMatch.matchesRanges(text: $0.text, query: q)
                || PaletteMatch.matchesRanges(text: $0.sourceApp, query: q)
        }
    }

    func thumbnail(for entry: ClipboardEntry) -> NSImage? {
        guard let name = entry.thumbnailFile else { return nil }
        return NSImage(contentsOf: imagesDirectory.appendingPathComponent(name))
    }

    func fullImage(for entry: ClipboardEntry) -> NSImage? {
        guard let name = entry.fullFile else { return nil }
        return NSImage(contentsOf: imagesDirectory.appendingPathComponent(name))
    }

    // MARK: - 기록

    @discardableResult
    func recordText(_ text: String, sourceApp: String) -> ClipboardEntry? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        lock.lock()
        // 연속 동일 텍스트 중복 방지
        if entries.first(where: { !$0.pinned })?.text == trimmed,
           entries.first(where: { !$0.pinned })?.kind == .text {
            lock.unlock()
            return nil
        }
        lock.unlock()
        let entry = ClipboardEntry(kind: .text, text: String(trimmed.prefix(4000)), sourceApp: sourceApp)
        insert(entry)
        return entry
    }

    @discardableResult
    func recordImage(_ image: NSImage, sourceApp: String) -> ClipboardEntry? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return nil }
        let w = Int(rep.pixelsWide)
        let h = Int(rep.pixelsHigh)
        let fileName = "\(UUID().uuidString).png"
        var fullName: String?
        // 상한 초과 원본은 썸네일만 보관
        if png.count <= Self.maxImageBytes {
            try? png.write(to: imagesDirectory.appendingPathComponent(fileName))
            fullName = fileName
        }
        let thumbName = "thumb-\(fileName)"
        if let thumb = Self.thumbnail(of: image),
           let tiff2 = thumb.tiffRepresentation,
           let rep2 = NSBitmapImageRep(data: tiff2),
           let png2 = rep2.representation(using: .png, properties: [:]) {
            try? png2.write(to: imagesDirectory.appendingPathComponent(thumbName))
        }
        let entry = ClipboardEntry(
            kind: .image,
            byteCount: png.count,
            dimensions: "\(w)×\(h)",
            thumbnailFile: thumbName,
            fullFile: fullName,
            sourceApp: sourceApp
        )
        insert(entry)
        return entry
    }

    @discardableResult
    func recordFile(url: URL, sourceApp: String) -> ClipboardEntry? {
        let entry = ClipboardEntry(
            kind: .file,
            text: url.lastPathComponent,
            fileURLString: url.absoluteString,
            sourceApp: sourceApp
        )
        insert(entry)
        return entry
    }

    // MARK: - 관리

    func setPinned(_ id: UUID, pinned: Bool) {
        lock.lock()
        if let i = entries.firstIndex(where: { $0.id == id }) {
            entries[i].pinned = pinned
        }
        lock.unlock()
        persist()
    }

    func remove(_ id: UUID) {
        lock.lock()
        if let i = entries.firstIndex(where: { $0.id == id }) {
            deleteFiles(for: entries[i])
            entries.remove(at: i)
        }
        lock.unlock()
        persist()
    }

    /// 지우기 — 고정 제외 전체 삭제 (고정은 유지).
    func clearUnpinned() {
        lock.lock()
        for e in entries where !e.pinned { deleteFiles(for: e) }
        entries.removeAll { !$0.pinned }
        lock.unlock()
        persist()
    }

    // MARK: - 내부

    private func insert(_ entry: ClipboardEntry) {
        lock.lock()
        entries.insert(entry, at: 0)
        // 고정 우선, 최신순 정렬 유지
        entries.sort {
            if $0.pinned != $1.pinned { return $0.pinned && !$1.pinned }
            return $0.createdAt > $1.createdAt
        }
        lock.unlock()
        enforceCaps()
        persist()
    }

    /// 상한 집행 — 개수/보관일/총용량. 고정 항목은 개수 상한에서 제외하지 않지만
    /// 보관일·용량 초과 시에는 고정도 삭제 대상 (무한 증가 방지).
    func enforceCaps(now: Date = Date()) {
        lock.lock()
        let cutoff = now.addingTimeInterval(TimeInterval(-Self.retentionDays * 24 * 3600))
        for e in entries where e.createdAt < cutoff { deleteFiles(for: e) }
        entries.removeAll { $0.createdAt < cutoff }
        if entries.count > Self.maxItems {
            for e in entries[Self.maxItems...] { deleteFiles(for: e) }
            entries = Array(entries.prefix(Self.maxItems))
        }
        lock.unlock()
        enforceTotalSize()
    }

    private func enforceTotalSize() {
        var total: Int64 = 0
        let fm = FileManager.default
        if let files = try? fm.contentsOfDirectory(at: imagesDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
            for f in files {
                total += Int64((try? f.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            }
        }
        guard total > Self.maxTotalBytes else { return }
        // 오래된(고정 제외 우선) 이미지부터 원본 삭제 → 썸네일만 남김
        lock.lock()
        let ordered = entries.indices.sorted { entries[$0].createdAt < entries[$1].createdAt }
        for i in ordered {
            if total <= Self.maxTotalBytes { break }
            guard let full = entries[i].fullFile else { continue }
            let url = imagesDirectory.appendingPathComponent(full)
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            try? fm.removeItem(at: url)
            entries[i].fullFile = nil
            total -= Int64(size)
        }
        lock.unlock()
        persist()
    }

    private func deleteFiles(for entry: ClipboardEntry) {
        let fm = FileManager.default
        for name in [entry.thumbnailFile, entry.fullFile].compactMap({ $0 }) {
            try? fm.removeItem(at: imagesDirectory.appendingPathComponent(name))
        }
    }

    private func persist() {
        lock.lock()
        let snapshot = entries
        lock.unlock()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(snapshot) {
            try? data.write(to: indexURL, options: .atomic)
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: indexURL),
              let decoded = try? JSONDecoder().decode([ClipboardEntry].self, from: data) else { return }
        entries = decoded
    }

    // MARK: - 붙여넣기

    /// 클립보드에만 되돌리기 (자동 붙여넣기 없음 — ⌥↩용).
    @discardableResult
    func copy(_ entry: ClipboardEntry) -> Bool {
        let pb = NSPasteboard.general
        ClipboardMonitor.shared.suppressNext = true
        pb.clearContents()
        switch entry.kind {
        case .text:
            return pb.setString(entry.text, forType: .string)
        case .image:
            guard let name = entry.fullFile ?? entry.thumbnailFile,
                  let data = try? Data(contentsOf: imagesDirectory.appendingPathComponent(name)) else { return false }
            return pb.setData(data, forType: .png)
        case .file:
            guard let s = entry.fileURLString, let url = URL(string: s) else { return false }
            return pb.writeObjects([url as NSURL])
        }
    }

    /// 항목을 클립보드에 되돌리고 ⌘V로 활성 앱에 붙여넣는다.
    /// 저장된 텍스트는 서식 없는 string이므로 ⌘V가 곧 서식 제거 붙여넣기다.
    @discardableResult
    func paste(_ entry: ClipboardEntry) -> Bool {
        guard KeySender.isTrusted() else {
            Logger.error("E-MAC-ACT-3007", "손쉬운 사용 권한 없음 — 클립보드 붙여넣기 불가")
            return false
        }
        guard copy(entry) else { return false }
        Thread.sleep(forTimeInterval: 0.05)
        return KeySender.postKey(keyCode: 9, flags: [.maskCommand])
    }

    // MARK: - 썸네일

    static func thumbnail(of image: NSImage) -> NSImage? {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let scale = min(1, thumbnailMaxPixel / max(size.width, size.height))
        let newSize = NSSize(width: size.width * scale, height: size.height * scale)
        let thumb = NSImage(size: newSize)
        thumb.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize))
        thumb.unlockFocus()
        return thumb
    }
}
