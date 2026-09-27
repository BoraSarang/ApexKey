import Foundation

/// 셸 실행 환경 — GUI 앱의 최소 PATH를 보완하는 단일 출처.
/// adb(Homebrew/Android SDK) 탐색 경로가 드리프트하지 않도록 여기서만 정의한다.
enum ShellEnvironment {
    /// 시스템 기본 PATH 폴백 (단일 출처 — ActionExecutor env 폴백과 공유)
    static let fallbackSystemPaths = "/usr/bin:/bin:/usr/sbin:/sbin"

    /// Homebrew + Android SDK platform-tools 추가 경로 (PATH export와 단일 출처)
    static func extraPaths(home: String? = nil) -> String {
        let h = home ?? FileManager.default.homeDirectoryForCurrentUser.path
        return "/opt/homebrew/bin:/usr/local/bin:\(h)/Library/Android/sdk/platform-tools:\(h)/Android/Sdk/platform-tools"
    }

    /// Homebrew + Android SDK platform-tools를 포함한 PATH export 문
    static var pathExport: String {
        "export PATH=\"\(extraPaths()):\(fallbackSystemPaths):$PATH\""
    }

    /// 명령 앞에 PATH 보완을 붙인 전체 스크립트
    static func script(_ command: String) -> String {
        "\(pathExport)\n\(command)"
    }

    // MARK: - 셸 리터럴 인용 (E-MAC-SCRIPT-6004)

    /// 값을 POSIX 셸 단일 인용 리터럴로 변환한다.
    ///
    /// **왜 필요한가**: 셸 단계는 `VariableResolver`로 `{clipboard}`·`{lastResult}` 같은 토큰을
    /// 치환한 문자열을 `/bin/zsh -c`에 그대로 넘긴다. AppleScript 경로에는
    /// `MenuEnumerator.appleScriptQuoted` 이스케이프가 있는데 셸 경로에는 대응 처리가
    /// **아예 없었** — 비신뢰 값(클립보드 내용, 직전 AI/웹 결과)이 셸 메타문자 실행으로
    /// 이어질 수 있었다.
    ///
    /// **패턴**: `'` 로 감싸고 내부 `'` 만 `'\''` 로 이스케이프한다.
    /// 빈 문자열은 `''` 로 표현되어야 한다(아무것도 안 감싸면 인자가 사라져 인자 개수가 틀어진다).
    static func literal(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
