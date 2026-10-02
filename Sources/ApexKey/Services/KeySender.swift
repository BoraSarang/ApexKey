import AppKit
import ApplicationServices

/// 키/마우스 합성 이벤트 단일 출처 — CGEvent post 4경로 통합용.
/// 권한 가드는 여기서 한 번만 수행한다. 권한 없으면 조용히 post하지 않고 false 반환.
enum KeySender {
    /// 손쉬운 사용 권한 확인
    static func isTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    /// 단일 키 down/up 전송 (flags 포함)
    @discardableResult
    static func postKey(keyCode: CGKeyCode, flags: CGEventFlags = []) -> Bool {
        guard isTrusted() else { return false }
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
        guard isTrusted() else { return false }
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
        guard isTrusted() else { return false }
        let source = CGEventSource(stateID: .hidSystemState)
        CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
        CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
        return true
    }
}
