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
            return executeLaunch(target: binding.target, title: binding.title)
        case .keyCombo:
            if let press = Self.parseKeyPress(from: binding.target) {
                return Self.sendKeyPress(press)
            }
            Logger.error("E-MAC-ACT-3004", "잘못된 키 조합 형식: \(binding.target) — 'keyCode:modifiers' 형식이어야 합니다")
            return false
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
            guard let url = URL(string: binding.target), url.scheme != nil else {
                Logger.error("E-MAC-MENU-3003", "잘못된 URL target: \(binding.target)")
                return false
            }
            NSWorkspace.shared.open(url)
            Logger.info("ActionExecutor", "URL 열기: \(url.absoluteString)")
            return true
        case .file:
            let trimmed = binding.target.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                Logger.error("E-MAC-ACT-3008", "파일 경로 미지정 — 실행 건너뜀")
                return false
            }
            guard FileManager.default.fileExists(atPath: trimmed) else {
                Logger.error("E-MAC-ACT-3008", "파일 없음: \(trimmed)")
                return false
            }
            let url = URL(fileURLWithPath: trimmed)
            NSWorkspace.shared.open(url)
            Logger.info("ActionExecutor", "파일 열기: \(url.path)")
            return true
        case .script:
            return runShellScript(binding.target)
        case .runScriptInShell:
            return runShellScript(binding.target)
        case .appleScript:
            let r = ScriptExecutor.runAppleScript(binding.target)
            return r.success
        case .javaScriptForAutomation:
            let r = ScriptExecutor.runJXA(binding.target)
            return r.success
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
        executeWithDetail(shortcut).success
    }

    /// 단축어 실행 + 사용자용 결과 메시지. 토스트 표시용.
    func executeWithDetail(_ shortcut: ShortcutItem) -> (success: Bool, message: String?) {
        Logger.info("ActionExecutor", "동작 실행 시작: \(shortcut.name) (\(shortcut.steps.count)단계)")
        var context = UseModelExecutor.ExecutionContext()
        // 사용자 정의 변수의 기본값을 실행 컨텍스트에 주입
        for variable in shortcut.variables where variable.type == .manual {
            if let defaultValue = variable.defaultValue {
                context.variables[variable.id] = defaultValue
            }
        }
        let result = ExecutionEngine.shared.execute(shortcut, context: &context)
        if result.success {
            return (true, nil)
        }
        return (false, result.error ?? "error.user.action_failed_fmt".localizedFormat(shortcut.name))
    }

    /// binding 실행 + 사용자용 결과 메시지. 토스트 표시용.
    /// 성공 시 message는 nil, 실패 시 사유를 반환한다.
    func executeWithDetail(_ binding: HotKeyBinding) -> (success: Bool, message: String?) {
        switch binding.actionType {
        case .launchApp:
            if Self.decodeLaunchConfig(from: binding.target) != nil {
                let ok = executeLaunch(target: binding.target, title: binding.title)
                return (ok, ok ? nil : "toast.reason.launch_failed".localized)
            }
            let trimmed = binding.target.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                Logger.error("E-MAC-APP-4001", "앱 미지정 — 번들ID 또는 경로 필요")
                return (false, "toast.reason.app_missing".localized)
            }
            if trimmed.contains("://"), URL(string: trimmed) == nil {
                return (false, "toast.reason.scheme_invalid".localized)
            }
            let ok = executeLaunch(target: binding.target, title: binding.title)
            return (ok, ok ? nil : "toast.reason.launch_failed".localized)
        case .keyCombo:
            guard let press = Self.parseKeyPress(from: binding.target) else {
                Logger.error("E-MAC-ACT-3004", "잘못된 키 조합 형식: \(binding.target)")
                return (false, "toast.reason.key_invalid".localized)
            }
            let ok = Self.sendKeyPress(press)
            return (ok, ok ? nil : "toast.reason.key_send_failed".localized)
        case .menuCommand:
            let item = MenuItem(title: binding.title, menuPath: binding.menuPath)
            let result = menuEnumerator.performAction(item, in: binding.target)
            return (result.isSuccess, result.isSuccess ? nil : result.description)
        case .url:
            guard let url = URL(string: binding.target), url.scheme != nil else {
                return (false, "toast.reason.url_invalid".localized)
            }
            NSWorkspace.shared.open(url)
            return (true, nil)
        case .file:
            let trimmed = binding.target.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, FileManager.default.fileExists(atPath: trimmed) else {
                return (false, "toast.reason.file_missing".localized)
            }
            NSWorkspace.shared.open(URL(fileURLWithPath: trimmed))
            return (true, nil)
        case .script, .runScriptInShell:
            let r = runShellScriptResult(binding.target)
            if r.success { return (true, nil) }
            let detail = r.errorOutput.isEmpty ? r.output : r.errorOutput
            return (false, detail.isEmpty
                ? "ui.step_settings.exit_code".localizedFormat(Int(r.exitCode))
                : String(detail.prefix(160)))
        case .appleScript:
            let r = ScriptExecutor.runAppleScript(binding.target)
            if r.success { return (true, nil) }
            return (false, r.errorOutput.isEmpty
                ? "error.user.script_failed".localized
                : String(r.errorOutput.prefix(160)))
        case .javaScriptForAutomation:
            let r = ScriptExecutor.runJXA(binding.target)
            if r.success { return (true, nil) }
            return (false, r.errorOutput.isEmpty
                ? "error.user.script_failed".localized
                : String(r.errorOutput.prefix(160)))
        case .system:
            guard let type = SystemActionType(rawValue: binding.target) else {
                return (false, "toast.reason.unimplemented".localized)
            }
            let ok = SystemActionExecutor.execute(type)
            return (ok, ok ? nil : "error.user.action_failed_fmt".localizedFormat(type.displayName))
        case .paste:
            runPaste(binding.target)
            return (true, nil)
        case .wait:
            runWait(binding.target)
            return (true, nil)
        case .coordinateClick:
            runCoordinateClick(binding.target)
            return (true, nil)
        case .pauseUntilInput:
            runPauseUntilInput()
            return (true, nil)
        case .macro:
            runMacro(binding.target)
            return (true, nil)
        default:
            Logger.error("E-MAC-ACT-3005", "미구현 액션 타입: \(binding.actionType.rawValue)")
            return (false, "toast.reason.unimplemented".localized)
        }
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

    /// 스크립트 파일 실행 + 결과 반환 — 외부 .sh 단일 소스용.
    /// 파일의 shebang(bash 배열 등)을 존중하기 위해 /bin/bash로 직접 실행한다.
    /// 파일이 없으면 E-MAC-SCRIPT-6003 실패 반환.
    func runScriptFileResult(_ path: String) -> ShellResult {
        guard FileManager.default.fileExists(atPath: path) else {
            Logger.error("E-MAC-SCRIPT-6003", "스크립트 파일 없음: \(path)")
            return ShellResult(success: false, output: "", errorOutput: "error.user.script_file_missing".localized, exitCode: -1)
        }
        Logger.info("FEATURE", "스크립트 파일 실행 시작: \(path)")
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = [path]
        // GUI 앱 최소 PATH 보완 (자식 프로세스 환경) — ShellEnvironment 단일 출처
        var env = ProcessInfo.processInfo.environment
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let extra = ShellEnvironment.extraPaths(home: home)
        env["PATH"] = "\(extra):\(env["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin")"
        task.environment = env
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
            Logger.info("FEATURE", "스크립트 파일 실행 성공 (exit 0)")
            return ShellResult(success: true, output: output, errorOutput: errorOutput, exitCode: code)
        } else {
            let detail = errorOutput.isEmpty ? output : errorOutput
            Logger.error("E-MAC-SCRIPT-6001", "스크립트 실패 (exit \(code)): \(detail.prefix(500))")
            return ShellResult(success: false, output: output, errorOutput: errorOutput, exitCode: code)
        }
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

    // MARK: - 앱 실행/토글 (LaunchConfig JSON 우선, 레거시 bundleID 폴백)

    /// binding.target 해석: `json:{LaunchConfig}` 이면 구조화 실행, 아니면 레거시 bundleID 토글.
    @discardableResult
    func executeLaunch(target: String, title: String = "") -> Bool {
        if let config = Self.decodeLaunchConfig(from: target) {
            let ok = AppSwitcher.execute(config: config)
            Logger.info("ActionExecutor", "앱 실행 \(ok ? "성공" : "실패"): \(config.displayName.isEmpty ? title : config.displayName) [\(config.mode.rawValue)]")
            return ok
        }
        let bundleID = target.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !bundleID.isEmpty else {
            Logger.error("E-MAC-APP-4001", "앱 미지정 — 번들ID 또는 경로 필요")
            return false
        }
        // URL 스킴 직접 입력 지원 (레거시 target에 스킴이 들어온 경우)
        if bundleID.contains("://") {
            guard let url = URL(string: bundleID) else {
                Logger.error("E-MAC-APP-4002", "잘못된 URL 스킴: \(bundleID)")
                return false
            }
            NSWorkspace.shared.open(url)
            Logger.info("ActionExecutor", "URL 스킴 실행: \(bundleID)")
            return true
        }
        // 토글 결과를 그대로 반환 — 없는 앱이면 false (성공 둔갑 금지)
        return AppSwitcher.toggle(bundleID: bundleID)
    }

    /// LaunchConfig JSON 디코딩 (`json:` 접두사)
    static func decodeLaunchConfig(from target: String) -> LaunchConfig? {
        guard target.hasPrefix("json:") else { return nil }
        let json = String(target.dropFirst("json:".count))
        guard let data = json.data(using: .utf8) else {
            Logger.error("E-MAC-APP-4003", "LaunchConfig UTF-8 변환 실패")
            return nil
        }
        do {
            return try JSONDecoder().decode(LaunchConfig.self, from: data)
        } catch {
            Logger.error("E-MAC-APP-4003", "LaunchConfig 디코딩 실패: \(error.localizedDescription)")
            return nil
        }
    }

    /// LaunchConfig → binding.target 인코딩
    static func encodeLaunchConfig(_ config: LaunchConfig) -> String {
        do {
            let data = try JSONEncoder().encode(config)
            guard let json = String(data: data, encoding: .utf8) else {
                Logger.error("E-MAC-APP-4003", "LaunchConfig 인코딩 문자열 변환 실패 — bundleID 폴백")
                return config.bundleID
            }
            return "json:" + json
        } catch {
            Logger.error("E-MAC-APP-4003", "LaunchConfig 인코딩 실패: \(error.localizedDescription) — bundleID 폴백")
            return config.bundleID
        }
    }

    // MARK: - 키 조합 보내기 (keyCombo)

    /// target 형식 "keyCode:modifiers" (Carbon 값, 예: ⌥⌘L = "37:2304") 파싱.
    static func parseKeyPress(from target: String) -> HotKeyCombo? {
        let parts = target.components(separatedBy: ":").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2,
              let keyCode = UInt32(parts[0]),
              let modifiers = UInt32(parts[1]) else { return nil }
        let combo = HotKeyCombo(
            keyCode: keyCode,
            modifiers: modifiers,
            displayString: KeyboardUtil.displayString(keyCode: keyCode, modifiers: modifiers)
        )
        return combo.isEmpty ? nil : combo
    }

    /// 키 조합 인코딩 (binding.target 저장용).
    static func encodeKeyPress(_ combo: HotKeyCombo) -> String {
        "\(combo.keyCode):\(combo.modifiers)"
    }

    /// 키 조합 전송 — 수식키 keyDown → 문자 down/up → 수식키 keyUp 순서로 실전송.
    /// 문자 키에만 flags를 세워 보내면 Finder 등 대부분 앱이 무시하므로 수식키 실타가 필수.
    /// 손쉬운 사용 권한이 없으면 전송이 무응답이라 false 반환.
    @discardableResult
    static func sendKeyPress(_ combo: HotKeyCombo) -> Bool {
        guard !combo.isEmpty else {
            Logger.error("E-MAC-ACT-3004", "빈 키 조합 — 전송 건너뜀")
            return false
        }
        guard AXIsProcessTrusted() else {
            Logger.error("E-MAC-ACT-3007", "손쉬운 사용 권한 없음 — 키 전송 불가. 시스템 설정 > 개인 정보 보호 및 보안 > 손쉬운 사용에서 ApexKey 허용 필요")
            return false
        }
        // Carbon 수식키 → 실제 키 코드 (kVK_Command/Shift/Option/Control)
        var modifierKeyCodes: [CGKeyCode] = []
        var flags = CGEventFlags()
        if combo.modifiers & KeyboardUtil.cmdMask != 0 { modifierKeyCodes.append(55); flags.insert(.maskCommand) }
        if combo.modifiers & KeyboardUtil.shiftMask != 0 { modifierKeyCodes.append(56); flags.insert(.maskShift) }
        if combo.modifiers & KeyboardUtil.optionMask != 0 { modifierKeyCodes.append(58); flags.insert(.maskAlternate) }
        if combo.modifiers & KeyboardUtil.controlMask != 0 { modifierKeyCodes.append(59); flags.insert(.maskControl) }
        let source = CGEventSource(stateID: .hidSystemState)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(combo.keyCode), keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(combo.keyCode), keyDown: false) else {
            Logger.error("E-MAC-ACT-3004", "키 이벤트 생성 실패: keyCode=\(combo.keyCode)")
            return false
        }
        for keyCode in modifierKeyCodes {
            CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)?.post(tap: .cghidEventTap)
        }
        down.flags = flags
        down.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.02)
        up.flags = flags
        up.post(tap: .cghidEventTap)
        for keyCode in modifierKeyCodes.reversed() {
            CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)?.post(tap: .cghidEventTap)
        }
        Logger.info("ActionExecutor", "키 조합 전송: \(KeyboardUtil.displayString(keyCode: combo.keyCode, modifiers: combo.modifiers))")
        return true
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