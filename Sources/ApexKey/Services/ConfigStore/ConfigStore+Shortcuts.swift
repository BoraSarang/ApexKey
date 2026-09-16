import Foundation
import SwiftData
import AppKit
import Combine

/// ConfigStore 영역 분할 (R-10) — 동일 클래스 extension, public API 동결.
extension ConfigStore {
    // MARK: - 동작(단축어) 관리

    /// 첫 실행 시 예시 단축어 3개 생성 (사용자 학습용)
    func seedSampleShortcuts(context: ModelContext) {
        let samples: [ShortcutItem] = [
            ShortcutItem(
                name: "작업 시작",
                steps: [
                    ShortcutStep(type: .launchApp, target: "com.apple.Safari", title: "Safari"),
                    ShortcutStep(type: .wait, target: "1.0", title: "대기 1초"),
                    ShortcutStep(type: .launchApp, target: "com.apple.finder", title: "Finder"),
                ]
            ),
            ShortcutItem(
                name: "볼륨 처리",
                steps: [
                    ShortcutStep(type: .macro, target: "49", title: "스페이스"),
                    ShortcutStep(type: .system, target: SystemActionType.mute.rawValue, title: "음소거 토글"),
                ]
            ),
            ShortcutItem(
                name: "정리 시작",
                steps: [
                    ShortcutStep(type: .script, target: "rm -rf ~/Library/Caches/ApexKey-tmp 2>/dev/null; echo 정리 완료", title: "캐시 정리"),
                    ShortcutStep(type: .wait, target: "2.0", title: "대기 2초"),
                    ShortcutStep(type: .system, target: SystemActionType.displaySleep.rawValue, title: "디스플레이 끄기"),
                ]
            ),
        ]
        samples.forEach { context.insert(PersistedShortcut.from($0)) }
        saveContext(context)
        shortcuts = samples
        Logger.info("ConfigStore", "[SHORTCUT] 예시 단축어 3개 생성")
    }

