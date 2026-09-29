import Foundation
import AppKit

/// 단축어 실행 엔진 — 단계를 순서대로 실행하며 흐름 제어(If/Repeat/ChooseFromMenu) 처리
final class ExecutionEngine {
    static let shared = ExecutionEngine()

    /// 실행 전용 **직렬** 큐 (E-MAC-ACT-3006)
    ///
    /// 왜 직렬인가: 실행 횟수가 아니라 **상태가 하나뿐인 싱글턴**이 있다.
    /// - `ActionExecutor.pauseSemaphore` — 사이보그 모드는 대기 중 세마포어 하나를 갖는다.
    ///   두 실행이 겹치면 나중에 시작한 쪽이 이전 세마포어를 교체·신호해 대기가 깨진다.
    /// - `ActionExecutor.pauseMonitor` — NSEvent 모니터도 하나뿐이다.
    /// 메인 스레드 동기 실행에서는 이 직렬성이 런타임이 공짜로 보장했으므로
    /// 백그라운드로 옮기면서 **직접 보존해야 한다.** `DispatchQueue.global`로 풀면 안 된다.
    ///
    /// 핫키 실행·자동화 실행·단계 테스트가 전부 이 큐를 공유한다.
    static let executionQueue = DispatchQueue(
        label: "com.borasarang.ApexKey.execution",
        qos: .userInitiated
    )

    /// Run Shortcut이 호출할 단축어 조회 클로저 (ConfigStore에서 주입)
    var shortcutProvider: ((UUID) -> ShortcutItem?)?

    /// Run Shortcut 최대 재귀 깊이 (순환 호출 가드)
    static let maxRunShortcutDepth = 10

    /// 실행 상태
    enum ControlFlow {
        case continueExecution  // 계속 실행
        case stop               // 단축어 중지
        case ended              // Stop Shortcut 결과
        case breakLoop          // 반복 중단
        case continueLoop       // 다음 반복으로
    }
    
    /// 실행 결과
    struct Result {
        var success: Bool = true
        var controlFlow: ControlFlow = .continueExecution
        var error: String?
        
        static let continueRunning = Result(success: true, controlFlow: .continueExecution)
    }
    
    /// 단축어 실행
    @discardableResult
    func execute(_ shortcut: ShortcutItem, context: inout UseModelExecutor.ExecutionContext, depth: Int = 0) -> Result {
        if depth >= ExecutionEngine.maxRunShortcutDepth {
            Logger.error("E-MAC-FLOW-7009", "Run Shortcut 재귀 깊이 초과 (\(ExecutionEngine.maxRunShortcutDepth)) — 순환 호출 확인")
            return Result(success: false, controlFlow: .continueExecution, error: "error.user.action_failed_fmt".localizedFormat(shortcut.name))
        }
        Logger.info("ExecutionEngine", "실행 시작: \(shortcut.name) (\(shortcut.steps.count)단계)")
        
        let result = execute(steps: shortcut.steps, context: &context, depth: depth)
        
        if result.controlFlow == .continueExecution || result.controlFlow == .stop {
            Logger.info("ExecutionEngine", "실행 완료: \(shortcut.name) (success=\(result.success))")
        }
        return result
    }
    
