import Foundation
import AppKit

/// 단축어 실행 엔진 — 단계를 순서대로 실행하며 흐름 제어(If/Repeat/ChooseFromMenu) 처리
final class ExecutionEngine {
    static let shared = ExecutionEngine()
    
    /// Run Shortcut이 호출할 단축어 조회 클로저 (ConfigStore에서 주입)
    var shortcutProvider: ((UUID) -> ShortcutItem?)?
    
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
        static func stopped() -> Result { Result(success: true, controlFlow: .stop) }
    }
    
    /// 단축어 실행
    @discardableResult
    func execute(_ shortcut: ShortcutItem, context: inout UseModelExecutor.ExecutionContext) -> Result {
        Logger.info("ExecutionEngine", "실행 시작: \(shortcut.name) (\(shortcut.steps.count)단계)")
        
        let result = execute(steps: shortcut.steps, context: &context)
        
        if result.controlFlow == .continueExecution || result.controlFlow == .stop {
            Logger.info("ExecutionEngine", "실행 완료: \(shortcut.name) (success=\(result.success))")
        }
        return result
    }
    
    /// 단계 배열 실행
    func execute(steps: [ShortcutStep], context: inout UseModelExecutor.ExecutionContext) -> Result {
        var ok = true
        for (index, step) in steps.enumerated() {
            // 스킵된 단계는 건너뜀
            if step.isSkipped {
                Logger.info("ExecutionEngine", "스킵: \(step.type.displayName) — \(step.title)")
                continue
            }
            
            Logger.info("ExecutionEngine", "단계 \(index + 1)/\(steps.count): \(step.type.displayName)")
            
            let result = executeStep(step, context: &context)
            if !result.success { ok = false }

            // 흐름 제어 처리
            switch result.controlFlow {
            case .breakLoop:
                return Result(success: true, controlFlow: .continueExecution)
            case .continueLoop:
                continue
            case .stop, .ended:
                return result
            case .continueExecution:
                break  // 계속
            }
        }
        return Result(success: ok, controlFlow: .continueExecution)
    }
    
    // MARK: - 단계 실행
    
    private func executeStep(_ step: ShortcutStep, context: inout UseModelExecutor.ExecutionContext) -> Result {
        switch step.type {
        // === AI 액션 ===
        case .useModel:
            UseModelExecutor.shared.execute(step, context: &context)
            return .continueRunning
            
        case .writingTool:
            WritingToolExecutor.shared.execute(step, context: &context)
            return .continueRunning
            
        case .imagePlayground:
            ImagePlaygroundExecutor.shared.execute(step, context: &context)
            return .continueRunning
            
        // === 흐름 제어 ===
        case .ifElse:
            return executeIf(step, context: &context)
            
        case .repeatLoop:
            if let loop = step.repeatLoop, loop.mode == .whileLoop {
                // whileLoop는 아직 조건 표현식이 없어 횟수 반복으로 폴백 (1회)
                Logger.error("E-MAC-FLOW-7008", "whileLoop 모드는 미지원 — 1회 반복으로 처리: \(step.title)")
            }
            return executeRepeatCount(step, context: &context)
            
        case .repeatEach:
            return executeRepeatEach(step, context: &context)
            
        case .endRepeat:
            return .continueRunning  // Repeat 블록 내부에서 처리됨
            
        case .chooseFromMenu:
            return executeChooseFromMenu(step, context: &context)
            
        case .runShortcut:
            return executeRunShortcut(step, context: &context)
            
        case .stopShortcut:
            return executeStopShortcut(step, context: &context)
            
        case .comment:
            return .continueRunning  // 주석은 실행 없음
            
        case .setVariable:
            return executeSetVariable(step, context: &context)

        case .script, .runScriptInShell:
            return executeShellScript(step, context: &context)
            
        case .outputToVariable:
            return executeOutputToVariable(step, context: &context)
            
        default:
            // 일반 액션은 변수 토큰 치환 후 실행, 실패는 성공으로 둔갑시키지 않고 전파 (R-01)
            var binding = step.toBinding()
            binding.target = VariableResolver.resolveText(step.target, context: makeResolveContext(context))
            let ok = ActionExecutor.shared.execute(binding)
            if !ok {
                return Result(success: false, controlFlow: .continueExecution, error: "error.user.action_failed_fmt".localizedFormat(step.type.displayName))
            }
            return .continueRunning
        }
    }
    
    // MARK: - If/Otherwise
    
    private func executeIf(_ step: ShortcutStep, context: inout UseModelExecutor.ExecutionContext) -> Result {
        guard let branch = step.ifBranch else {
            Logger.error("E-MAC-FLOW-7001", "If 단계에 ifBranch 설정이 없음")
            return .continueRunning
        }
        
        // 조건 평가 — 변수/특수변수(반복 인덱스 등)/매직변수 모두 포함
        let conditionResult = branch.condition.evaluate(with: makeResolveContext(context))
        Logger.info("ExecutionEngine", "If 조건: \(branch.condition.displayString) → \(conditionResult ? "참" : "거짓")")
        
        let stepsToRun = conditionResult ? branch.thenSteps : (branch.elseSteps ?? [])
        return execute(steps: stepsToRun, context: &context)
    }
    
    // MARK: - Repeat (횟수 반복)
    
    private func executeRepeatCount(_ step: ShortcutStep, context: inout UseModelExecutor.ExecutionContext) -> Result {
        guard let loop = step.repeatLoop else {
            Logger.error("E-MAC-FLOW-7002", "Repeat 단계에 repeatLoop 설정이 없음")
            return .continueRunning
        }
        
        // whileLoop/count 미설정 시 기본 1회 (기존 0회 조용한 실패 방지)
        let count = loop.count ?? 1
        Logger.info("ExecutionEngine", "반복 시작: \(count)회 (\(loop.mode.rawValue))")
        
        let previousRepeatIndex = context.repeatIndex
        let previousRepeatItem = context.repeatItem
        
        for iteration in 1...count {
            context.repeatIndex = iteration
            context.repeatItem = .number(Double(iteration))
            context.setOutput(.number(Double(iteration)), for: loop.repeatIndexVariable ?? UUID())
            
            let result = execute(steps: loop.steps, context: &context)
            switch result.controlFlow {
            case .breakLoop:
                Logger.info("ExecutionEngine", "반복 중단됨 (iteration \(iteration))")
                context.repeatIndex = previousRepeatIndex
                context.repeatItem = previousRepeatItem
                return .continueRunning
            case .stop, .ended:
                context.repeatIndex = previousRepeatIndex
                context.repeatItem = previousRepeatItem
                return result
            case .continueLoop:
                continue
            case .continueExecution:
                break
            }
        }
        
        context.repeatIndex = previousRepeatIndex
        context.repeatItem = previousRepeatItem
        Logger.info("ExecutionEngine", "반복 완료: \(count)회")
        return .continueRunning
    }
    
    // MARK: - Repeat with Each (항목 반복)
    
    private func executeRepeatEach(_ step: ShortcutStep, context: inout UseModelExecutor.ExecutionContext) -> Result {
        guard let loop = step.repeatLoop else {
            Logger.error("E-MAC-FLOW-7003", "Repeat Each 단계에 repeatLoop 설정이 없음")
            return .continueRunning
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
        
        for (index, item) in collection.enumerated() {
            let iteration = index + 1
            context.repeatIndex = iteration
            context.repeatItem = item
            context.setOutput(.number(Double(iteration)), for: loop.repeatIndexVariable ?? UUID())
            if let itemVarID = loop.repeatItemVariable {
                context.setOutput(item, for: itemVarID)
            }
            
            let result = execute(steps: loop.steps, context: &context)
            switch result.controlFlow {
            case .breakLoop:
                Logger.info("ExecutionEngine", "반복 중단됨 (item \(iteration))")
                context.repeatIndex = previousRepeatIndex
                context.repeatItem = previousRepeatItem
                return .continueRunning
            case .stop, .ended:
                context.repeatIndex = previousRepeatIndex
                context.repeatItem = previousRepeatItem
                return result
            case .continueLoop:
                continue
            case .continueExecution:
                break
            }
        }
        
        context.repeatIndex = previousRepeatIndex
        context.repeatItem = previousRepeatItem
        Logger.info("ExecutionEngine", "항목 반복 완료: \(collection.count)개")
        return .continueRunning
    }
    
    // MARK: - Choose from Menu
    
    private func executeChooseFromMenu(_ step: ShortcutStep, context: inout UseModelExecutor.ExecutionContext) -> Result {
        guard let menu = step.chooseFromMenu else {
            Logger.error("E-MAC-FLOW-7004", "Choose From Menu 단계에 설정이 없음")
            return .continueRunning
        }
        
        guard !menu.options.isEmpty else {
            Logger.error("E-MAC-FLOW-7005", "메뉴 옵션이 없음")
            return .continueRunning
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
    
    private func executeRunShortcut(_ step: ShortcutStep, context: inout UseModelExecutor.ExecutionContext) -> Result {
        guard let targetID = UUID(uuidString: step.target) else {
            Logger.error("E-MAC-FLOW-7006", "Run Shortcut 대상 UUID가 유효하지 않음: \(step.target)")
            return .continueRunning
        }
        
        guard let targetShortcut = shortcutProvider?(targetID) else {
            Logger.error("E-MAC-FLOW-7007", "Run Shortcut 대상 단축어 없음: \(targetID.uuidString.prefix(8))")
            return .continueRunning
        }
        
        Logger.info("ExecutionEngine", "단축어 호출: \(targetShortcut.name)")
        return execute(targetShortcut, context: &context)
    }
    
    // MARK: - Stop Shortcut
    
    private func executeStopShortcut(_ step: ShortcutStep, context: inout UseModelExecutor.ExecutionContext) -> Result {
        // StopShortcutAction 설정은 actionParameters에 인코딩됨 (현재는 단순 중지)
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

    /// 스크립트 단계 실행 — 변수 토큰({매직변수} 등)을 해석한 뒤 셸에서 실행
    private func executeShellScript(_ step: ShortcutStep, context: inout UseModelExecutor.ExecutionContext) -> Result {
        let resolved = VariableResolver.resolveText(step.target, context: makeResolveContext(context))
        let ok = ActionExecutor.shared.runShellScript(resolved)
        context.setOutput(.text(resolved), for: step.id)
        context.lastOutput = .text(resolved)
        if !ok {
            return Result(success: false, controlFlow: .continueExecution, error: "error.user.script_failed".localized)
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
