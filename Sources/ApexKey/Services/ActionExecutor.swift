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
            return runShellScript(binding.target)
        case .runScriptInShell:
            return runShellScript(binding.target)
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
        default:
            Logger.error("E-MAC-ACT-3005", "미구현 액션 타입: \(binding.actionType.rawValue)")
            return false
        }
    }

    /// onlyWhenAppActive 옵션 판별 — 대상 앱이 활성 상태일 때만 실행
    func shouldExecute(_ binding: HotKeyBinding, frontmostBundleID: String?) -> Bool {
        guard binding.onlyWhenAppActive else { return true }
        return binding.target == frontmostBundleID
    }

    /// 단축어(동작) 실행 — 단계를 순서대로 재생 (흐름 제어 포함)
    @discardableResult
    func execute(_ shortcut: ShortcutItem) -> Bool {
        Logger.info("ActionExecutor", "동작 실행 시작: \(shortcut.name) (\(shortcut.steps.count)단계)")
        var context = UseModelExecutor.ExecutionContext()
        // 사용자 정의 변수의 기본값을 실행 컨텍스트에 주입
        for variable in shortcut.variables where variable.type == .manual {
            if let defaultValue = variable.defaultValue {
                context.variables[variable.id] = defaultValue
            }
        }
        return ExecutionEngine.shared.execute(shortcut, context: &context).success
    }

    /// 셸 스크립트 실행 결과 (테스트 실행 UI 표시용)
    struct ShellResult {
        var success: Bool
        var output: String
        var errorOutput: String
        var exitCode: Int32
    }

    /// 셸 스크립트 실행 — GUI 앱의 최소 PATH를 보완하고 결과를 로그에 남김.
    /// adb 등 Homebrew/Android SDK 도구를 찾을 수 있도록 PATH를 확장한다.
    @discardableResult
    func runShellScript(_ command: String) -> Bool {
        runShellScriptResult(command).success
    }

    /// 셸 스크립트 실행 + 결과(출력/종료코드) 반환 — 스크립트 설정의 테스트 실행 표시용
    func runShellScriptResult(_ command: String) -> ShellResult {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            Logger.error("E-MAC-SCRIPT-6002", "빈 스크립트 — 실행 건너뜀")
            return ShellResult(success: false, output: "", errorOutput: "error.user.empty_script".localized, exitCode: -1)
        }
        Logger.info("FEATURE", "셸 스크립트 실행 시작: \(trimmed.prefix(120))")
        let fullCommand = ShellEnvironment.script(trimmed)
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-c", fullCommand]
        let outPipe = Pipe()
        let errPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = errPipe
        do {
            try task.run()
        } catch {
            Logger.error("E-MAC-SCRIPT-6001", "스크립트 실행 실패: \(error.localizedDescription)")
            return ShellResult(success: false, output: "", errorOutput: error.localizedDescription, exitCode: -1)
        }
        task.waitUntilExit()
        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        let output = (String(data: outData, encoding: .utf8) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let errorOutput = (String(data: errData, encoding: .utf8) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let code = task.terminationStatus
        if !output.isEmpty {
            Logger.info("ActionExecutor", "스크립트 출력:\n\(output.prefix(2000))")
        }
        if code == 0 {
            Logger.info("FEATURE", "셸 스크립트 실행 성공 (exit 0)")
            return ShellResult(success: true, output: output, errorOutput: errorOutput, exitCode: code)
        } else {
            let detail = errorOutput.isEmpty ? output : errorOutput
            Logger.error("E-MAC-SCRIPT-6001", "스크립트 실패 (exit \(code)): \(detail.prefix(500))")
            return ShellResult(success: false, output: output, errorOutput: errorOutput, exitCode: code)
        }
    }

    // MARK: - 붙여넣기

    private func runPaste(_ target: String) {
        let pasteboard = NSPasteboard.general

        let text: String
        if target == "clipboard" {
            // 클립보드 내용을 활성 앱으로 붙여넣기 — clear 전에 먼저 읽어야 함
            text = pasteboard.string(forType: .string) ?? ""
        } else {
            text = target
        }

        guard !text.isEmpty else {
            Logger.info("ActionExecutor", "붙여넣기 건너뜀: 빈 텍스트")
            return
        }

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        simulateKeyCombo(keyCode: 9, modifiers: [.maskCommand])
        Logger.info("ActionExecutor", "붙여넣기 실행: \(text.count)자")
    }

    // MARK: - 대기

    private func runWait(_ target: String) {
        let seconds = max(0, Double(target) ?? 1.0)
        if Thread.isMainThread {
            Logger.error("E-MAC-ACT-3006", "메인 스레드 동기 대기 — UI가 \(seconds)초 멈춤 (동작 실행은 백그라운드 권장)")
        }
        Logger.info("ActionExecutor", "대기 시작: \(seconds)초")
        // 순차 의미 보장: 호출 스레드에서 동기 sleep (R-02)
        Thread.sleep(forTimeInterval: seconds)
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
        // 호출 스레드를 블로킹하는데 모니터는 메인 런루프에 등록되므로,
        // 메인에서 호출하면 교착. 그 경우 백그라운드로 넘긴다 (R-03)
        if Thread.isMainThread {
            Logger.info("ActionExecutor", "경고: 메인 스레드 입력 대기 — 백그라운드로 전환")
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.blockingPauseUntilInput()
            }
            return
        }
        blockingPauseUntilInput()
    }

    private func blockingPauseUntilInput() {
        Logger.info("ActionExecutor", "사이보그 모드 시작 — ⌘⇧↩로 계속")

        let semaphore = DispatchSemaphore(value: 0)

        // 로컬 모니터는 메인 런루프에서만 이벤트를 수신하므로 메인 스레드에 등록
        DispatchQueue.main.async {
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
                    Logger.info("ActionExecutor", "사이보그 모드: 입력 감지 — 계속")
                    semaphore.signal()
                    return nil
                }
                return event
            }
        }

        // 호출 스레드 블로킹 (백그라운드) — 메인 런루프는 자유로워 이벤트 수신 가능
        semaphore.wait()
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