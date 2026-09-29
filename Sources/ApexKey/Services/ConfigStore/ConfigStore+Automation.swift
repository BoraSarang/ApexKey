import Foundation
import SwiftData
import AppKit
import Combine

/// ConfigStore 영역 분할 (R-10) — 동일 클래스 extension, public API 동결.
extension ConfigStore {
    /// 모든 워크플로우에 등록된 자동화 트리거 수 (사이드바 배지)
    ///
    /// E-MAC-AUTO-8003: 이전에는 `automations.count`를 그대로 셌다. 그런데 `register`는
    /// 미구현 트리거 8종을 거부하므로 **배지에 표시된 수와 실제 등록 수가 달랐다**
    /// (배지 4 / 등록 0 같은 상태). 배지는 사용자가 "자동화가 몇 개 있나"를 판단하는
    /// 기준이므로 실제 등록 기준으로 세야 한다.
    var automationTriggerCount: Int {
        shortcuts.reduce(0) { partial, shortcut in
            partial + shortcut.automations.filter(\.isWatcherSupported).count
        }
    }

    /// 미구현이라 등록되지 않는 트리거 수 (UI에서 "준비 중" 안내용)
    var unimplementedTriggerCount: Int {
        shortcuts.reduce(0) { partial, shortcut in
            partial + shortcut.automations.filter { !$0.isWatcherSupported }.count
        }
    }

    // MARK: - 개인 자동화 연동

    /// AutomationManager에 단축어 트리거 등록 + 콜백 연결 + RunShortcut 조회 주입
    func configureAutomationManager() {
        let automationManager = AutomationManager.shared
        automationManager.onTriggerFired = { [weak self] shortcutID, trigger, event in
            self?.runAutomation(shortcutID: shortcutID, trigger: trigger, input: event.toVariableValue())
        }
        ExecutionEngine.shared.shortcutProvider = { [weak self] shortcutID in
            // E-MAC-ACT-3006: 실행이 백그라운드로 옮겨져 이 클로저가 **오프메인에서** 불린다
            // (Run Shortcut 단계가 하위 단축어를 조회할 때). `shortcuts`는 MainActor 상태라
            // 직접 읽으면 데이터 경쟁이므로 메인으로 한 번 홉한다.
            //
            // 교착이 없는 이유: 실행 큐는 직렬이고, 메인은 실행 큐를 기다리지 않는다.
            // 메인이 막히는 유일한 경로(동기 실행)는 이번 커밋에서 제거했다.
            guard let self else { return nil }
            if Thread.isMainThread {
                return self.shortcuts.first(where: { $0.id == shortcutID })
            }
            var resolved: ShortcutItem?
            DispatchQueue.main.sync {
                resolved = self.shortcuts.first(where: { $0.id == shortcutID })
            }
            return resolved
        }
        automationManager.unregisterAll()
        for shortcut in shortcuts where !shortcut.automations.isEmpty {
            automationManager.register(shortcut: shortcut)
        }
        Logger.info("ConfigStore", "자동화 트리거 등록: \(automationManager.registeredCount)개")
    }

    /// 자동화 트리거로 단축어 실행
    ///
    /// E-MAC-ACT-3006: 실행은 백그라운드로, 통계 갱신은 메인으로.
    /// 컨텍스트 구성에 MainActor 상태(변수 기본값)를 쓰므로 **메인에서 먼저 끝내고**,
    /// 값 타입만 캡처해 백그라운드로 넘긴다.
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

        runOffMainThread(
            {
                ExecutionEngine.shared.execute(shortcut, context: &context)
            },
            onFinish: { [weak self] result in
                guard let self else { return }
                if result.success, let idx = self.shortcuts.firstIndex(where: { $0.id == shortcutID }) {
                    self.shortcuts[idx].lastRunAt = Date()
                    self.shortcuts[idx].runCount += 1
                    self.syncShortcut(self.shortcuts[idx])
                }
                Logger.info("ConfigStore", "자동화 실행 결과: success=\(result.success)")
            }
        )
    }
}