    /// 단계 배열 실행
    func execute(steps: [ShortcutStep], context: inout UseModelExecutor.ExecutionContext, depth: Int = 0) -> Result {
        var ok = true
        // E-MAC-FLOW-7009: 실패 사유를 최초 1건만 보존한다.
        // 이전에는 `error`를 버려서 스크립트 문법 오류 같은 구체적 원인이
        // 상위에서 "동작 실패: <이름>"으로 뭉개졌다.
        var firstError: String?
        for (index, step) in steps.enumerated() {
            // 스킵된 단계는 건너뜀
            if step.isSkipped {
                Logger.info("ExecutionEngine", "스킵: \(step.type.displayName) — \(step.title)")
                continue
            }

            Logger.info("ExecutionEngine", "단계 \(index + 1)/\(steps.count): \(step.type.displayName)")

            let result = executeStep(step, context: &context, depth: depth)
            if !result.success {
                ok = false
                if firstError == nil { firstError = result.error }
            }

            // 흐름 제어 처리
            switch result.controlFlow {
            case .breakLoop:
                // 반복 탈출은 상위로 전파 (반복 핸들러가 변환 담당).
                // 그때까지 실패가 있으면 전체 실패로 전파 (성공 둔팝 방지)
                return Result(success: ok && result.success, controlFlow: .breakLoop, error: firstError)
            case .continueLoop:
                continue
            case .stop, .ended:
                // E-MAC-FLOW-7009: stop/ended는 `result`만 반환해 그 이전에 쌓인 실패를 버렸다.
                // Stop Shortcut 이전에 실패한 단계가 있어도 success:true가 보고됐다.
                return Result(success: ok && result.success, controlFlow: result.controlFlow, error: firstError ?? result.error)
            case .continueExecution:
                break  // 계속
            }
        }
        return Result(success: ok, controlFlow: .continueExecution, error: firstError)
    }
    
    // MARK: - 텍스트 액션 (E-MAC-TEXT-6001)
    
    /// 텍스트 액션 11종 실행.
    ///
    /// `target`이 주 입력이고, 나머지 파라미터는 `actionParameters`의
    /// `TextActionConfig`에서 온다. `target`의 Magic Variable 토큰을 먼저 해석한다.
    private func executeTextAction(_ step: ShortcutStep, context: inout UseModelExecutor.ExecutionContext) -> Result {
        let config = TextActionConfig.decode(from: step.actionParameters)
        let ctx = makeResolveContext(context)
        // 주 입력: actionParameters.text가 우선, 없으면 target
        let rawInput = config.text?.isEmpty == false ? config.text! : step.target
        let input = VariableResolver.resolveText(rawInput, context: ctx)
        // 보조 입력들도 Magic Variable를 받을 수 있어야 한다
        let search = VariableResolver.resolveText(config.search ?? "", context: ctx)
        let replacement = VariableResolver.resolveText(config.replacement ?? "", context: ctx)
        let separator = VariableResolver.resolveText(config.separator ?? "", context: ctx)

        let outcome: TextActions.Outcome
        switch step.type {
        case .text:
            outcome = TextActions.text(input)
        case .combineText:
            // `\u{1F}` 블록 구분은 설정 UI가 쓰는 다중 입력 표현이다
            let parts = separator.isEmpty
                ? input.components(separatedBy: "\u{1F}")
                : input.components(separatedBy: separator)
            outcome = TextActions.combine(parts.isEmpty ? [input] : parts, separator: config.separator ?? " ")
        case .splitText:
            outcome = TextActions.split(input, separator: separator)
        case .trimWhitespace:
            outcome = TextActions.trimWhitespace(input)
        case .replaceText:
            outcome = TextActions.replace(input, search: search, replacement: replacement)
        case .regex:
            // 치환 문자열이 있으면 치환, 없으면 매치 추출
            if config.replacement?.isEmpty == false {
                outcome = TextActions.regexReplace(input, pattern: search, replacement: replacement)
            } else {
                outcome = TextActions.regex(input, pattern: search, allMatches: step.title == "all")
            }
        case .matchText:
            outcome = TextActions.matches(input, pattern: search)
        case .count:
            outcome = TextActions.count(input, unit: config.countUnit ?? .characters)
        case .formatNumber:
            outcome = TextActions.formatNumber(
                input,
                style: config.numberStyle ?? .decimal,
                decimals: config.decimals ?? 0,
                grouping: config.grouping ?? true
            )
        case .getClipboard:
            outcome = TextActions.getClipboard()
        case .setClipboard:
            outcome = TextActions.setClipboard(input)
        default:
            return Result(
                success: false,
                controlFlow: .continueExecution,
                error: "error.user.action_failed_fmt".localizedFormat(step.type.displayName)
            )
        }

        switch outcome {
        case .success(let value):
            context.setOutput(.text(value), for: step.id)
            context.lastOutput = .text(value)
            Logger.info("ExecutionEngine", "텍스트 액션 완료: \(step.type.rawValue) (\(value.count)자)")
            return .continueRunning
        case .failure(let reason):
            Logger.error("E-MAC-TEXT-6002", "텍스트 액션 실패: \(step.type.rawValue) — \(reason)")
            return Result(success: false, controlFlow: .continueExecution, error: reason.messageKey.localized)
        }
    }

