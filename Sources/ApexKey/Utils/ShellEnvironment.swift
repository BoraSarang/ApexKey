import Foundation

/// 셸 실행 환경 — GUI 앱의 최소 PATH를 보완하는 단일 출처.
/// adb(Homebrew/Android SDK) 탐색 경로가 드리프트하지 않도록 여기서만 정의한다.
enum ShellEnvironment {
    /// Homebrew + Android SDK platform-tools를 포함한 PATH export 문
    static var pathExport: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "export PATH=\"/opt/homebrew/bin:/usr/local/bin:\(home)/Library/Android/sdk/platform-tools:\(home)/Android/Sdk/platform-tools:/usr/bin:/bin:/usr/sbin:/sbin:$PATH\""
    }

    /// 명령 앞에 PATH 보완을 붙인 전체 스크립트
    static func script(_ command: String) -> String {
        "\(pathExport)\n\(command)"
    }
}
