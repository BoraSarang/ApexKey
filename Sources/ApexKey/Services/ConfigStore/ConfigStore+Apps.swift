import Foundation
import SwiftData
import AppKit
import Combine

/// ConfigStore 영역 분할 (R-10) — 동일 클래스 extension, public API 동결.
extension ConfigStore {
    /// 디스크에서 지워진 앱을 목록·저장에서 자동 정리 (경로가 비어있지 않은데 파일이 없으면 제거)
    func pruneRemovedApps() {
        let nonexistent = apps.filter {
            !$0.path.isEmpty && !FileManager.default.fileExists(atPath: $0.path)
        }
        guard !nonexistent.isEmpty else { return }
        nonexistent.forEach { removeApp($0) }
        Logger.info("ConfigStore", "[APPS] 디스크에서 사라진 앱 \(nonexistent.count)개 자동 제거")
    }

    // MARK: - 앱 관리

    func addApp(_ app: AppItem) {
        guard let context = container?.mainContext else { return }
        context.insert(PersistedApp.from(app))
        saveContext(context)
        apps.append(app)
    }

    func addAppsFromInstalled() {
        let installed = AppFinder.installedApps(includesSystem: showSystemApps)
        let existingIDs = Set(apps.map { $0.bundleID })
        let new = installed.filter { !existingIDs.contains($0.bundleID) }
        guard let context = container?.mainContext else { return }
        new.forEach { context.insert(PersistedApp.from($0)) }
        saveContext(context)
        apps.append(contentsOf: new)
    }

    /// 시스템 앱(`/System/`)이 저장 목록에 없으면 스캔해 추가 — 시스템 앱 표시 토글을 켤 때 호출
    func addSystemAppsIfMissing() {
        let installed = AppFinder.installedApps(includesSystem: true)
            .filter { $0.path.hasPrefix("/System/") }
        let existingIDs = Set(apps.map { $0.bundleID })
        let new = installed.filter { !existingIDs.contains($0.bundleID) }
        guard !new.isEmpty, let context = container?.mainContext else { return }
        new.forEach { context.insert(PersistedApp.from($0)) }
        saveContext(context)
        apps.append(contentsOf: new)
    }

    func toggleHidden(_ app: AppItem) {
        guard let idx = apps.firstIndex(where: { $0.id == app.id }) else { return }
        let updated = AppItem(
            id: app.id, name: app.name, bundleID: app.bundleID, path: app.path,
            category: app.category, isHidden: !app.isHidden
        )
        apps[idx] = updated
        syncApp(updated)
    }

    /// 앱 제거 — 연관 바인딩·핫키까지 정리한다.
    ///
    /// E-MAC-STORE-5007: 이전에는 앱 항목만 지우고 `target == app.bundleID`인 바인딩과
    /// 등록된 Carbon 핫키를 남겼다. `pruneRemovedApps()`가 **매 실행** 호출되므로
    /// 경로가 사라진 앱(외장드라이브 뽑기, 앱 경로 변경 등)이면 앱은 목록에서 사라지는데
    /// 고아 핫키는 `registerAllBindings()`로 매번 재등록되어 죽은 bundleID로 실행을 시도했다.
    func removeApp(_ app: AppItem) {
        // 1) 대상 앱의 바인딩 + 핫키 정리
        let orphans = bindings.filter { $0.target == app.bundleID }
        for orphan in orphans {
            Logger.info("ConfigStore", "[APPS] 앱 제거로 바인딩 정리: \(orphan.title) (\(orphan.combo.displayString))")
            removeBinding(orphan)
        }
        // 2) 워크플로우 단계가 이 앱을 참조하는 경우는 건드리지 않는다 —
        //    사용자 입력이 조용히 사라지면 안 되므로 별도 과제로 남긴다.
        // 3) 앱 항목 제거
        apps.removeAll { $0.id == app.id }
        guard let context = container?.mainContext else { return }
        let fetch = FetchDescriptor<PersistedApp>(predicate: #Predicate { $0.id == app.id })
        if let found = fetchContext(context, fetch).first {
            context.delete(found)
        }
        saveContext(context)
    }

    func syncApp(_ app: AppItem) {
        guard let context = container?.mainContext else { return }
        let fetch = FetchDescriptor<PersistedApp>(predicate: #Predicate { $0.id == app.id })
        if let found = fetchContext(context, fetch).first {
            found.name = app.name
            found.isHidden = app.isHidden
            found.categoryRaw = app.category.rawValue
            found.path = app.path
        }
        saveContext(context)
    }

    func visibleApps() -> [AppItem] {
        var result: [AppItem]
        if showHiddenApps {
            result = apps
        } else {
            result = apps.filter { !$0.isHidden }
        }
        if !showSystemApps {
            result = result.filter { !$0.path.hasPrefix("/System/") }
        }
        return result
    }

    func categoryOrder() -> [AppCategory] {
        AppCategory.allCases
    }

    /// 카테고리별 그룹핑된 파생 뷰 모델
    func appsByCategory() -> [(category: AppCategory, apps: [AppItem])] {
        categoryOrder().compactMap { cat in
            let list = visibleApps().filter { $0.category == cat }
            return list.isEmpty ? nil : (cat, list)
        }
    }

    /// 사용자가 카테고리를 직접 변경 (수동 플래그를 세워 재분류 시 보존)
    func updateCategory(for appID: UUID, to category: AppCategory) {
        guard let idx = apps.firstIndex(where: { $0.id == appID }) else { return }
        apps[idx].category = category
        apps[idx].categoryManuallySet = true
        guard let context = container?.mainContext else { return }
        let fetch = FetchDescriptor<PersistedApp>()
        let list = fetchContext(context, fetch)
        guard let persisted = list.first(where: { $0.id == appID }) else { return }
        persisted.categoryRaw = category.rawValue
        persisted.categoryManuallySet = true
        saveContext(context)
        Logger.info("ConfigStore", "[APPS] 카테고리 수동 변경: \(persisted.name) → \(category.rawValue)")
    }

    /// 수동으로 바꾼 앱을 제외한 나머지를 앱 메타데이터로 재분류
    func reclassifyCategories() {
        guard let context = container?.mainContext else { return }
        var changed = false
        for i in apps.indices where !apps[i].categoryManuallySet {
            let category = AppFinder.categorize(path: apps[i].path)
            if category != apps[i].category {
                apps[i].category = category
                changed = true
            }
        }
        guard changed else {
            Logger.info("ConfigStore", "[APPS] 재분류: 변경된 앱 없음")
            return
        }
        let fetch = FetchDescriptor<PersistedApp>()
        let persistedList = fetchContext(context, fetch)
        for persisted in persistedList where !(persisted.categoryManuallySet ?? false) {
            if let app = apps.first(where: { $0.id == persisted.id }) {
                persisted.categoryRaw = app.category.rawValue
            }
        }
        saveContext(context)
        Logger.info("ConfigStore", "[APPS] 카테고리 재분류 완료")
    }
}
