import AppKit
import Foundation

/// 클립보드 변경 감시 — changeCount 폴링 (0.5초).
/// 기록은 ClipboardHistory가, 붙여넣기는 호출부가 담당한다.
final class ClipboardMonitor {
    static let shared = ClipboardMonitor(history: ClipboardHistory())

    let history: ClipboardHistory
    /// 우리가 직접 쓴 클립보드는 다음 폴링 1회 건너뜀 (자기 기록 방지).
    var suppressNext = false

    private var timer: Timer?
    private var lastChangeCount: Int = NSPasteboard.general.changeCount

    init(history: ClipboardHistory) {
        self.history = history
    }

    func start() {
        stop()
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.poll()
        }
        Logger.info("ClipboardMonitor", "감시 시작")
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// 즉시 1회 폴링 — 팔레트가 열릴 때 방금 복사한 항목을 놓치지 않기 위해.
    func refresh() {
        poll()
    }

    private func poll() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount
        if suppressNext {
            suppressNext = false
            return
        }
        let sourceApp = NSWorkspace.shared.frontmostApplication?.localizedName
            ?? NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            ?? ""
        let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
        if ClipboardHistory.ignoredBundleIDs.contains(bundleID) { return }
        // 파일URL 우선 (Finder 복사) → 이미지 → 텍스트 순으로 판정
        if let urls = pb.readObjects(forClasses: [NSURL.self]) as? [URL],
           let first = urls.first, first.isFileURL {
            history.recordFile(url: first, sourceApp: sourceApp)
            return
        }
        if let data = pb.data(forType: .tiff) ?? pb.data(forType: .png),
           let image = NSImage(data: data) {
            history.recordImage(image, sourceApp: sourceApp)
            return
        }
        if let text = pb.string(forType: .string) {
            history.recordText(text, sourceApp: sourceApp)
        }
    }
}
