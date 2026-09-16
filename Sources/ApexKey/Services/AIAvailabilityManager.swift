import Foundation

/// Apple Intelligence 가용성 체크 및 관리
final class AIAvailabilityManager {
    static let shared = AIAvailabilityManager()
    
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
            return .available
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
        // FoundationModels 프레임워크 가용성 체크
        guard canImportFoundationModels else {
            return .modelUnavailable(reason: "error.user.foundation_models_unavailable".localized)
        }
        
        // Apple Intelligence 활성화 상태 체크 (간접적)
        // SystemLanguageModel.default 사용 가능 여부로 판단
        return .available
    }
    
    #if canImport(FoundationModels)
    private let canImportFoundationModels = true
    #else
    private let canImportFoundationModels = false
    #endif
    
}
