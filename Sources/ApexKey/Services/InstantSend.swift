import AppKit
import Foundation

/// Instant Send — 전면 앱의 선택 내용을 단축키로 가로채 워크플로우 입력으로 전달.
/// Safari 등 AX 선택 텍스트가 불안정한 앱도 되도록 ⌘C 캡처 방식을 쓴다:
/// 저장 → ⌘C → 변화 대기 → 읽기 → 원복. 클립보드는 pasteboardItems 왕복으로 복원한다.
enum InstantSend {
    struct Payload: Hashable {
        /// 전달 텍스트 (파일 선택이면 경로들을 줄바꿈으로 합친 것)
        var text: String
        var sourceApp: String
    }

    /// 선택 캡처. 없으면 nil (토스트 안내용).
    /// - Note: 실제 키 전송·클립보드를 건드리므로 단위 테스트 불가, Safari 실동작으로 검증한다.
    static func capture() -> Payload? {
        guard KeySender.isTrusted() else {
            Logger.error("E-MAC-ACT-3007", "손쉬운 사용 권한 없음 — Instant Send 불가")
            return nil
        }
        let pb = NSPasteboard.general
        // 원본 보관 — NSPasteboardItem은 NSCopying이 없어 타입별 Data로 저장한다.
        var savedData: [(NSPasteboard.PasteboardType, Data)] = []
        for type in pb.types ?? [] {
            if let d = pb.data(forType: type) {
                savedData.append((type, d))
            }
        }
        let before = pb.changeCount
        ClipboardMonitor.shared.suppressNext = true
        // ⌘C 전송
        guard KeySender.postKey(keyCode: 8, flags: [.maskCommand]) else { return nil }
        // 변화 대기 (최대 0.6초)
        let deadline = Date().addingTimeInterval(0.6)
        while pb.changeCount == before, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        defer {
            // 클립보드 원복 (다음 폴링 1회 제외)
            ClipboardMonitor.shared.suppressNext = true
            pb.clearContents()
            for (type, data) in savedData {
                pb.setData(data, forType: type)
            }
        }
        let sourceApp = NSWorkspace.shared.frontmostApplication?.localizedName
            ?? NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            ?? ""
        if let text = pb.string(forType: .string),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return Payload(text: text, sourceApp: sourceApp)
        }
        if let urls = pb.readObjects(forClasses: [NSURL.self]) as? [URL], !urls.isEmpty {
            let paths = urls.map { $0.path }.joined(separator: "\n")
            if !paths.isEmpty {
                return Payload(text: paths, sourceApp: sourceApp)
            }
        }
        return nil
    }
}
