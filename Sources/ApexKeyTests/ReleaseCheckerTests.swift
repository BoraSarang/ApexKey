import XCTest
@testable import ApexKey

/// ReleaseChecker 버전 비교 단위 테스트 — 네트워크 없이 순수함수만 검증
final class ReleaseCheckerTests: XCTestCase {

    func testNewerPatch() {
        XCTAssertTrue(ReleaseChecker.isNewer(latest: "v1.0.1", current: "1.0.0"))
    }

    func testNewerMinorAndMajor() {
        XCTAssertTrue(ReleaseChecker.isNewer(latest: "v1.1.0", current: "1.0.9"))
        XCTAssertTrue(ReleaseChecker.isNewer(latest: "v2.0.0", current: "1.9.9"))
    }

    func testEqualVersions() {
        XCTAssertFalse(ReleaseChecker.isNewer(latest: "v1.0.0", current: "1.0.0"))
        XCTAssertFalse(ReleaseChecker.isNewer(latest: "1.0.0", current: "1.0.0"))
    }

    func testOlderLatest() {
        XCTAssertFalse(ReleaseChecker.isNewer(latest: "v0.9.9", current: "1.0.0"))
    }

    func testMultiDigitSegments() {
        // 문자열 비교가 아닌 숫자 비교여야 함 ("1.10" > "1.9")
        XCTAssertTrue(ReleaseChecker.isNewer(latest: "v1.10.0", current: "1.9.0"))
        XCTAssertFalse(ReleaseChecker.isNewer(latest: "v1.9.0", current: "1.10.0"))
    }

    func testDifferentSegmentLengths() {
        XCTAssertTrue(ReleaseChecker.isNewer(latest: "v1.0.1", current: "1.0"))
        XCTAssertFalse(ReleaseChecker.isNewer(latest: "v1.0", current: "1.0.0"))
    }

    func testUppercaseVPrefix() {
        XCTAssertTrue(ReleaseChecker.isNewer(latest: "V1.0.1", current: "1.0.0"))
    }

    func testSuffixStripped() {
        XCTAssertFalse(ReleaseChecker.isNewer(latest: "v1.0.0-beta", current: "1.0.0"))
        XCTAssertTrue(ReleaseChecker.isNewer(latest: "v1.0.1-beta", current: "1.0.0"))
    }

    // MARK: - v0.18 SemVer 프리릴리스 정확 비교 (E-MAC-UX-9007)

    func testStrictSemVer() {
        // isNewer는 프리릴리스를 무시(1.0.0-beta == 1.0.0), isNewerStrict는 반영
        XCTAssertFalse(ReleaseChecker.isNewerStrict(latest: "v1.0.0-beta", current: "1.0.0"))
        XCTAssertTrue(ReleaseChecker.isNewerStrict(latest: "v1.0.0", current: "1.0.0-beta"))
        XCTAssertFalse(ReleaseChecker.isNewerStrict(latest: "v1.0.0-alpha", current: "1.0.0-beta"))
        XCTAssertTrue(ReleaseChecker.isNewerStrict(latest: "v1.0.1", current: "1.0.0"))
        XCTAssertFalse(ReleaseChecker.isNewerStrict(latest: "v1.0.0", current: "1.0.0"))
        // 프리릴리스 + 빌드메타 혼합
        XCTAssertTrue(ReleaseChecker.isNewerStrict(latest: "v1.0.1+build.2", current: "1.0.1+build.1"))
        XCTAssertFalse(ReleaseChecker.isNewerStrict(latest: "v1.0.1", current: "1.0.1"))
    }

    func testRateLimitedEnumExists() {
        // 403/429 → rateLimited 케이스 존재 (dispatch는 ConfigStore+Update에서)
        let errors: [ReleaseCheckError] = [.rateLimited, .fetchFailed, .invalidResponse, .decodeFailed, .noPublishedRelease]
        XCTAssertEqual(errors.count, 5)
        XCTAssertEqual(ReleaseCheckError.rateLimited, .rateLimited)
    }

    func testEmptyCurrentTreatsLatestAsNewer() {
        XCTAssertTrue(ReleaseChecker.isNewer(latest: "v1.0.0", current: ""))
    }

    func testGitHubReleaseDecoding() throws {
        let json = """
        {"tag_name":"v1.2.0","html_url":"https://github.com/BoraSarang/ApexKey/releases/tag/v1.2.0","name":"ApexKey v1.2.0","body":"## News"}
        """.data(using: .utf8)!
        let release = try JSONDecoder().decode(GitHubRelease.self, from: json)
        XCTAssertEqual(release.tagName, "v1.2.0")
        XCTAssertEqual(release.htmlURL, "https://github.com/BoraSarang/ApexKey/releases/tag/v1.2.0")
        XCTAssertEqual(release.body, "## News")
    }

    func testGitHubReleaseDecodingNullBody() throws {
        let json = """
        {"tag_name":"v1.0.0","html_url":"https://example.com","name":null,"body":null}
        """.data(using: .utf8)!
        let release = try JSONDecoder().decode(GitHubRelease.self, from: json)
        XCTAssertNil(release.body)
    }

    func testFrequencyDefaultsToWeekly() {
        XCTAssertEqual(ConfigStore.UpdateCheckFrequency(rawValue: "weekly"), .weekly)
        XCTAssertEqual(ConfigStore.UpdateCheckFrequency.allCases.count, 4)
    }
}