    // MARK: - 단계 실행
    
    private func executeStep(_ step: ShortcutStep, context: inout UseModelExecutor.ExecutionContext, depth: Int = 0) -> Result {
        switch step.type {
        // === 텍스트 액션 11종 (E-MAC-TEXT-6001) ===
        case .text, .combineText, .splitText, .trimWhitespace, .replaceText,
             .regex, .matchText, .count, .formatNumber, .getClipboard, .setClipboard:
            return executeTextAction(step, context: &context)

        // === AI 액션 ===
        case .useModel:
            let ok = UseModelExecutor.shared.execute(step, context: &context)
            if !ok {
                return Result(success: false, controlFlow: .continueExecution, error: "error.user.action_failed_fmt".localizedFormat(step.type.displayName))
            }
            return .continueRunning

        case .writingTool:
            let ok = WritingToolExecutor.shared.execute(step, context: &context)
            if !ok {
                return Result(success: false, controlFlow: .continueExecution, error: "error.user.action_failed_fmt".localizedFormat(step.type.displayName))
            }
            return .continueRunning

        case .imagePlayground:
            let ok = ImagePlaygroundExecutor.shared.execute(step, context: &context)
            if !ok {
                return Result(success: false, controlFlow: .continueExecution, error: "error.user.action_failed_fmt".localizedFormat(step.type.displayName))
            }
            return .continueRunning
            
        // === 흐름 제어 ===
        case .ifElse:
            return executeIf(step, context: &context, depth: depth)

        case .repeatLoop:
            if let loop = step.repeatLoop, loop.mode == .whileLoop {
                // whileLoop는 아직 조건 표현식이 없어 횟수 반복으로 폴백 (1회)
                Logger.error("E-MAC-FLOW-7008", "whileLoop 모드는 미지원 — 1회 반복으로 처리: \(step.title)")
            }
            return executeRepeatCount(step, context: &context, depth: depth)

        case .repeatEach:
            return executeRepeatEach(step, context: &context, depth: depth)
            
        case .endRepeat:
            return .continueRunning  // Repeat 블록 내부에서 처리됨
            
        case .chooseFromMenu:
            return executeChooseFromMenu(step, context: &context)

        case .runShortcut:
            return executeRunShortcut(step, context: &context, depth: depth)
            
        case .stopShortcut:
            return executeStopShortcut(step, context: &context)
            
        case .comment:
            return .continueRunning  // 주석은 실행 없음
            
        case .setVariable:
            return executeSetVariable(step, context: &context)

        case .script, .runScriptInShell:
            return executeShellScript(step, context: &context)

        case .appleScript:
            return executeAppleScript(step, context: &context)

        case .javaScriptForAutomation:
            return executeJXA(step, context: &context)

        case .launchApp:
            return executeLaunchApp(step, context: &context)

        case .keyCombo:
            return executeKeyCombo(step, context: &context)
            
        case .outputToVariable:
            return executeOutputToVariable(step, context: &context)
            
        default:
            // 일반 액션은 변수 토큰 치환 후 실행, 실패는 성공으로 둔팝시키지 않고 전파 (R-01)
            var binding = step.toBinding()
            binding.target = VariableResolver.resolveText(step.target, context: makeResolveContext(context))
            // E-MAC-FLOW-7009: `setOutput`이 아예 없어서 `{lastResult}`·출력-변수 단계가
            // 이 단계의 결과가 아니라 **이전 블록의 잔여값**을 읽었다.
            // 실행 결과를 이 단계의 출력으로 기록해 흐름을 이어간다.
            let detail = ActionExecutor.shared.executeWithDetail(binding)
            context.setOutput(.text(detail.message ?? ""), for: step.id)
            context.lastOutput = .text(detail.message ?? "")
            if !detail.success {
                return Result(
                    success: false,
                    controlFlow: .continueExecution,
                    error: detail.message ?? "error.user.action_failed_fmt".localizedFormat(step.type.displayName)
                )
            }
            return .continueRunning
        }
    }
    
