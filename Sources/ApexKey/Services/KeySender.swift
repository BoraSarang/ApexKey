import AppKit
import ApplicationServices

/// 키/마우스 합성 이벤트 단일 출처 — CGEvent post 4경로 통합용.
/// 권한 가드는 여기서 한 번만 수행한다. 권한 없으면 조용히 post하지 않고 false 반환.
enum KeySender {
    /// 손쉬운 사용 권한 확인
    static func isTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    /// XCTest 실행 중에는 합성 이벤트를 절대 post하지 않는다.
    /// 개발 머신은 손쉬운 사용 권한이 있어 `isTrusted()`가 true라, 테스트가
    /// 실제 키 입력·클릭을 쏴서 포커스된 입력창에 글자가 찍힌다
    /// (예: 숫자 검증 테스트가 "1234.03.14..." 를 타이핑). 권한이 없을 때와
    /// 같은 값(false)을 돌려준다. 판정은 Logger.isTestRun과 같은 방식.
    static var suppressesPublish: Bool { NSClassFromString("XCTestCase") != nil }

    /// 단일 키 down/up 전송 (flags 포함)
    @discardableResult
    static func postKey(keyCode: CGKeyCode, flags: CGEventFlags = []) -> Bool {
        guard !suppressesPublish, isTrusted() else { return false }
        let source = CGEventSource(stateID: .hidSystemState)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            return false
        }
        down.flags = flags
        down.post(tap: .cghidEventTap)
        up.flags = flags
        up.post(tap: .cghidEventTap)
        return true
    }

    /// 수식키 실타 + 본키 전송 (Finder 등이 flags-only 이벤트를 무시하므로 필수)
    @discardableResult
    static func postCombo(keyCode: CGKeyCode, flags: CGEventFlags, modifierKeyCodes: [CGKeyCode]) -> Bool {
        guard !suppressesPublish, isTrusted() else { return false }
        let source = CGEventSource(stateID: .hidSystemState)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            return false
        }
        for code in modifierKeyCodes {
            CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: true)?.post(tap: .cghidEventTap)
        }
        down.flags = flags
        down.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.02)
        up.flags = flags
        up.post(tap: .cghidEventTap)
        for code in modifierKeyCodes.reversed() {
            CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: false)?.post(tap: .cghidEventTap)
        }
        return true
    }

    /// 좌표 클릭 전송
    @discardableResult
    static func click(at point: CGPoint) -> Bool {
        guard !suppressesPublish, isTrusted() else { return false }
        let source = CGEventSource(stateID: .hidSystemState)
        CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
        CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
        return true
    }
}
