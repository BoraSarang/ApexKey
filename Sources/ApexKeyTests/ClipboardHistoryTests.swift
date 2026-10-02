import AppKit
import XCTest
@testable import ApexKey

/// 클립보드 기록 저장소 단위 테스트 — 실제 클립보드는 건드리지 않음
final class ClipboardHistoryTests: XCTestCase {
    private func tempDir() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("clip-\(UUID().uuidString)", isDirectory: true)
    }

    func testRecordTextDedupesConsecutiveDuplicate() {
        let h = ClipboardHistory(directory: tempDir())
        XCTAssertNotNil(h.recordText("hello", sourceApp: "Safari"))
        XCTAssertNil(h.recordText("  hello  ", sourceApp: "Safari"))
        XCTAssertEqual(h.all().count, 1)
    }

    func testRecordTextEmptyIgnored() {
        let h = ClipboardHistory(directory: tempDir())
        XCTAssertNil(h.recordText("   ", sourceApp: "X"))
        XCTAssertTrue(h.all().isEmpty)
    }

    func testPinRemoveClear() {
        let h = ClipboardHistory(directory: tempDir())
        let a = h.recordText("a", sourceApp: "S")!
        h.recordText("b", sourceApp: "S")
        h.setPinned(a.id, pinned: true)
        XCTAssertEqual(h.pinned().map(\.id), [a.id])
        h.clearUnpinned()
        XCTAssertEqual(h.all().map(\.id), [a.id])
        h.remove(a.id)
        XCTAssertTrue(h.all().isEmpty)
    }

    func testCapsEnforceCountAndRetention() {
        let dir = tempDir()
        let h = ClipboardHistory(directory: dir)
        for i in 0..<(ClipboardHistory.maxItems + 10) {
            h.recordText("item \(i)", sourceApp: "S")
        }
        XCTAssertEqual(h.all().count, ClipboardHistory.maxItems)
        // 보관일(30일) 초과 항목은 로드 후 enforceCaps로 제거된다
        let old = ClipboardEntry(kind: .text, text: "old", sourceApp: "S",
                                 createdAt: Date().addingTimeInterval(-40 * 24 * 3600))
        let fresh = ClipboardEntry(kind: .text, text: "new", sourceApp: "S", createdAt: Date())
        let data = try! JSONEncoder().encode([old, fresh])
        try! FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try! data.write(to: dir.appendingPathComponent("index.json"), options: .atomic)
        let h2 = ClipboardHistory(directory: dir)
        h2.enforceCaps()
        XCTAssertEqual(h2.all().map(\.text), ["new"])
    }

    func testSearchMatchesTextAndSource() {
        let h = ClipboardHistory(directory: tempDir())
        h.recordText("회의록 정리", sourceApp: "Slack")
        h.recordText("hello world", sourceApp: "Safari")
        XCTAssertEqual(h.search("회의").count, 1)
        XCTAssertEqual(h.search("safari").count, 1)
        XCTAssertEqual(h.search("ㅎㅇ").count, 1)
    }

    func testImageRecordAndThumbnail() {
        let h = ClipboardHistory(directory: tempDir())
        let img = NSImage(size: NSSize(width: 400, height: 200))
        img.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: 400, height: 200).fill()
        img.unlockFocus()
        let entry = h.recordImage(img, sourceApp: "Preview")
        XCTAssertNotNil(entry)
        // Retina backing store라 픽셀은 환경 배율에 따름 — 형식만 검증
        XCTAssertTrue(entry?.dimensions.contains("×") ?? false)
        XCTAssertTrue((entry?.byteCount ?? 0) > 0)
        XCTAssertNotNil(h.thumbnail(for: entry!))
        XCTAssertNotNil(h.fullImage(for: entry!))
    }

    func testPersistenceRoundTrip() {
        let dir = tempDir()
        let h = ClipboardHistory(directory: dir)
        h.recordText("persist me", sourceApp: "S")
        let h2 = ClipboardHistory(directory: dir)
        XCTAssertEqual(h2.all().map(\.text), ["persist me"])
    }
}