    // MARK: - If/Otherwise
    
    private func executeIf(_ step: ShortcutStep, context: inout UseModelExecutor.ExecutionContext, depth: Int = 0) -> Result {
        guard let branch = step.ifBranch else {
            Logger.error("E-MAC-FLOW-7001", "If 단계에 ifBranch 설정이 없음")
            return Result(success: false, controlFlow: .continueExecution, error: "error.user.action_failed_fmt".localizedFormat(step.type.displayName))
        }

        // 조건 평가 — 변수/특수변수(반복 인덱스 등)/매직변수 모두 포함
        let conditionResult = branch.condition.evaluate(with: makeResolveContext(context))
        Logger.info("ExecutionEngine", "If 조건: \(branch.condition.displayString) → \(conditionResult ? "참" : "거짓")")

        let stepsToRun = conditionResult ? branch.thenSteps : (branch.elseSteps ?? [])
        return execute(steps: stepsToRun, context: &context, depth: depth)
    }

    // MARK: - Repeat (횟수 반복)

    private func executeRepeatCount(_ step: ShortcutStep, context: inout UseModelExecutor.ExecutionContext, depth: Int = 0) -> Result {
        guard let loop = step.repeatLoop else {
            Logger.error("E-MAC-FLOW-7002", "Repeat 단계에 repeatLoop 설정이 없음")
            return Result(success: false, controlFlow: .continueExecution, error: "error.user.action_failed_fmt".localizedFormat(step.type.displayName))
        }
        
        // whileLoop/count 미설정 시 기본 1회 (기존 0회 조용한 실패 방지)
        let count = loop.count ?? 1
        guard count > 0 else {
            Logger.error("E-MAC-FLOW-7008", "반복 횟수 0 이하 — 실행 생략 (count=\(loop.count ?? 0))")
            return Result(success: false, controlFlow: .continueExecution, error: "error.user.action_failed_fmt".localizedFormat(step.type.displayName))
        }
        Logger.info("ExecutionEngine", "반복 시작: \(count)회 (\(loop.mode.rawValue))")
        
        let previousRepeatIndex = context.repeatIndex
        let previousRepeatItem = context.repeatItem

        // E-MAC-FLOW-7009: 반복 내부의 실패를 흡수하지 않고 상위로 전파한다.
        // 이전에는 controlFlow만 보고 `.continueExecution`을 무시한 뒤 무조건
        // `.continueRunning`(success: true)을 반환해, 반복 안의 AppleScript/셸이
        // 매 회 실패해도 단축어가 성공으로 보고되고 runCount가 증가했다.
        var anyFailed = false
        var firstError: String?

        for iteration in 1...count {
            context.repeatIndex = iteration
            context.repeatItem = .number(Double(iteration))
            // 인덱스 변수가 지정된 때만 기록 (nil이면 매번 랜덤 UUID에 쌓이는 쓰레기 출력 방지)
            if let indexVarID = loop.repeatIndexVariable {
                context.setOutput(.number(Double(iteration)), for: indexVarID)
            }

            let result = execute(steps: loop.steps, context: &context, depth: depth)
            if !result.success {
                anyFailed = true
                if firstError == nil { firstError = result.error }
            }
            switch result.controlFlow {
            case .breakLoop:
                Logger.info("ExecutionEngine", "반복 중단됨 (iteration \(iteration))")
                context.repeatIndex = previousRepeatIndex
                context.repeatItem = previousRepeatItem
                if anyFailed {
                    return Result(success: false, controlFlow: .continueExecution, error: firstError)
                }
                return .continueRunning
            case .stop, .ended:
                context.repeatIndex = previousRepeatIndex
                context.repeatItem = previousRepeatItem
                return Result(success: !anyFailed && result.success, controlFlow: result.controlFlow, error: firstError ?? result.error)
            case .continueLoop:
                continue
            case .continueExecution:
                continue
            }
        }

        context.repeatIndex = previousRepeatIndex
        context.repeatItem = previousRepeatItem
        Logger.info("ExecutionEngine", "반복 완료: \(count)회 (실패=\(anyFailed))")
        if anyFailed {
            return Result(success: false, controlFlow: .continueExecution, error: firstError)
        }
        return .continueRunning
    }
    
