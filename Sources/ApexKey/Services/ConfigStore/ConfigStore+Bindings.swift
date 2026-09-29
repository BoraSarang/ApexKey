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
    ///
    /// E-MAC-HTKEY-1003: 기존 구현은 `removeBinding(first)` **후** `addBinding`을 호출했다.
    /// `addBinding`이 중복 조합이면 조용히 `return`하므로, 교체 시도가 실패하면
    /// **작동하던 핫키만 사라진 상태**가 남았다(무음). 이제 삭제 **전**에 중복을 확인한다.
    @discardableResult
    func setLaunchBinding(for appID: UUID, combo: HotKeyCombo) -> HotKeyApplyResult {
        guard !combo.isEmpty else { return .invalidCombo }
        guard let app = apps.first(where: { $0.id == appID }) else { return .appNotFound }
        let existing = launchBindings(for: appID).first
        // 기존 항목은 자기 자신이므로 중복 검사에서 제외하고, 교체 전에 미리 검증한다.
        if isDuplicate(combo: combo, excluding: existing?.id ?? UUID()) {
            Logger.error("E-MAC-HTKEY-1003", "앱 실행 단축키 교체 실패 — 중복 조합: \(combo.displayString) (기존 핫키 유지)")
            return .duplicateCombo
        }
        if let first = existing {
            let updated = HotKeyBinding(
                id: first.id,
                combo: combo,
                actionType: .launchApp,
                target: app.bundleID,
                title: app.name,
                onlyWhenAppActive: false
            )
            removeBinding(first)
            return addBinding(updated)
        }
        return addBinding(HotKeyBinding(
            combo: combo,
            actionType: .launchApp,
            target: app.bundleID,
            title: app.name,
            onlyWhenAppActive: false
        ))
    }

    @discardableResult
    func addBinding(_ binding: HotKeyBinding) -> HotKeyApplyResult {
        // 중복 조합 체크 — 조용히 무시하지 않고 호출부에 통지한다
        if isDuplicate(combo: binding.combo, excluding: binding.id) {
            Logger.error("E-MAC-HTKEY-1003", "중복 단축키 — 추가 거부: \(binding.combo.displayString)")
            return .duplicateCombo
        }
        guard !binding.combo.isEmpty else {
            Logger.error("E-MAC-HTKEY-1003", "빈 단축키 — 추가 거부")
            return .invalidCombo
        }
        guard let context = container?.mainContext else {
            Logger.error("E-MAC-STORE-5001", "저소 사용 불가 — 바인딩 추가 실패")
            return .storeUnavailable
        }
        context.insert(PersistedBinding.from(binding))
        saveContext(context)
        bindings.append(binding)
        guard hotKeyService.register(binding.id, combo: binding.combo) else {
            // 저장은 됐지만 OS 등록이 실패한 상태 — 사용자에게 알려야 한다
            Logger.error("E-MAC-HTKEY-1004", "Carbon 핫키 등록 실패 (OS 선점 가능): \(binding.combo.displayString)")
            return .hotKeyRegistrationFailed
        }
        return .applied
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

}