    /// 새 동작 생성 (빈 단계)
    @discardableResult
    func addShortcut(name: String) -> ShortcutItem? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let shortcut = ShortcutItem(name: trimmed)
        guard let context = container?.mainContext else { return nil }
        context.insert(PersistedShortcut.from(shortcut))
        saveContext(context)
        shortcuts.append(shortcut)
        Logger.info("ConfigStore", "[SHORTCUT] 동작 생성: \(trimmed)")
        return shortcut
    }

    func removeShortcut(_ shortcut: ShortcutItem) {
        if !shortcut.combo.isEmpty {
            hotKeyService.unregister(shortcut.id)
        }
        shortcuts.removeAll { $0.id == shortcut.id }
        guard let context = container?.mainContext else { return }
        let fetch = FetchDescriptor<PersistedShortcut>(predicate: #Predicate { $0.id == shortcut.id })
        if let found = fetchContext(context, fetch).first {
            context.delete(found)
        }
        saveContext(context)
        Logger.info("ConfigStore", "[SHORTCUT] 동작 삭제: \(shortcut.name)")
    }

    /// 동작 이름 변경
    func renameShortcut(_ shortcut: ShortcutItem, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let idx = shortcuts.firstIndex(where: { $0.id == shortcut.id }) else { return }
        shortcuts[idx].name = trimmed
        syncShortcut(shortcuts[idx])
    }

    /// 동작에 단계 추가
    func addStep(to shortcut: ShortcutItem, step: ShortcutStep) {
        guard let idx = shortcuts.firstIndex(where: { $0.id == shortcut.id }) else { return }
        shortcuts[idx].steps.append(step)
        syncShortcut(shortcuts[idx])
        Logger.info("ConfigStore", "[SHORTCUT] 단계 추가: \(step.type.displayName)")
    }

    /// 단계 삭제
    func removeStep(from shortcut: ShortcutItem, at index: Int) {
        guard let idx = shortcuts.firstIndex(where: { $0.id == shortcut.id }),
              shortcuts[idx].steps.indices.contains(index) else { return }
        shortcuts[idx].steps.remove(at: index)
        syncShortcut(shortcuts[idx])
    }

    /// 단계 순서 이동 (위/아래)
    func moveStep(in shortcut: ShortcutItem, from index: Int, direction: MoveDirection) {
        guard let idx = shortcuts.firstIndex(where: { $0.id == shortcut.id }),
              shortcuts[idx].steps.indices.contains(index) else { return }
        let targetIdx: Int
        switch direction {
        case .up: targetIdx = index - 1
        case .down: targetIdx = index + 1
        }
        guard targetIdx >= 0, targetIdx < shortcuts[idx].steps.count else { return }
        shortcuts[idx].steps.swapAt(index, targetIdx)
        syncShortcut(shortcuts[idx])
    }

    /// 단계 복제
    func duplicateStep(in shortcut: ShortcutItem, at index: Int) {
        guard let idx = shortcuts.firstIndex(where: { $0.id == shortcut.id }),
              shortcuts[idx].steps.indices.contains(index) else { return }
        let step = shortcuts[idx].steps[index]
        var copy = step
        copy.id = UUID()
        shortcuts[idx].steps.insert(copy, at: index + 1)
        syncShortcut(shortcuts[idx])
    }

    /// 동작 실행 단축키 지정/변경 (중복 시 무시)
    func setShortcutCombo(_ shortcut: ShortcutItem, combo: HotKeyCombo) {
        if combo.isEmpty { return }
        if isDuplicate(combo: combo, excluding: shortcut.id) {
            Logger.info("ConfigStore", "[SHORTCUT] 중복 단축키 무시: \(combo.displayString)")
            return
        }
        guard let idx = shortcuts.firstIndex(where: { $0.id == shortcut.id }) else { return }
        // 이전 조합 해제
        if !shortcuts[idx].combo.isEmpty, shortcuts[idx].combo != combo {
            hotKeyService.unregister(shortcut.id)
        }
        shortcuts[idx].combo = combo
        _ = hotKeyService.register(shortcut.id, combo: combo)
        syncShortcut(shortcuts[idx])
        Logger.info("ConfigStore", "[SHORTCUT] 실행 단축키 지정: \(shortcut.name) → \(combo.displayString)")
    }

    /// 동작 단축키 해제
    func clearShortcutCombo(_ shortcut: ShortcutItem) {
        guard let idx = shortcuts.firstIndex(where: { $0.id == shortcut.id }) else { return }
        hotKeyService.unregister(shortcut.id)
        shortcuts[idx].combo = .empty
        syncShortcut(shortcuts[idx])
    }

    func syncShortcut(_ shortcut: ShortcutItem) {
        guard let context = container?.mainContext else { return }
        let fetch = FetchDescriptor<PersistedShortcut>(predicate: #Predicate { $0.id == shortcut.id })
        if let found = fetchContext(context, fetch).first {
            found.name = shortcut.name
            found.comboKeyCode = shortcut.combo.keyCode
            found.comboModifiers = shortcut.combo.modifiers
            found.comboDisplayString = shortcut.combo.displayString
            found.stepsData = StoreCoding.encode(shortcut.steps, label: "단축어 단계")
            found.iconRaw = shortcut.icon.displayName
            found.colorRaw = shortcut.color.rawValue
            found.aiModelRaw = shortcut.aiModel.rawValue
            found.descriptionText = shortcut.description
            found.showInSystemShortcuts = shortcut.showInSystemShortcuts
            found.folderName = shortcut.folder
            found.isShareable = shortcut.isShareable
            found.modifiedAt = shortcut.modifiedAt
            found.lastRunAt = shortcut.lastRunAt
            found.runCount = shortcut.runCount
            found.triggersData = StoreCoding.encode(shortcut.automations, label: "자동화 트리거")
            found.variablesData = StoreCoding.encode(shortcut.variables, label: "사용자 변수")
            found.permissionsData = StoreCoding.encode(shortcut.permissions, label: "단축어 권한")
        }
        saveContext(context)
    }

    // MARK: - 편집기 저장 (기존 ShortcutEditorView 확장 이관)

    func updateShortcutSteps(_ shortcut: ShortcutItem, steps: [ShortcutStep]) {
        if let index = shortcuts.firstIndex(where: { $0.id == shortcut.id }) {
            shortcuts[index].steps = steps
            shortcuts[index].modifiedAt = Date()
            syncShortcut(shortcuts[index])
        }
    }
    
    func updateShortcutName(_ shortcut: ShortcutItem, name: String) {
        if let index = shortcuts.firstIndex(where: { $0.id == shortcut.id }) {
            shortcuts[index].name = name
            shortcuts[index].modifiedAt = Date()
            syncShortcut(shortcuts[index])
        }
    }
    
    func updateShortcutDescription(_ shortcut: ShortcutItem, description: String) {
        if let index = shortcuts.firstIndex(where: { $0.id == shortcut.id }) {
            shortcuts[index].description = description
            shortcuts[index].modifiedAt = Date()
            syncShortcut(shortcuts[index])
        }
    }
    
    func updateShortcutAutomations(_ shortcut: ShortcutItem, automations: [AutomationTrigger]) {
        if let index = shortcuts.firstIndex(where: { $0.id == shortcut.id }) {
            shortcuts[index].automations = automations
            shortcuts[index].modifiedAt = Date()
            syncShortcut(shortcuts[index])
            // 해당 단축어 자동화 재등록
            AutomationManager.shared.unregister(shortcutID: shortcut.id)
            AutomationManager.shared.register(shortcut: shortcuts[index])
        }
    }
    
    func updateShortcutVariables(_ shortcut: ShortcutItem, variables: [Variable]) {
        if let index = shortcuts.firstIndex(where: { $0.id == shortcut.id }) {
            shortcuts[index].variables = variables
            shortcuts[index].modifiedAt = Date()
            syncShortcut(shortcuts[index])
        }
    }
}
