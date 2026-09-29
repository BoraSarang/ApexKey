import Foundation

/// Apple Intelligence 가용성 체크 및 관리.
///
/// **현재 상태 (PLAN_v0.21 T-143)**: FoundationModels 프레임워크와의 실제 연동이 **구현되지 않았다**.
/// 따라서 `isAvailable`은 어떤 기기에서도 `.available`을 반환하지 않는다.
/// 이전 구현은 macOS 26 이상이면 무조건 `.available`을 반환해, Apple Intelligence가 꺼진 기기에서도
/// "사용 가능"로 표시된 뒤 스텁 실행기가 **거짓 성공**을 반환했다.
final class AIAvailabilityManager {
    static let shared = AIAvailabilityManager()

    /// FoundationModels 연동 미구현 사유 (사용자 안내용)
    static let notImplementedReasonKey = "ai.error_not_implemented"

    /// 현재 시스템의 Apple Intelligence 가용 상태
    var currentAvailability: AIAvailability {
        if #available(macOS 26.0, *) {
            return checkAvailability_macOS26()
        } else {
            return .unsupportedOS(requiredVersion: "macOS 26.0")
        }
    }

    /// 특정 모델 타입이 사용 가능한지 체크
    func isAvailable(_ modelType: AIModelType) -> AIAvailability {
        switch modelType {
        case .askEachTime:
            // "실행 시 선택"은 선택 UI가 구현되지 않아 정상 동작할 수 없다.
            // 이전 구현은 무조건 `.available`을 반환했다.
            return .modelUnavailable(reason: Self.notImplementedReasonKey.localized)
        case .onDevice, .privateCloud, .chatGPT:
            return currentAvailability
        }
    }

    /// 모든 모델 타입의 가용성 맵
    var availabilityMap: [AIModelType: AIAvailability] {
        var map: [AIModelType: AIAvailability] = [:]
        for type in AIModelType.allCases {
            map[type] = isAvailable(type)
        }
        return map
    }

    // MARK: - macOS 26+ 체크

    @available(macOS 26.0, *)
    private func checkAvailability_macOS26() -> AIAvailability {
        // TODO(PLAN_v0.21 T-143 후속): FoundationModels 실연동 시 SystemLanguageModel.default
        // 생성 가능 여부로 실제 가용성을 판정한다.
        // 지금은 프레임워크 임포트 여부로도 판단하지 않는다 —
        // `#if canImport`는 컴파일 시 결정되는 상수라 특정 빌드에서 분기가 도달 불가해진다.
        return .modelUnavailable(reason: Self.notImplementedReasonKey.localized)
    }
}
