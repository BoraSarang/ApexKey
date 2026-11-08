import Foundation
import AppKit

/// 트랙패드 규칙 저장 — SwiftData 스키마를 건드리지 않고 UserDefaults(JSON)로 격리한다.
///
/// 이유: 트랙패드는 v0.33의 **실험적 모듈**이다. 모델을 SwiftData에 넣으면
/// 스키마 버전·마이그레이션 계획(`ConfigMigrationPlan`)을 함께 올려야 하고,
/// 기능을 접을 때 되돌리기 어렵다. 규칙은 작은 값 묶음이라 JSON이면 충분하다.
extension ConfigStore {

    // MARK: - 로드

    func loadTrackpadState() {
        isLoadingTrackpad = true

        trackpadEnabled = defaults.bool(forKey: PrefKeys.trackpadEnabled)

        if let data = defaults.data(forKey: PrefKeys.trackpadSliders),
           let rules = try? JSONDecoder().decode([EdgeSliderRule].self, from: data) {
            trackpadSliders = rules
        }
        if let data = defaults.data(forKey: PrefKeys.trackpadGestures),
           let rules = try? JSONDecoder().decode([GestureRule].self, from: data) {
            trackpadGestures = rules
        }

        // 첫 실행 — 기본 규칙 1개(오른쪽 에지 · 두 손가락 · 볼륨)를 넣어 둔다.
        // 사용자가 지우면 다시 넣지 않는다(플래그).
        let needsSeed = trackpadSliders.isEmpty && !defaults.bool(forKey: PrefKeys.trackpadDidSeed)
        if needsSeed {
            trackpadSliders = [EdgeSliderRule()]
            defaults.set(true, forKey: PrefKeys.trackpadDidSeed)
        }

        // 로드 중 저장을 막았으므로(무한 되쓰기 방지) 시드는 여기서 한 번 명시적으로 저장한다.
        // 이 줄이 없으면 앱을 껐다 켤 때 기본 규칙이 사라진다(플래그만 남아 재시드도 안 됨).
        isLoadingTrackpad = false
        if needsSeed {
            saveTrackpadSliders()
        }
    }

    // MARK: - 저장

    func saveTrackpadSliders() {
        guard !isLoadingTrackpad else { return }
        if let data = try? JSONEncoder().encode(trackpadSliders) {
            defaults.set(data, forKey: PrefKeys.trackpadSliders)
        }
    }

    func saveTrackpadGestures() {
        guard !isLoadingTrackpad else { return }
        if let data = try? JSONEncoder().encode(trackpadGestures) {
            defaults.set(data, forKey: PrefKeys.trackpadGestures)
        }
    }

    // MARK: - 편집

    func setTrackpadEnabled(_ enabled: Bool) {
        guard trackpadEnabled != enabled else { return }
        trackpadEnabled = enabled
        Logger.info("ConfigStore", "[TPAD] 마스터 토글: \(enabled ? "켜짐" : "꺼짐")")
    }

    func upsertTrackpadSlider(_ rule: EdgeSliderRule) {
        if let index = trackpadSliders.firstIndex(where: { $0.id == rule.id }) {
            trackpadSliders[index] = rule
        } else {
            trackpadSliders.append(rule)
        }
    }

    func removeTrackpadSlider(id: UUID) {
        trackpadSliders.removeAll { $0.id == id }
    }

    func upsertTrackpadGesture(_ rule: GestureRule) {
        if let index = trackpadGestures.firstIndex(where: { $0.id == rule.id }) {
            trackpadGestures[index] = rule
        } else {
            trackpadGestures.append(rule)
        }
    }

    func removeTrackpadGesture(id: UUID) {
        trackpadGestures.removeAll { $0.id == id }
    }

    /// 규칙 0개 → 기본 규칙 1개 만들기
    func createDefaultTrackpadSlider() {
        upsertTrackpadSlider(EdgeSliderRule())
    }

    // MARK: - 표시용 이름 해석

    /// 제스처 실행 대상의 사람이 읽는 이름 ("터미널에서 열기", "Safari · 보기 › 번역 › 한국어로 번역")
    func trackpadActionName(_ action: GestureAction) -> String {
        switch action.kind {
        case .workflow:
            guard let id = action.shortcutID else { return "trackpad.action.none".localized }
            return shortcuts.first(where: { $0.id == id })?.name ?? "trackpad.action.missing".localized
        case .hotkey:
            guard let id = action.bindingID else { return "trackpad.action.none".localized }
            guard let binding = bindings.first(where: { $0.id == id }) else {
                return "trackpad.action.missing".localized
            }
            let label = binding.combo.displayString
            return label.isEmpty ? binding.title : label
        case .menu:
            let appName = action.menuBundleID.flatMap(Self.appName(for:)) ?? "?"
            let path = action.menuPath.isEmpty
                ? (action.menuTitle ?? "trackpad.action.missing".localized)
                : action.menuPath.joined(separator: " › ")
            return "\(appName) · \(path)"
        case .system:
            return action.systemAction?.displayName ?? "trackpad.action.missing".localized
        }
    }

    /// 번들ID → 앱 표시 이름 (실행 중이 아니면 설치 경로에서 조회)
    static func appName(for bundleID: String) -> String? {
        if let running = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleID }),
           let name = running.localizedName {
            return name
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return FileManager.default.displayName(atPath: url.path)
        }
        return nil
    }

    /// 실행 중인 앱 목록 — 메뉴 항목 실행 대상 선택용
    func runningAppsForMenuPicker() -> [AppItem] {
        let running = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
        return running.map {
            AppItem(
                name: $0.localizedName ?? $0.bundleIdentifier ?? "",
                bundleID: $0.bundleIdentifier ?? "",
                path: $0.bundleURL?.path ?? ""
            )
        }
    }
}