    // MARK: - Repeat with Each (항목 반복)
    
    private func executeRepeatEach(_ step: ShortcutStep, context: inout UseModelExecutor.ExecutionContext, depth: Int = 0) -> Result {
        guard let loop = step.repeatLoop else {
            Logger.error("E-MAC-FLOW-7003", "Repeat Each 단계에 repeatLoop 설정이 없음")
            return Result(success: false, controlFlow: .continueExecution, error: "error.user.action_failed_fmt".localizedFormat(step.type.displayName))
        }
        
        // 컬렉션 가져오기
        let collection: [VariableValue]
        if let varID = loop.collectionVariable {
            collection = context.variables[varID]?.asList ?? []
        } else {
            collection = []
        }
        
        Logger.info("ExecutionEngine", "각 항목 반복 시작: \(collection.count)개 항목")
        
        let previousRepeatIndex = context.repeatIndex
        let previousRepeatItem = context.repeatItem

        // E-MAC-FLOW-7009 — executeRepeatCount와 동일하게 내부 실패를 전파한다.
        var anyFailed = false
        var firstError: String?

        for (index, item) in collection.enumerated() {
            let iteration = index + 1
            context.repeatIndex = iteration
            context.repeatItem = item
            if let indexVarID = loop.repeatIndexVariable {
                context.setOutput(.number(Double(iteration)), for: indexVarID)
            }
            if let itemVarID = loop.repeatItemVariable {
                context.setOutput(item, for: itemVarID)
            }

            let result = execute(steps: loop.steps, context: &context, depth: depth)
            if !result.success {
                anyFailed = true
                if firstError == nil { firstError = result.error }
            }
            switch result.controlFlow {
            case .breakLoop:
                Logger.info("ExecutionEngine", "반복 중단됨 (item \(iteration))")
                context.repeatIndex = previousRepeatIndex
                context.repeatItem = previousRepeatItem
                if anyFailed {
                    return Result(success: false, controlFlow: .continueExecution, error: firstError)
                }
                return .continueRunning
            case .stop, .ended:
                context.repeatIndex = previousRepeatIndex
                context.repeatItem = previousRepeatItem
                return Result(success: !anyFailed && result.success, controlFlow: result.controlFlow, error: firstError ?? result.error)
            case .continueLoop:
                continue
            case .continueExecution:
                break
            }
        }
        
        context.repeatIndex = previousRepeatIndex
        context.repeatItem = previousRepeatItem
        Logger.info("ExecutionEngine", "항목 반복 완료: \(collection.count)개 (실패=\(anyFailed))")
        if anyFailed {
            return Result(success: false, controlFlow: .continueExecution, error: firstError)
        }
        return .continueRunning
    }
    
