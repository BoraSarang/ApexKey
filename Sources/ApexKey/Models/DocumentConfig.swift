import Foundation

/// 문서 앱 연동 — Pages·Numbers·TextEdit 파라미터 (T-216)
///
/// TextEdit은 스크립팅 사전으로 문서 생성·열기·본문 편집·글꼴/크기 지정이 가능하다.
/// Pages·Numbers는 이 기기에서 설치되어 있지 않아 사전을 실측할 수 없었다.
/// 따라서 **설치 여부를 먼저 확인**하고, 미설치면 "앱 미설치" 사유를 명확히 돌려준다.
/// 본문 편집·글꼴 지정은 TextEdit 전용이다(다른 앱은 `unsupportedApp`).
struct DocumentConfig: Codable, Hashable {

    enum App: String, Codable, CaseIterable, Hashable {
        case textEdit
        case pages
        case numbers
        /// 문서를 기본 앱으로 연다 (`viewDocument` 전용)
        case defaultApp

        var displayName: String {
            switch self {
            case .textEdit: return "doc.app.text_edit".localized
            case .pages: return "doc.app.pages".localized
            case .numbers: return "doc.app.numbers".localized
            case .defaultApp: return "doc.app.default".localized
            }
        }

        var bundleIdentifier: String? {
            switch self {
            case .textEdit: return "com.apple.TextEdit"
            case .pages: return "com.apple.iWork.Pages"
            case .numbers: return "com.apple.iWork.Numbers"
            case .defaultApp: return nil
            }
        }

        /// AppleScript의 `tell application "..."`에 쓰는 이름
        var scriptName: String? {
            switch self {
            case .textEdit: return "TextEdit"
            case .pages: return "Pages"
            case .numbers: return "Numbers"
            case .defaultApp: return nil
            }
        }
    }

    enum EditMode: String, Codable, CaseIterable, Hashable {
        case append
        case replace

        var displayName: String {
            switch self {
            case .append: return "doc.edit.append".localized
            case .replace: return "doc.edit.replace".localized
            }
        }
    }

    /// 대상 앱
    var app: App?
    /// 문서 경로 (`viewDocument`·`editDocument`·`setParagraphStyle`)
    var path: String?
    /// 새 문서 본문 또는 편집할 텍스트
    var content: String?
    /// 편집 방식 — 기본은 덧붙이기
    var editMode: EditMode?
    /// 글꼴 이름
    var fontName: String?
    /// 글꼴 크기
    var fontSize: Int?

    init(
        app: App? = nil,
        path: String? = nil,
        content: String? = nil,
        editMode: EditMode? = nil,
        fontName: String? = nil,
        fontSize: Int? = nil
    ) {
        self.app = app
        self.path = path
        self.content = content
        self.editMode = editMode
        self.fontName = fontName
        self.fontSize = fontSize
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.app = try c.decodeIfPresent(App.self, forKey: .app)
        self.path = try c.decodeIfPresent(String.self, forKey: .path)
        self.content = try c.decodeIfPresent(String.self, forKey: .content)
        self.editMode = try c.decodeIfPresent(EditMode.self, forKey: .editMode)
        self.fontName = try c.decodeIfPresent(String.self, forKey: .fontName)
        self.fontSize = try c.decodeIfPresent(Int.self, forKey: .fontSize)
    }

    static func decode(from data: Data?) -> DocumentConfig {
        guard let data, !data.isEmpty else { return DocumentConfig() }
        return (try? JSONDecoder().decode(DocumentConfig.self, from: data)) ?? DocumentConfig()
    }

    func encode() -> Data? {
        try? JSONEncoder().encode(self)
    }

    var resolvedApp: App { app ?? .textEdit }
    var resolvedEditMode: EditMode { editMode ?? .append }
    var resolvedFontSize: Int { fontSize ?? 0 }
}
