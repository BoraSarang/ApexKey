import Foundation
import SwiftData
import AppKit
import Combine

/// ConfigStore 영역 분할 (R-10) — 동일 클래스 extension, public API 동결.
extension ConfigStore {
    // MARK: - 동작(단축어) 관리

    /// 시스템 프리셋을 1단계 워크플로우로 생성 (같은 이름 프리셋이 이미 있으면 건너뜀)
    func addPresetShortcuts(_ types: [SystemActionType]) {
        guard !types.isEmpty, let context = container?.mainContext else { return }
        var created: [ShortcutItem] = []
        for type in types {
            guard !shortcuts.contains(where: { $0.name == type.displayName }) else { continue }
            let shortcut = ShortcutItem(
                name: type.displayName,
                steps: [ShortcutStep(type: .system, target: type.rawValue, title: type.displayName)],
                icon: .sfSymbol(name: type.systemImage)
            )
            context.insert(PersistedShortcut.from(shortcut))
            created.append(shortcut)
        }
        guard !created.isEmpty else { return }
        saveContext(context)
        shortcuts.append(contentsOf: created)
        Logger.info("ConfigStore", "[SHORTCUT] 프리셋 워크플로우 \(created.count)개 추가")
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
        AutomationManager.shared.unregister(shortcutID: shortcut.id)
        shortcuts.removeAll { $0.id == shortcut.id }
        corruptedShortcutBlobColumns.removeValue(forKey: shortcut.id)
        corruptedBlobFallbackBytes.removeValue(forKey: shortcut.id)
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
    @discardableResult
    func setShortcutCombo(_ shortcut: ShortcutItem, combo: HotKeyCombo) -> HotKeyApplyResult {
        if combo.isEmpty { return .invalidCombo }
        if isDuplicate(combo: combo, excluding: shortcut.id) {
            Logger.error("E-MAC-HTKEY-1003", "[SHORTCUT] 중복 단축키 — 변경 거부: \(combo.displayString) (기존 조합 유지)")
            return .duplicateCombo
        }
        guard let idx = shortcuts.firstIndex(where: { $0.id == shortcut.id }) else { return .appNotFound }
        // 이전 조합 해제
        if !shortcuts[idx].combo.isEmpty, shortcuts[idx].combo != combo {
            hotKeyService.unregister(shortcut.id)
        }
        shortcuts[idx].combo = combo
        guard hotKeyService.register(shortcut.id, combo: combo) else {
            Logger.error("E-MAC-HTKEY-1004", "Carbon 핫키 등록 실패 (OS 선점 가능): \(combo.displayString)")
            return .hotKeyRegistrationFailed
        }
        syncShortcut(shortcuts[idx])
        Logger.info("ConfigStore", "[SHORTCUT] 실행 단축키 지정: \(shortcut.name) → \(combo.displayString)")
        return .applied
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
            // 디코딩 실패한 blob 컬럼은 원본 Data 유지 — 메모리 fallback([])으로 영구 삭제 방지 (P0-3)
            let corrupt = corruptedShortcutBlobColumns[shortcut.id] ?? []
            if !corrupt.isEmpty {
                Logger.error("E-MAC-STORE-5003", "손상 blob 컬럼 쓰기 건너뜀: \(shortcut.name) (\(corrupt.map(\.rawValue).sorted().joined(separator: ",")))")
            }
            if corrupt.contains(.steps) {
                // 잠긴 컬럼이라도 지금 값이 왕복하면 잠금을 푼다 (E-MAC-STORE-5010)
                tryRecoverBlob(shortcut.steps, column: .steps, id: shortcut.id) { found.stepsData = $0 }
            } else {
                found.stepsData = StoreCoding.encodeKeeping(shortcut.steps, previous: found.stepsData, label: "단축어 단계")
            }
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
            if corrupt.contains(.triggers) {
                tryRecoverBlob(shortcut.automations, column: .triggers, id: shortcut.id) { found.triggersData = $0 }
            } else {
                found.triggersData = StoreCoding.encodeKeeping(shortcut.automations, previous: found.triggersData, label: "자동화 트리거")
            }
            if corrupt.contains(.variables) {
                tryRecoverBlob(shortcut.variables, column: .variables, id: shortcut.id) { found.variablesData = $0 }
            } else {
                found.variablesData = StoreCoding.encodeKeeping(shortcut.variables, previous: found.variablesData, label: "사용자 변수")
            }
            if corrupt.contains(.permissions) {
                tryRecoverBlob(shortcut.permissions, column: .permissions, id: shortcut.id) { found.permissionsData = $0 }
            } else {
                found.permissionsData = StoreCoding.encodeKeeping(shortcut.permissions, previous: found.permissionsData, label: "단축어 권한")
            }
        }
        saveContext(context)
    }

