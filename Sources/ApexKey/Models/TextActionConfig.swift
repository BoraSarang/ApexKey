import Foundation

/// 텍스트 액션 파라미터 — `step.actionParameters`에 JSON으로 저장된다 (E-MAC-TEXT-6001)
///
/// 설계 근거:
/// - 카탈로그에 노출된 11종 텍스트 액션은 전부 `planned` 상태였다. 그대로 두면
///   "정규식"을 고르고 빈 설정 창을 연 뒤 실행해야야 "미구현"을 알 수 있었다
/// - 파라미터는 `target`이 아니라 `actionParameters`에 넣었다. `target`은 한 줄뿐이라
///   "찾을 문자열 → 바꿀 문자열" 같은 2입력 액션을 표현할 수 없다.
///   `StopShortcutAction`(`E-MAC-UX-9003`)이 이미 확립한 패턴이다
/// - 모든 필드가 선택값이다. 관대 디코딩(`E-MAC-STORE-5008`)과 같은 이유로,
///   구 저장분에서 필드가 빠져도 디코딩이 실패하면 안 된다
struct TextActionConfig: Codable, Hashable {
    /// 주 입력 텍스트 (Magic Variable 해석 대상)
    var text: String?
    /// 찾을 문자열 또는 정규식 패턴
    var search: String?
    /// 치환 문자열
    var replacement: String?
    /// 결합·분리 구분자
    var separator: String?
    /// 개수 세기 단위
    var countUnit: CountUnit?
    /// 숫자 표기 방식
    var numberStyle: NumberStyle?
    /// 소수 자릿수 (0이면 정수)
    var decimals: Int?
    /// 천 단위 구분자 사용 여부
    var grouping: Bool?
    /// Base64 인코딩(true) / 디코딩(false)
    var decode: Bool?
    /// 해시 알고리즘
    var hashAlgorithm: DataActions.HashAlgorithm?
    /// 이항 수학 연산
    var mathOperation: DataActions.MathOperation?
    /// 대소문자 스타일
    var caseStyle: DataActions.CaseStyle?
    /// 정렬 순서
    var sortOrder: DataActions.SortOrder?
    /// 정렬 방식
    var sortMode: DataActions.SortMode?
    /// 접두사 (surroundText)
    var prefix: String?
    /// 접미사 (surroundText)
    var suffix: String?
    /// 날짜 형식 (dateFormatter)
    var dateFormat: String?
    /// 생성 개수 (uuid)
    var count: Int?

    /// 특정 액션에서 "이 필드가 반드시 있어야 한다"를 표현한다
    enum CountUnit: String, Codable, CaseIterable, Hashable {
        case characters   // 문자
        case words        // 단어
        case lines        // 줄
        case sentences    // 문장

        var displayName: String {
            switch self {
            case .characters: return "unit.characters".localized
            case .words: return "unit.words".localized
            case .lines: return "unit.lines".localized
            case .sentences: return "unit.sentences".localized
            }
        }
    }

    enum NumberStyle: String, Codable, CaseIterable, Hashable {
        case decimal     // 1234.5
        case percent     // 12.3%
        case currency    // ₩1,235 (로케일 통화기호)
        case scientific  // 1.23e+3
        case words       // 천오백...

        var displayName: String {
            switch self {
            case .decimal: return "style.decimal".localized
            case .percent: return "style.percent".localized
            case .currency: return "style.currency".localized
            case .scientific: return "style.scientific".localized
            case .words: return "style.words".localized
            }
        }
    }

    /// `actionParameters`에서 안전하게 복원 — 없으면 빈 설정
    static func decode(from data: Data?) -> TextActionConfig {
        guard let data, !data.isEmpty else { return TextActionConfig() }
        return (try? JSONDecoder().decode(TextActionConfig.self, from: data)) ?? TextActionConfig()
    }
}
