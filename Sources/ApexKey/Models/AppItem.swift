import Foundation

/// 등록된 앱 (카테고리, 표시, 숨김 상태)
struct AppItem: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var bundleID: String
    var path: String
    var category: AppCategory
    var isHidden: Bool = false

    init(
        id: UUID = UUID(),
        name: String,
        bundleID: String,
        path: String,
        category: AppCategory = .uncategorized,
        isHidden: Bool = false
    ) {
        self.id = id
        self.name = name
        self.bundleID = bundleID
        self.path = path
        self.category = category
        self.isHidden = isHidden
    }
}

enum AppCategory: String, Codable, CaseIterable, Identifiable {
    case browser
    case developer
    case productivity
    case communication
    case media
    case uncategorized

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .browser:       return "브라우저"
        case .developer:     return "개발"
        case .productivity:  return "생산성"
        case .communication: return "커뮤니케이션"
        case .media:         return "미디어"
        case .uncategorized: return "기타"
        }
    }
}
