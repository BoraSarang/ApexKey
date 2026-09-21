import Foundation
import SwiftData
import AppKit
import Combine

/// ConfigStore 영역 분할 (R-10) — 동일 클래스 extension, public API 동결.
extension ConfigStore {
    /// 모든 워크플로우에 등록된 자동화 트리거 수 (사이드바 배지)
    var automationTriggerCount: Int {
        shortcuts.reduce(0) { $0 + $1.automations.count }
    }

    // MARK: - 개인 자동화 연동

    /// AutomationManager에 단축어 트리거 등록 + 콜백 연결 + RunShortcut 조회 주입
    func configureAutomationManager() {
        let automationManager = AutomationManager.shared
        automationManager.onTriggerFired = { [weak self] shortcutID, trigger, event in
            self?.runAutomation(shortcutID: shortcutID, trigger: trigger, input: event.toVariableValue())
        }
        ExecutionEngine.shared.shortcutProvider = { [weak self] shortcutID in
            self?.shortcuts.first(where: { $0.id == shortcutID })
        }
        automationManager.unregisterAll()
        for shortcut in shortcuts where !shortcut.automations.isEmpty {
            automationManager.register(shortcut: shortcut)
        }
        Logger.info("ConfigStore", "자동화 트리거 등록: \(automationManager.registeredCount)개")
    }

    /// 자동화 트리거로 단축어 실행
    func runAutomation(shortcutID: UUID, trigger: AutomationTrigger, input: VariableValue) {
        guard let shortcut = shortcuts.first(where: { $0.id == shortcutID }) else {
            Logger.error("E-MAC-AUTO-8001", "자동화 대상 단축어 없음: \(shortcutID.uuidString.prefix(8))")
            return
        }
        Logger.info("ConfigStore", "개인 자동화 실행: \(shortcut.name) (트리거: \(trigger.displayName))")

        var context = UseModelExecutor.ExecutionContext()
        context.shortcutInput = input
        // 트리거 입력을 단축어 입력 변수로 연결
        let inputID = UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID()
        context.setOutput(input, for: inputID)
        context.variables[inputID] = input
        // 사용자 정의 변수 기본값 주입
        for variable in shortcut.variables where variable.type == .manual {
            if let defaultValue = variable.defaultValue {
                context.variables[variable.id] = defaultValue
            }
        }

        let result = ExecutionEngine.shared.execute(shortcut, context: &context)
        if result.success, let idx = shortcuts.firstIndex(where: { $0.id == shortcutID }) {
            shortcuts[idx].lastRunAt = Date()
            shortcuts[idx].runCount += 1
            syncShortcut(shortcuts[idx])
        }
        Logger.info("ConfigStore", "자동화 실행 결과: success=\(result.success)")
    }
}
