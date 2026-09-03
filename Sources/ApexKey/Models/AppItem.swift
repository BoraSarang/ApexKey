import Foundation

/// 등록된 앱 (카테고리, 표시, 숨김 상태)
struct AppItem: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var bundleID: String
    var path: String
    var category: AppCategory
    var isHidden: Bool = false
    /// 사용자가 카테고리를 수동으로 바꿨는지 여부 — 재분류 시 보존
    var categoryManuallySet: Bool = false

    init(
        id: UUID = UUID(),
        name: String,
        bundleID: String,
        path: String,
        category: AppCategory = .uncategorized,
        isHidden: Bool = false,
        categoryManuallySet: Bool = false
    ) {
        self.id = id
        self.name = name
        self.bundleID = bundleID
        self.path = path
        self.category = category
        self.isHidden = isHidden
        self.categoryManuallySet = categoryManuallySet
    }
}

enum AppCategory: String, Codable, CaseIterable, Identifiable {
    case productivity
    case utilities
    case photoVideo
    case games
    case business
    case education
    case music
    case socialNetworking
    case uncategorized

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .productivity:     return "생산성"
        case .utilities:        return "유틸리티"
        case .photoVideo:       return "사진 및 비디오"
        case .games:            return "게임"
        case .business:         return "비즈니스"
        case .education:        return "교육"
        case .music:            return "음악"
        case .socialNetworking: return "소셜 네트워킹"
        case .uncategorized:    return "기타"
        }
    }

    var symbolName: String {
        switch self {
        case .productivity:     return "checklist"
        case .utilities:        return "wrench.and.screwdriver"
        case .photoVideo:       return "camera"
        case .games:            return "gamecontroller"
        case .business:         return "briefcase"
        case .education:        return "graduationcap"
        case .music:            return "music.note"
        case .socialNetworking: return "bubble.left.and.bubble.right"
        case .uncategorized:    return "square.grid.3x3"
        }
    }

    /// 기존 6개 카테고리 체계에서 자동 이관용 매핑 (구 저장값 → 신규)
    static func migrate(_ legacyRaw: String) -> AppCategory {
        switch legacyRaw {
        case "browser":        return .utilities        // App Store상 브라우저는 유틸리티
        case "developer":      return .uncategorized    // 신규 메인에 개발자 도구 없음
        case "productivity":   return .productivity
        case "communication":  return .socialNetworking
        case "media":          return .photoVideo
        case "utilities":      return .utilities
        case "photoVideo":     return .photoVideo
        case "games":          return .games
        case "business":       return .business
        case "education":      return .education
        case "music":          return .music
        case "socialNetworking": return .socialNetworking
        default:               return .uncategorized
        }
    }
}
