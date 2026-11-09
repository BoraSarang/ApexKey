import Foundation
import AppKit

/// 사용자에게 묻는 액션 (T-211) — 대화상자 · 확인
///
/// **테스트 가능성**: 버튼을 누르는 부분(`runner`)을 주입할 수 있다. 기본값은
/// 실제 `NSAlert.runModal()`이지만 테스트는 "확인을 눌렀다"고 응답하는 클로저를
/// 넣어 UI 없이 결과를 검증한다. 실행 엔진은 백그라운드 직렬 큐에서 돌기 때문에
/// 모달은 반드시 메인 스레드에서 띄운다.
enum UserPromptActions {

    /// NSAlert를 띄우고 응답을 돌려주는 함수
    typealias Runner = (NSAlert) -> NSApplication.ModalResponse

    /// 텍스트 입력 대화상자.
    ///
    /// - Returns: 입력한 문자열. 취소하면 빈 문자열 (실패가 아니다 — 사용자의 선택)
    static func dialog(
        message: String,
        defaultText: String?,
        runner: @escaping Runner = { $0.runModal() }
    ) -> String {
        let alert = makeAlert(message: message)
        alert.addButton(withTitle: "ui.common.ok".localized)
        alert.addButton(withTitle: "ui.common.cancel".localized)

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.stringValue = defaultText ?? ""
        field.placeholderString = "ui.next_action.default_text".localized
        alert.accessoryView = field

        let response = runOnMain { runner(alert) }
        guard response == .alertFirstButtonReturn else { return "" }
        return field.stringValue
    }

    /// 확인/취소 대화상자.
    ///
    /// - Returns: 확인이면 `true`, 취소면 `false`. 취소를 실패로 만들지 않는다 —
    ///   다음 단계에서 If로 분기할 수 있게 결과를 남긴다.
    static func confirmation(
        message: String,
        runner: @escaping Runner = { $0.runModal() }
    ) -> Bool {
        let alert = makeAlert(message: message)
        alert.addButton(withTitle: "ui.common.ok".localized)
        alert.addButton(withTitle: "ui.common.cancel".localized)
        let response = runOnMain { runner(alert) }
        return response == .alertFirstButtonReturn
    }

    // MARK: - 내부

    private static func makeAlert(message: String) -> NSAlert {
        let alert = NSAlert()
        alert.alertStyle = .informational
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        alert.messageText = trimmed.isEmpty
            ? "action.dialog".localized
            : trimmed
        return alert
    }

    /// 모달은 메인 스레드에서만 안전하다
    private static func runOnMain<T>(_ block: @escaping () -> T) -> T {
        if Thread.isMainThread { return block() }
        return DispatchQueue.main.sync(execute: block)
    }
}