    /// 잠긴 blob 컬럼의 복구를 시도한다 (E-MAC-STORE-5010)
    ///
    /// **왜 필요한가**: `corruptedShortcutBlobColumns`의 해제 지점이 `load()`와
    /// `removeShortcut`뿐이었다. 그래서 한 번 손상되면 그 컬럼은 **영구 쓰기 잠금**이 되고,
    /// 복구 경로는 동작 삭제뿐이다. 사용자가 아무리 편집해도 저장은 계속 건너뛰어진다.
    /// 데이터는 소실되지 않지만 **편집이 반영되지 않는다** — 사용자는 버그로 느낀다.
    ///
    /// **해제 조건 3가지 (모두 만족해야 한다)**:
    /// 1. 인코딩이 성공했다
    /// 2. 디코딩이 성공하고 원래 값과 같다 (왕복)
    /// 3. **손상 시점의 fallback 값과 다르다**
    ///
    /// 3번이 핵심이다. 처음엔 1·2번(왕복)만으로 충분하다고 생각했는데 **틀렸다** —
    /// fallback인 `[]`도 왕복에 성공하므로, 이 조건만으로는 "손상 원본을 조용히
    /// 덮어쓴다"(P0-3이 막으려던 것)를 막지 못한다. 테스트가 실제로 이 결함을 잡았다.
    /// 값의 **출처**를 추적해야 구별할 수 있다. (`corruptedBlobFallbackBytes`)
    ///
    /// 알려진 한계: 사용자가 의도적으로 그 값을 fallback과 같은 값(빈 배열 등)으로
    /// 만들면 잠금이 유지된다. 안전 쪽으로 실패하는 선택이며, 빈 값 저장이 필요한
    /// 경우는 드물다. 잠금을 강제로 푸는 경로는 **두지 않는다** — 원본을 지우는
    /// 유일한 방법이 되어 버리면 P0-3이 무의미해진다.
    ///
    /// - Parameter apply: 조건을 모두 만족했을 때만 호출해 blob을 덮어쓴다
    private func tryRecoverBlob<T: Codable & Equatable>(
        _ value: T,
        column: StoreBlobColumn,
        id: UUID,
        apply: (Data) -> Void
    ) {
        let data = StoreCoding.encode(value, label: "blob 복구 시도 (\(column.rawValue))")
        guard !data.isEmpty else { return }
        guard let roundTrip = try? JSONDecoder().decode(T.self, from: data), roundTrip == value else {
            Logger.info("ConfigStore", "[SHORTCUT] blob 잠금 유지: \(column.rawValue) (왕복 불일치)")
            return
        }
        // 조건 3 — 아직 손상 직후의 fallback 값이면 "바뀐 게 없다"
        if let fallback = corruptedBlobFallbackBytes[id]?[column], fallback == data {
            Logger.info("ConfigStore", "[SHORTCUT] blob 잠금 유지: \(column.rawValue) (손상 시점 fallback과 동일 — 사용자 변경 없음)")
            return
        }
        apply(data)
        corruptedShortcutBlobColumns[id]?.remove(column)
        corruptedBlobFallbackBytes[id]?[column] = nil
        if corruptedShortcutBlobColumns[id]?.isEmpty == true {
            corruptedShortcutBlobColumns.removeValue(forKey: id)
            corruptedBlobFallbackBytes.removeValue(forKey: id)
        }
        Logger.info("ConfigStore", "[SHORTCUT] blob 잠금 해제: \(column.rawValue) — 사용자 변경분으로 복구됨")
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
