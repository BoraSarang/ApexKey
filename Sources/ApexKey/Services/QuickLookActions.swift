import Foundation
import AppKit
import QuickLookUI

/// Quick Look 미리보기 (T-211)
///
/// 파일이 없으면 패널을 띄우지 않고 실패를 돌려준다. 테스트 실행 중에는
/// 패널을 열지 않는다 — 검증은 파일 존재 확인까지만 한다.
final class QuickLookActions: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    static let shared = QuickLookActions()

    enum FailureReason: Equatable, Error {
        case emptyPath
        case fileMissing
        case panelUnavailable

        var messageKey: String {
            switch self {
            case .emptyPath: return "error.user.next_path_empty"
            case .fileMissing: return "toast.reason.file_missing"
            case .panelUnavailable: return "error.user.next_quicklook_failed"
            }
        }
    }

    private var previewURL: URL?

    private override init() {
        super.init()
    }

    /// 파일을 Quick Look으로 연다
    @discardableResult
    func preview(path: String) -> Result<Void, FailureReason> {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.emptyPath) }

        let expanded = (trimmed as NSString).expandingTildeInPath
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: expanded, isDirectory: &isDirectory),
              !isDirectory.boolValue else {
            return .failure(.fileMissing)
        }

        // XCTest 중에는 패널을 열지 않는다 (포커스 탈취 방지)
        if KeySender.suppressesPublish { return .success(()) }

        previewURL = URL(fileURLWithPath: expanded)
        var opened = true
        DispatchQueue.main.sync {
            guard let panel = QLPreviewPanel.shared() else {
                opened = false
                return
            }
            panel.dataSource = self
            panel.delegate = self
            panel.makeKeyAndOrderFront(nil)
        }
        return opened ? .success(()) : .failure(.panelUnavailable)
    }

    // MARK: - QLPreviewPanelDataSource

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        previewURL == nil ? 0 : 1
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        previewURL as NSURL?
    }
}
