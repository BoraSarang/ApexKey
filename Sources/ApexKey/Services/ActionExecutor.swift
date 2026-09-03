import Foundation
import AppKit
import ApplicationServices

/// HotKeyBinding을 실제 액션으로 실행하는 디스패처
final class ActionExecutor {
    static let shared = ActionExecutor()

    private let menuEnumerator = MenuEnumerator.shared

    /// binding 실행. 성공 여부를 반환 (메뉴 명령 등 성공 판별 가능한 경우 유효)
    @discardableResult
    func execute(_ binding: HotKeyBinding) -> Bool {
        Logger.info("ActionExecutor", "실행 시작: \(binding.actionType.displayName) (target=\(binding.target), title=\(binding.title))")
        switch binding.actionType {
        case .launchApp:
            AppSwitcher.toggle(bundleID: binding.target)
            return true
        case .menuCommand:
            let item = MenuItem(title: binding.title, menuPath: binding.menuPath)
            let result = menuEnumerator.performAction(item, in: binding.target)
            if result.isSuccess {
                Logger.info("ActionExecutor", "메뉴 명령 성공: \(binding.title) (\(binding.target))")
            } else {
                Logger.error("E-MAC-MENU-3002", "메뉴 명령 실패: \(result.description) — \(binding.title) (\(binding.target))")
            }
            return result.isSuccess
        case .url:
            if let url = URL(string: binding.target) {
                NSWorkspace.shared.open(url)
                Logger.info("ActionExecutor", "URL 열기: \(url.absoluteString)")
            } else {
                Logger.error("E-MAC-MENU-3003", "잘못된 URL target: \(binding.target)")
            }
            return true
        case .file:
            let url = URL(fileURLWithPath: binding.target)
            NSWorkspace.shared.open(url)
            Logger.info("ActionExecutor", "파일 열기: \(url.path)")
            return true
        case .script:
            runScript(binding.target)
            return true
        case .system:
            if let type = SystemActionType(rawValue: binding.target) {
                let ok = SystemActionExecutor.execute(type)
                Logger.info("ActionExecutor", "시스템 액션 \(ok ? "성공" : "실패"): \(type.displayName)")
                return ok
            } else {
                Logger.error("E-MAC-SYS-8003", "알 수 없는 시스템 액션: \(binding.target)")
                return false
            }
        case .paste:
            runPaste(binding.target)
            return true
        case .wait:
            runWait(binding.target)
            return true
        case .coordinateClick:
            runCoordinateClick(binding.target)
            return true
        case .pauseUntilInput:
            runPauseUntilInput()
            return true
        case .macro:
            runMacro(binding.target)
            return true
        }
    }

    /// onlyWhenAppActive 옵션 판별 — 대상 앱이 활성 상태일 때만 실행
    func shouldExecute(_ binding: HotKeyBinding, frontmostBundleID: String?) -> Bool {
        guard binding.onlyWhenAppActive else { return true }
        return binding.target == frontmostBundleID
    }

    /// 단축어(동작) 실행 — 단계를 순서대로 재생
    @discardableResult
    func execute(_ shortcut: ShortcutItem) -> Bool {
        Logger.info("ActionExecutor", "동작 실행 시작: \(shortcut.name) (\(shortcut.steps.count)단계)")
        for (index, step) in shortcut.steps.enumerated() {
            let binding = step.toBinding()
            Logger.info("ActionExecutor", "동작 \(shortcut.name) — 단계 \(index + 1)/\(shortcut.steps.count): \(step.type.displayName)")
            execute(binding)
        }
        Logger.info("ActionExecutor", "동작 실행 완료: \(shortcut.name)")
        return true
    }

    private func runScript(_ command: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-c", command]
        do {
            try task.run()
        } catch {
            Logger.error("E-MAC-SCRIPT-6001", "스크립트 실행 실패: \(error.localizedDescription)")
        }
    }

    // MARK: - 붙여넣기

    private func runPaste(_ target: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        let text: String
        if target == "clipboard" {
            text = pasteboard.string(forType: .string) ?? ""
        } else {
            text = target
        }

        guard !text.isEmpty else {
            Logger.info("ActionExecutor", "붙여넣기 건너뜀: 빈 텍스트")
            return
        }

        pasteboard.setString(text, forType: .string)
        simulateKeyCombo(keyCode: 9, modifiers: [.maskCommand])
        Logger.info("ActionExecutor", "붙여넣기 실행: \(text.count)자")
    }

    // MARK: - 대기

    private func runWait(_ target: String) {
        let seconds = Double(target) ?? 1.0
        Logger.info("ActionExecutor", "대기 시작: \(seconds)초")
        Thread.sleep(forTimeInterval: max(0, seconds))
        Logger.info("ActionExecutor", "대기 완료")
    }

    // MARK: - 좌표 클릭

    private func runCoordinateClick(_ target: String) {
        let components = target.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard components.count == 2,
              let x = Double(components[0]),
              let y = Double(components[1]) else {
            Logger.error("E-MAC-ACT-3004", "잘못된 좌표 형식: \(target) — 'x,y' 형식이어야 합니다")
            return
        }

        let point = CGPoint(x: x, y: y)
        simulateMouseClick(at: point)
        Logger.info("ActionExecutor", "좌표 클릭: (\(x), \(y))")
    }

    // MARK: - 사이보그 모드 (입력 대기)

    private func runPauseUntilInput() {
        Logger.info("ActionExecutor", "사이보그 모드 시작 — ⌘⇧↩로 계속")

        var monitorRef: Any?
        monitorRef = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let combo = KeyboardUtil.combo(from: event)
            if combo.keyCode == 36
                && combo.modifiers & KeyboardUtil.cmdMask != 0
                && combo.modifiers & KeyboardUtil.shiftMask != 0 {
                if let monitor = monitorRef {
                    NSEvent.removeMonitor(monitor)
                }
                monitorRef = nil
                Logger.info("ActionExecutor", "사이보그 모드: 입력 감지 — 계속")
                return nil
            }
            return event
        }
    }

    // MARK: - 매크로

    private func runMacro(_ target: String) {
        let keyCodes = target.components(separatedBy: ",").compactMap { UInt32($0.trimmingCharacters(in: .whitespaces)) }
        guard !keyCodes.isEmpty else { return }
        Logger.info("ActionExecutor", "매크로 실행: \(keyCodes.count)개 키")
        for keyCode in keyCodes {
            simulateKeyCode(keyCode)
            Thread.sleep(forTimeInterval: 0.06)
        }
    }

    private func simulateKeyCode(_ keyCode: UInt32) {
        let cgKeyCode = CGKeyCode(keyCode)
        let source = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: cgKeyCode, keyDown: true)
        down?.post(tap: .cghidEventTap)
        let up = CGEvent(keyboardEventSource: source, virtualKey: cgKeyCode, keyDown: false)
        up?.post(tap: .cghidEventTap)
    }

    // MARK: - CGEvent 헬퍼

    private func simulateKeyCombo(keyCode: CGKeyCode, modifiers: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        down?.flags = modifiers
        down?.post(tap: .cghidEventTap)
        let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        up?.flags = modifiers
        up?.post(tap: .cghidEventTap)
    }

    private func simulateMouseClick(at point: CGPoint) {
        let source = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
        down?.post(tap: .cghidEventTap)
        let up = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
        up?.post(tap: .cghidEventTap)
    }
}