import Foundation
import SwiftData
import AppKit
import Combine

/// ConfigStore 영역 분할 (R-10) — 동일 클래스 extension, public API 동결.
extension ConfigStore {
    // MARK: - 바인딩 관리

    func bindings(for appID: UUID) -> [HotKeyBinding] {
        // launchApp bindings 중 해당 앱 것을 반환 (target == bundleID)
        guard let app = apps.first(where: { $0.id == appID }) else { return [] }
        return bindings.filter { $0.target == app.bundleID }
    }

    /// 특정 앱의 "앱 실행/토글" 단축키 (launchApp 타입)
    func launchBindings(for appID: UUID) -> [HotKeyBinding] {
        guard let app = apps.first(where: { $0.id == appID }) else { return [] }
        return bindings.filter { $0.actionType == .launchApp && $0.target == app.bundleID }
    }

    /// 앱 실행/토글 단축키 추가/교체 (이미 있으면 첫 항목만 갱신)
    func setLaunchBinding(for appID: UUID, combo: HotKeyCombo) {
        guard !combo.isEmpty else { return }
        guard let app = apps.first(where: { $0.id == appID }) else { return }
        if let first = launchBindings(for: appID).first {
            let updated = HotKeyBinding(
                id: first.id,
                combo: combo,
                actionType: .launchApp,
                target: app.bundleID,
                title: app.name,
                onlyWhenAppActive: false
            )
            removeBinding(first)
            addBinding(updated)
        } else {
            addBinding(HotKeyBinding(
                combo: combo,
                actionType: .launchApp,
                target: app.bundleID,
                title: app.name,
                onlyWhenAppActive: false
            ))
        }
    }

    func addBinding(_ binding: HotKeyBinding) {
        // 중복 조합 체크
        if isDuplicate(combo: binding.combo, excluding: binding.id) {
            Logger.info("ConfigStore", "중복 단축키 무시: \(binding.combo.displayString)")
            return
        }
        guard let context = container?.mainContext else { return }
        context.insert(PersistedBinding.from(binding))
        saveContext(context)
        bindings.append(binding)
        _ = hotKeyService.register(binding.id, combo: binding.combo)
    }

    func removeBinding(_ binding: HotKeyBinding) {
        bindings.removeAll { $0.id == binding.id }
        hotKeyService.unregister(binding.id)
        guard let context = container?.mainContext else { return }
        let fetch = FetchDescriptor<PersistedBinding>(predicate: #Predicate { $0.id == binding.id })
        if let found = fetchContext(context, fetch).first {
            context.delete(found)
        }
        saveContext(context)
    }

    /// 단축키 중복 감지 (다른 binding/단축어 + 예약 핫키와 충돌)
    func isDuplicate(combo: HotKeyCombo, excluding id: UUID) -> Bool {
        guard !combo.isEmpty else { return false }
        let bindingConflict = bindings.contains { $0.id != id && $0.combo.matches(combo) }
        if bindingConflict { return true }
        if shortcuts.contains(where: { $0.id != id && $0.combo.matches(combo) }) { return true }
        // 예약 핫키 (패널 토글/팔레트/HUD/반복) 포함
        let reserved: [(UUID, HotKeyCombo)] = [
            (panelToggleID, toggleHotkey),
            (paletteID, paletteHotkey),
            (menuHUDID, menuHUDHotkey),
            (repeatLastID, Self.defaultRepeatHotkey),
        ]
        return reserved.contains { $0.0 != id && $0.1.matches(combo) }
    }

    /// 이름으로 바인딩 검색 (부분 매칭 + 한글 초성 매칭)
    func binding(matching query: String) -> [HotKeyBinding] {
        let q = query.lowercased()
        return bindings.filter {
            KoreanSearch.matches(query: q, in: $0.title)
                || KoreanSearch.matches(query: q, in: $0.actionType.displayName)
                || $0.combo.displayString.lowercased().contains(q)
        }.sorted { $0.title < $1.title }
    }

    /// 앱이 주어진 검색어와 매칭되는지 (앱 목록/메인 검색 공용)
    /// - 앱 이름: 초성+일반 매칭
    /// - 번들ID: 일반 substring 매칭
    /// - 설정된 글로벌 단축키 조합: 일반 substring 매칭
    func appMatchesSearch(_ app: AppItem, query: String) -> Bool {
        let q = query.lowercased()
        return KoreanSearch.matches(query: q, in: app.name)
            || app.bundleID.lowercased().contains(q)
            || bindings(for: app.id).contains { $0.combo.displayString.lowercased().contains(q) }
    }

    /// 바인딩 복제
    func duplicate(_ binding: HotKeyBinding) {
        let newBinding = HotKeyBinding(
            id: UUID(),
            combo: binding.combo,
            actionType: binding.actionType,
            target: binding.target,
            title: "ui.binding.duplicate_fmt".localizedFormat(binding.title),
            onlyWhenAppActive: binding.onlyWhenAppActive
        )
        addBinding(newBinding)
        Logger.info("ConfigStore", "바인딩 복제: \(binding.title) → \(newBinding.title)")
    }

    /// 바인딩 순서 이동 (위/아래)
    func moveBinding(_ binding: HotKeyBinding, direction: MoveDirection) {
        guard let idx = bindings.firstIndex(where: { $0.id == binding.id }) else { return }
        let targetIdx: Int
        switch direction {
        case .up: targetIdx = idx - 1
        case .down: targetIdx = idx + 1
        }
        guard targetIdx >= 0, targetIdx < bindings.count else { return }
        bindings.swapAt(idx, targetIdx)
        Logger.info("ConfigStore", "바인딩 순서 이동: \(binding.title)")
    }
}
