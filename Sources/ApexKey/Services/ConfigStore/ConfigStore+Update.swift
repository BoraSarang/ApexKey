import Foundation

/// ConfigStore 영역 분할 — 업데이트 확인 상태 + 주기 + 마지막 확인 시각.
/// Stored property는 본체(ConfigStore.swift)에 두고, 타입·로직만 extension에 둔다.
extension ConfigStore {
    /// 업데이트 확인 상태 (UI 표시용)
    enum UpdateState: Equatable, Sendable {
        case idle
        case checking
        case upToDate
        case updateAvailable(tag: String, htmlURL: String, notes: String)
        case unavailable(String)
    }

    /// 자동 확인 주기 — 기본값 weekly.
    enum UpdateCheckFrequency: String, CaseIterable, Identifiable, Sendable {
        case atLaunch
        case daily
        case weekly
        case never

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .atLaunch: return "update.frequency.at_launch".localized
            case .daily: return "update.frequency.daily".localized
            case .weekly: return "update.frequency.weekly".localized
            case .never: return "update.frequency.never".localized
            }
        }

        /// 확인 간격(초) — atLaunch는 실행 단위라 nil.
        var interval: TimeInterval? {
            switch self {
            case .atLaunch: return nil
            case .daily: return 86_400
            case .weekly: return 604_800
            case .never: return nil
            }
        }
    }

    /// 업데이트 있음 상태일 때 시트 표시용 릴리스 정보.
    var availableUpdate: GitHubRelease? {
        guard case let .updateAvailable(tag, htmlURL, notes) = updateState else { return nil }
        return GitHubRelease(tagName: tag, htmlURL: htmlURL, name: nil, body: notes.isEmpty ? nil : notes)
    }

    /// 주기에 따라 필요하면 확인한다. 앱 실행 시·패널 토글 시 호출 (조용히, 자동 팝업 없음).
    func maybeAutoCheckForUpdate() async {
        guard updateCheckFrequency != .never else { return }
        if case .checking = updateState { return }
        let now = Date()
        let due: Bool
        switch updateCheckFrequency {
        case .never:
            due = false
        case .atLaunch:
            due = updateCheckedAt.map { $0 < launchDate } ?? true
        case .daily, .weekly:
            guard let interval = updateCheckFrequency.interval else { due = false; break }
            due = updateCheckedAt.map { now.timeIntervalSince($0) >= interval } ?? true
        }
        guard due else { return }
        await checkForUpdate()
    }

    /// 즉시 확인 — 수동 진입점(설정·정보·메뉴바)에서 호출.
    /// 새 버전이면 true 반환 → 호출側에서 시트 자동 팝업.
    @discardableResult
    func checkForUpdate() async -> Bool {
        if case .checking = updateState { return false }
        updateState = .checking
        defer {
            // 마지막 확인 시각은 성공·실패 관계없이 영속화한다.
            // 메모리에만 두면 재실행마다 nil이라 주간/일간 설정이 무의미해진다.
            updateCheckedAt = Date()
        }
        do {
            let current = ReleaseChecker.currentVersion
            if let release = try await ReleaseChecker.checkForUpdate(current: current) {
                updateState = .updateAvailable(
                    tag: release.tagName,
                    htmlURL: release.htmlURL,
                    notes: release.body ?? ""
                )
                Logger.info("ConfigStore", "[UPDATE] 새 버전 발견: \(release.tagName) (현재 \(current))")
                return true
            }
            updateState = .upToDate
            Logger.info("ConfigStore", "[UPDATE] 최신 버전입니다 (현재 \(current))")
            return false
        } catch let error as ReleaseCheckError {
            switch error {
            case .noPublishedRelease:
                updateState = .unavailable("update.none_published")
            case .fetchFailed, .invalidResponse, .decodeFailed:
                updateState = .unavailable("update.fetch_failed")
            }
            Logger.error("E-MAC-UPDATE-8004", "업데이트 확인 실패: \(error)")
            return false
        } catch {
            updateState = .unavailable("update.fetch_failed")
            Logger.error("E-MAC-UPDATE-8005", "업데이트 확인 실패: \(error.localizedDescription)")
            return false
        }
    }
}
