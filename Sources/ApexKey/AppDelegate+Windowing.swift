//
//  AppDelegate+Windowing.swift
//  ApexKey
//
//  KeyCapablePanel / ToastPanel subclasses
//

import AppKit

/// 보더리스 플로팅 패널이 키 포커스(ESC 등)를 받도록 key가 될 수 있게 하는 서브클래스
final class KeyCapablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    /// Esc 후킹 — 포커스 받을 컨트롤이 없는 창(아이콘 그리드 등)은
    /// SwiftUI onKeyPress가 발동하지 않아 Esc가 먹지 않는다.
    /// nil이면 super 동작(아무 일 없음). SwiftUI가 먼저 처리하면
    /// 이벤트가 소비되어 여기로 오지 않으므로 중복 발동 없다.
    var onEscape: (() -> Void)?
    override func cancelOperation(_ sender: Any?) {
        if let onEscape {
            onEscape()
        } else {
            super.cancelOperation(sender)
        }
    }
}

/// 실행 결과 토스트 전용 — 클릭은 받되 key/main이 되지 않아 전면 앱 포커스를 유지한다
final class ToastPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
