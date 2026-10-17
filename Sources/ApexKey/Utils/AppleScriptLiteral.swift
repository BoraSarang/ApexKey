import Foundation

/// AppleScript 문자열 리터럴 인용 — 단일 출처.
///
/// **왜 필요한가**: 경로·메뉴 제목 같은 비신뢰 문자열을 스크립트 소스에 그대로 넣으면
/// `"` 하나로 스크립트가 깨지거나(실패) 다른 구문이 실행된다. 셸 경로에는
/// `ShellEnvironment.literal`이 있지만 AppleScript 경로의 대응은 `MenuEnumerator`의
/// private 함수 하나뿐이었다(중복 위험). 여기로 모은다.
///
/// **규칙**: `\` → `\\`, `"` → `\"`, 앞뒤를 `"` 로 감싼다.
/// 셸 인용(`'...'`)과 **별개 계층**이다 — 둘 다 필요하면 셸 인용을 먼저 하고 그 결과를 감싼다.
enum AppleScriptLiteral {
    static func quoted(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}