    // MARK: - Choose from Menu
    
    private func executeChooseFromMenu(_ step: ShortcutStep, context: inout UseModelExecutor.ExecutionContext) -> Result {
        guard let menu = step.chooseFromMenu else {
            Logger.error("E-MAC-FLOW-7004", "Choose From Menu 단계에 설정이 없음")
            return Result(success: false, controlFlow: .continueExecution, error: "error.user.action_failed_fmt".localizedFormat(step.type.displayName))
        }

        guard !menu.options.isEmpty else {
            Logger.error("E-MAC-FLOW-7005", "메뉴 옵션이 없음")
            return Result(success: false, controlFlow: .continueExecution, error: "error.user.action_failed_fmt".localizedFormat(step.type.displayName))
        }
        
        // 메뉴 표시 (동기식 대화상자) — NSAlert.runModal은 메인 스레드에서만 가능
        var selectedValue: VariableValue? = nil
        var cancelled = false
        
        func presentMenu() {
            let alert = NSAlert()
            alert.messageText = menu.prompt
            alert.alertStyle = .informational
            
            for option in menu.options {
                alert.addButton(withTitle: option.title)
            }
            if menu.showCancelButton {
                alert.addButton(withTitle: "ui.cancel".localized)
            }
            
            let response = alert.runModal()
            
            // 응답 처리
            let firstRaw = NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
            let cancelRaw = firstRaw + menu.options.count  // 취소 버튼 = 마지막
            if menu.showCancelButton && response.rawValue == cancelRaw {
                cancelled = true
                return
            }
            
            let selectedIndex = response.rawValue - firstRaw
            guard selectedIndex >= 0 && selectedIndex < menu.options.count else {
                cancelled = true
                return
            }
            selectedValue = menu.options[selectedIndex].value
        }
        
        if Thread.isMainThread {
            presentMenu()
        } else {
            DispatchQueue.main.sync { presentMenu() }
        }
        
        if cancelled {
            Logger.info("ExecutionEngine", "메뉴 선택 취소")
            context.setOutput(.null, for: menu.outputVariable)
            return .continueRunning
        }
        
        context.setOutput(selectedValue ?? .null, for: menu.outputVariable)
        if let sv = selectedValue {
            let title = menu.options.first(where: { $0.value == sv })?.title ?? ""
            Logger.info("ExecutionEngine", "메뉴 선택: \(title)")
        }
        
        return .continueRunning
    }
    
    // MARK: - Run Shortcut
    
    private func executeRunShortcut(_ step: ShortcutStep, context: inout UseModelExecutor.ExecutionContext, depth: Int = 0) -> Result {
        guard let targetID = UUID(uuidString: step.target) else {
            Logger.error("E-MAC-FLOW-7006", "Run Shortcut 대상 UUID가 유효하지 않음: \(step.target)")
            return Result(success: false, controlFlow: .continueExecution, error: "error.user.action_failed_fmt".localizedFormat(step.type.displayName))
        }

        guard let targetShortcut = shortcutProvider?(targetID) else {
            Logger.error("E-MAC-FLOW-7007", "Run Shortcut 대상 단축어 없음: \(targetID.uuidString.prefix(8))")
            return Result(success: false, controlFlow: .continueExecution, error: "error.user.action_failed_fmt".localizedFormat(step.type.displayName))
        }

        Logger.info("ExecutionEngine", "단축어 호출: \(targetShortcut.name)")
        return execute(targetShortcut, context: &context, depth: depth + 1)
    }
    
    // MARK: - Stop Shortcut
    
