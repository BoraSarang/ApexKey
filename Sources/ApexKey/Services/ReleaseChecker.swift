import Foundation

/// GitHub Releases 기반 업데이트 확인 (macos-app-update 가이드 이식)
/// 인앱 자동 설치는 하지 않고, 새 버전 안내 + 릴리스 페이지 이동만 담당한다.
public struct GitHubRelease: Codable, Sendable, Equatable {
    public let tagName: String
    public let htmlURL: String
    public let name: String?
    public let body: String?

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case name
        case body
    }
}

/// 릴리스 조회 실패 원인 — 404(릴리스 0개)는 별도 케이스로 구분한다.
public enum ReleaseCheckError: Error, Equatable, Sendable {
    case noPublishedRelease
    case fetchFailed
    case invalidResponse
    case decodeFailed
}

public enum ReleaseChecker {
    public static let repository = "BoraSarang/ApexKey"

    /// 현재 번들 버전 (CFBundleShortVersionString)
    public static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    /// 최신 릴리스 조회 — 릴리스가 하나도 없으면 404이므로 전용 에러로 구분한다.
    public static func fetchLatest() async throws -> GitHubRelease {
        guard let url = URL(string: "https://api.github.com/repos/\(repository)/releases/latest") else {
            throw ReleaseCheckError.invalidResponse
        }
        var request = URLRequest(url: url)
        // User-Agent에 버전을 하드코딩하지 않고 번들에서 읽는다 (가이드 실패6 회피).
        request.setValue("ApexKey/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            Logger.error("E-MAC-UPDATE-8001", "릴리스 조회 네트워크 실패: \(error.localizedDescription)")
            throw ReleaseCheckError.fetchFailed
        }
        guard let http = response as? HTTPURLResponse else {
            throw ReleaseCheckError.invalidResponse
        }
        if http.statusCode == 404 {
            throw ReleaseCheckError.noPublishedRelease
        }
        guard (200...299).contains(http.statusCode) else {
            Logger.error("E-MAC-UPDATE-8002", "릴리스 조회 HTTP 실패: \(http.statusCode)")
            throw ReleaseCheckError.fetchFailed
        }
        do {
            return try JSONDecoder().decode(GitHubRelease.self, from: data)
        } catch {
            Logger.error("E-MAC-UPDATE-8003", "릴리스 응답 디코딩 실패: \(error.localizedDescription)")
            throw ReleaseCheckError.decodeFailed
        }
    }

    /// 순수 버전 비교 — 선행 "v" 제거 후 숫자 세그먼트 비교 ("1.10" > "1.9").
    /// 네트워크 없이 단위테스트 가능하다.
    public static func isNewer(latest: String, current: String) -> Bool {
        compareVersions(normalize(latest), normalize(current)) == .orderedDescending
    }

    /// 현재 버전보다 최신 릴리스가 있으면 해당 릴리스 반환, 아니면 nil.
    public static func checkForUpdate(current: String = currentVersion) async throws -> GitHubRelease? {
        let release = try await fetchLatest()
        return isNewer(latest: release.tagName, current: current) ? release : nil
    }

    // MARK: - 내부 헬퍼

    static func normalize(_ version: String) -> [Int] {
        var v = version.trimmingCharacters(in: .whitespacesAndNewlines)
        if v.hasPrefix("v") || v.hasPrefix("V") {
            v = String(v.dropFirst())
        }
        // 빌드 메타데이터(+...)·프리릴리스(-...) 접미사는 비교에서 제외한다.
        let core = v.split(separator: "+", maxSplits: 1).first.map(String.init) ?? v
        let numeric = core.split(separator: "-", maxSplits: 1).first.map(String.init) ?? core
        return numeric.split(separator: ".").map { Int($0) ?? 0 }
    }

    private static func compareVersions(_ lhs: [Int], _ rhs: [Int]) -> ComparisonResult {
        let count = max(lhs.count, rhs.count)
        for i in 0..<count {
            let l = i < lhs.count ? lhs[i] : 0
            let r = i < rhs.count ? rhs[i] : 0
            if l < r { return .orderedAscending }
            if l > r { return .orderedDescending }
        }
        return .orderedSame
    }
}
