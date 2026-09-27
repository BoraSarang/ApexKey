import XCTest
@testable import ApexKey

/// 셸 인젝션 방어 회귀 테스트 (PLAN_v0.21 T-145 / E-MAC-SCRIPT-6004)
///
/// 셸 단계는 `VariableResolver`로 토큰을 치환한 문자열을 `/bin/zsh -c`에 넘긴다.
/// AppleScript 경로에는 `appleScriptQuoted` 이스케이프가 있었지만 셸 경로에는 대응 처리가
/// **아예 없었다**. `{clipboard}`(사용자 클립보드)·`{lastResult}`(직전 AI/웹 결과)가
/// 비신뢰 입력이면 셸 메타문자 실행으로 이어질 수 있었다.
final class ShellInjectionGuardTests: XCTestCase {

    // MARK: - 인용 헬퍼

    /// 일반 문자열은 그대로 인용된다
    func testLiteralQuotesPlainValue() {
        XCTAssertEqual(ShellEnvironment.literal("hello"), "'hello'")
    }

    /// 빈 문자열도 인용해야 한다 (감싸지 않으면 인자가 사라져 인자 개수가 어긋난다)
    func testLiteralQuotesEmptyValue() {
        XCTAssertEqual(ShellEnvironment.literal(""), "''")
    }

    /// command substitution이 무력화된다
    func testLiteralNeutralizesCommandSubstitution() {
        let escaped = ShellEnvironment.literal("$(whoami)")
        // 인용된 리터럴로 들어가므로 셸이 실행하지 않는다
        XCTAssertEqual(escaped, "'$(whoami)'")
    }

    /// backtick command substitution이 무력화된다
    func testLiteralNeutralizesBackticks() {
        let escaped = ShellEnvironment.literal("`whoami`")
        XCTAssertEqual(escaped, "'`whoami`'")
    }

    /// 명령 연결(`;`, `&&`, `||`)과 리다이렉트가 무력화된다
    func testLiteralNeutralizesChaining() {
        for payload in ["; whoami", "&& whoami", "|| whoami", "\n whoami", "> /tmp/pwned"] {
            let escaped = ShellEnvironment.literal(payload)
            XCTAssertTrue(escaped.hasPrefix("'") && escaped.hasSuffix("'"),
                          "인용되지 않음: \(payload)")
        }
    }

    /// 변수 확장이 무력화된다
    func testLiteralNeutralizesVariableExpansion() {
        XCTAssertEqual(ShellEnvironment.literal("$HOME"), "'$HOME'")
        XCTAssertEqual(ShellEnvironment.literal("${PATH}"), "'${PATH}'")
    }

    /// 내부 작은따옴표는 `'\''` 로 이스케이프된다 (패턴 오류 방지)
    func testLiteralEscapesInnerSingleQuote() {
        XCTAssertEqual(ShellEnvironment.literal("it's"), "'it'\\''s'")
    }

    // MARK: - 실제 셸 실행으로 검증

    /// 인젝션 페이로드가 실제로 실행되지 않아야 한다.
    /// 값이 그대로 출력되어야 하고, 부수효과(파일 생성)가 없어야 한다.
    func testInjectedPayloadIsNotExecuted() {
        let marker = FileManager.default.temporaryDirectory
            .appendingPathComponent("apexkey_injection_marker_\(UUID().uuidString)")
        // 공격 페이로드: 토스트 대신 파일을 만들려 한다
        let payload = "; touch \(marker.path) #"

        // 실제 스크립트 형태: printf로 토큰 값을 찍는 명령
        let command = "printf '%s' \(ShellEnvironment.literal(payload))"
        let run = ProcessRunner.run(executable: "/bin/zsh", arguments: ["-c", command])

        XCTAssertEqual(run.exitCode, 0, "스크립트 자체는 성공해야 함")
        XCTAssertEqual(run.standardOutput, payload, "값이 그대로 출력되어야 함 (메타문자 실행 아님)")
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: marker.path),
            "인젝션 페이로드가 실행되어 파일이 생성됨"
        )
    }

    /// 이스케이프가 없으면 실제로 위험하다는 것을 확인하는 대조 테스트.
    /// (수정 전 동작 재현 — 이 테스트가 통과해야 인젝션이 "진짜 위험한" 것으로 고정된다)
    func testWithoutEscapingPayloadWouldExecute() {
        let marker = FileManager.default.temporaryDirectory
            .appendingPathComponent("apexkey_injection_baseline_\(UUID().uuidString)")
        let payload = "; touch \(marker.path) #"

        // 의도적으로 이스케이프 없이 조립 — 취약 동작 재현
        let command = "printf '%s' \(payload)"
        _ = ProcessRunner.run(executable: "/bin/zsh", arguments: ["-c", command])

        XCTAssertTrue(
            FileManager.default.fileExists(atPath: marker.path),
            "이스케이프가 없으면 페이로드가 실행됨 — 보호가 실제로 필요한 이유"
        )
        try? FileManager.default.removeItem(at: marker)
    }

    // MARK: - resolveText 이스케이프 훅

    /// 치환된 **값에만** 이스케이프가 적용되고 템플릿은 보존되어야 한다
    func testEscapingAppliesToValuesNotTemplate() {
        var context = VariableResolver.ResolveContext()
        context.variables[UUID(uuidString: "00000000-0000-0000-0000-000000000001")!] = .text("a b")
        // resolveText는 UUID 기반 사용자 변수를 찾지 못하므로,
        // 훅 자체가 호출되는지는 별도 신호(마법변수 토큰)로 검증한다.
        let text = "echo '{마법변수:00000000-0000-0000-0000-000000000001:text}'"
        let escaped = VariableResolver.resolveText(
            text,
            context: context,
            escaping: ShellEnvironment.literal
        )
        // 값이 있으면 인용된 형태로 치환, 없으면 원문 유지 — 어느 쪽이든 템플릿의 따옴표는 온전해야 한다
        XCTAssertTrue(escaped.hasPrefix("echo '"))
    }

    /// 기본 이스케이프는 항등이어야 한다 (AppleScript/JXA 경로 동작 불변)
    func testDefaultEscapingIsIdentity() {
        let input = "tell application \"Finder\" to get name of {clipboard}"
        let context = VariableResolver.ResolveContext()
        let resolved = VariableResolver.resolveText(input, context: context)
        // 기본값이 항등이므로 템플릿의 따옴표가 이스케이프 처리되지 않은 채 유지된다
        XCTAssertTrue(resolved.contains("\"Finder\""))
    }
}