    private func executeStopShortcut(_ step: ShortcutStep, context: inout UseModelExecutor.ExecutionContext) -> Result {
        // StopShortcutAction을 actionParameters에서 디코딩해 outputVariable에 기록 (E-MAC-UX-9003)
        if let data = step.actionParameters,
           let action = try? JSONDecoder().decode(StopShortcutAction.self, from: data),
           let outputVariable = action.outputVariable {
            let value = action.outputValue ?? context.lastOutput
            context.variables[outputVariable] = value
            Logger.info("ExecutionEngine", "단축어 중지 → 출력 변수 기록")
        }
        Logger.info("ExecutionEngine", "단축어 중지")
        return Result(success: true, controlFlow: .ended)
    }
    
    // MARK: - Set Variable
    
    private func executeSetVariable(_ step: ShortcutStep, context: inout UseModelExecutor.ExecutionContext) -> Result {
        // target 값을 변수로 설정 (변수 토큰 해석)
        if let outputVariable = step.outputVariables?.first {
            let resolveCtx = makeResolveContext(context)
            let resolvedTarget = VariableResolver.resolveText(step.target, context: resolveCtx)
            let value = inferValue(from: resolvedTarget)
            context.variables[outputVariable.id] = value
            Logger.info("ExecutionEngine", "변수 설정: \(outputVariable.name) = \(resolvedTarget)")
        }
        return .continueRunning
    }
    
    // MARK: - Output to Variable
    
    private func executeOutputToVariable(_ step: ShortcutStep, context: inout UseModelExecutor.ExecutionContext) -> Result {
        // 마지막 출력을 변수로 저장
        if let outputVariable = step.outputVariables?.first {
            context.variables[outputVariable.id] = context.lastOutput
            Logger.info("ExecutionEngine", "출력 → 변수: \(outputVariable.name)")
        }
        return .continueRunning
    }
    
    // MARK: - 셸 스크립트

    /// 스크립트 단계 실행 — 변수 토큰({마법변수} 등)을 해석한 뒤 셸에서 실행
    private func executeShellScript(_ step: ShortcutStep, context: inout UseModelExecutor.ExecutionContext) -> Result {
        // E-MAC-SCRIPT-6004: 치환된 값은 셸 리터럴로 인용한다.
        // {clipboard}·{lastResult}는 비신뢰 출처(사용자 클립보드, 직전 AI/웹 결과)이므로
        // 인용 없이 `/bin/zsh -c`에 들어가면 메타문자가 실행될 수 있다.
        let resolved = VariableResolver.resolveText(
            step.target,
            context: makeResolveContext(context),
            escaping: ShellEnvironment.literal
        )
        let ok = ActionExecutor.shared.runShellScriptResult(resolved)
        // E-MAC-FLOW-7009: 이전에는 `runShellScript`(성공 여부만 반환)가 stdout을 버려서
        // 출력 변수에 **스크립트 소스코드**가 기록됐다. `{lastResult}`나 출력-변수 단계가
        // 실행 결과가 아니라 명령 문자열을 받는 문제가 있었다.
        // AppleScript 경로처럼 실제 r.output을 기록한다.
        context.setOutput(.text(ok.output), for: step.id)
        context.lastOutput = .text(ok.output)
        if !ok.success {
            let detail = ok.errorOutput.isEmpty ? ok.output : ok.errorOutput
            return Result(
                success: false,
                controlFlow: .continueExecution,
                error: detail.isEmpty
                    ? "error.user.script_failed".localized
                    : String(detail.prefix(160))
            )
        }
        return .continueRunning
    }

    // MARK: - AppleScript / JXA

    private func executeAppleScript(_ step: ShortcutStep, context: inout UseModelExecutor.ExecutionContext) -> Result {
        let resolved = VariableResolver.resolveText(step.target, context: makeResolveContext(context))
        let r = ScriptExecutor.runAppleScript(resolved)
        context.setOutput(.text(r.output), for: step.id)
        context.lastOutput = .text(r.output)
        if !r.success {
            return Result(success: false, controlFlow: .continueExecution, error: r.errorOutput.isEmpty ? "error.user.script_failed".localized : r.errorOutput)
        }
        return .continueRunning
    }

    private func executeJXA(_ step: ShortcutStep, context: inout UseModelExecutor.ExecutionContext) -> Result {
        let resolved = VariableResolver.resolveText(step.target, context: makeResolveContext(context))
        let r = ScriptExecutor.runJXA(resolved)
        context.setOutput(.text(r.output), for: step.id)
        context.lastOutput = .text(r.output)
        if !r.success {
            return Result(success: false, controlFlow: .continueExecution, error: r.errorOutput.isEmpty ? "error.user.script_failed".localized : r.errorOutput)
        }
        return .continueRunning
    }

    // MARK: - 앱 실행/토글

    private func executeLaunchApp(_ step: ShortcutStep, context: inout UseModelExecutor.ExecutionContext) -> Result {
        var config = step.effectiveLaunchConfig
        // 변수 토큰 해석 (bundleID/path/args/스킴 전부)
        let ctx = makeResolveContext(context)
        config.bundleID = VariableResolver.resolveText(config.bundleID, context: ctx)
        config.path = VariableResolver.resolveText(config.path, context: ctx)
        config.args = VariableResolver.resolveText(config.args, context: ctx)
        config.urlScheme = VariableResolver.resolveText(config.urlScheme, context: ctx)
        let ok = AppSwitcher.execute(config: config)
        context.setOutput(.text(config.displayName), for: step.id)
        context.lastOutput = .text(config.displayName)
        if !ok {
            return Result(success: false, controlFlow: .continueExecution, error: "error.user.action_failed_fmt".localizedFormat(step.type.displayName))
        }
        return .continueRunning
    }

    // MARK: - 키 조합 보내기

    private func executeKeyCombo(_ step: ShortcutStep, context: inout UseModelExecutor.ExecutionContext) -> Result {
        // 구조화 설정 우선, 없으면 레거시 target "keyCode:modifiers" 파싱
        let combo: HotKeyCombo?
        if let press = step.keyPress, !press.isEmpty {
            combo = press
        } else {
            combo = ActionExecutor.parseKeyPress(from: VariableResolver.resolveText(step.target, context: makeResolveContext(context)))
        }
        guard let combo else {
            return Result(success: false, controlFlow: .continueExecution, error: "error.user.action_failed_fmt".localizedFormat(step.type.displayName))
        }
        let ok = ActionExecutor.sendKeyPress(combo)
        let label = KeyboardUtil.displayString(keyCode: combo.keyCode, modifiers: combo.modifiers)
        context.setOutput(.text(label), for: step.id)
        context.lastOutput = .text(label)
        if !ok {
            return Result(success: false, controlFlow: .continueExecution, error: "error.user.action_failed_fmt".localizedFormat(step.type.displayName))
        }
        return .continueRunning
    }

    // MARK: - 헬퍼
    
    /// ExecutionContext → VariableResolver.ResolveContext 변환
    private func makeResolveContext(_ context: UseModelExecutor.ExecutionContext) -> VariableResolver.ResolveContext {
        var resolveCtx = VariableResolver.ResolveContext()
        resolveCtx.variables = context.variables
        resolveCtx.stepOutputs = context.stepOutputs
        resolveCtx.lastOutput = context.lastOutput
        resolveCtx.repeatIndex = context.repeatIndex
        resolveCtx.repeatItem = context.repeatItem
        resolveCtx.shortcutInput = context.shortcutInput
        return resolveCtx
    }
    
    /// 문자열에서 숫자/불리언/텍스트 타입 추론
    private func inferValue(from text: String) -> VariableValue {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == "true" || trimmed == "참" || trimmed == "예" { return .boolean(true) }
        if trimmed == "false" || trimmed == "거짓" || trimmed == "아니오" { return .boolean(false) }
        if let number = Double(trimmed) { return .number(number) }
        return .text(text)
    }
}
