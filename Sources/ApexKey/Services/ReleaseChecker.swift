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
    case rateLimited // 403/429
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
        if http.statusCode == 403 || http.statusCode == 429 {
            Logger.error("E-MAC-UPDATE-8002", "릴리스 조회 속도 제한: \(http.statusCode)")
            throw ReleaseCheckError.rateLimited
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

    /// SemVer 정확 비교 — 프리릴리스·빌드 메타 포함 (E-MAC-UX-9007).
    /// `isNewer`와 달리 프리릴리스 존재 여부를 반영한다 (1.0.0-beta < 1.0.0).
    public static func isNewerStrict(latest: String, current: String) -> Bool {
        let l = parseSemVer(latest)
        let r = parseSemVer(current)
        if l.core != r.core {
            return compareVersions(l.core, r.core) == .orderedDescending
        }
        return comparePrerelease(l.pre, r.pre) == .orderedDescending
    }

    static func parseSemVer(_ version: String) -> (core: [Int], pre: String?) {
        var v = version.trimmingCharacters(in: .whitespacesAndNewlines)
        if v.hasPrefix("v") || v.hasPrefix("V") { v = String(v.dropFirst()) }
        let coreAndMeta = v.split(separator: "+", maxSplits: 1)
        let coreAndPre = String(coreAndMeta[0]).split(separator: "-", maxSplits: 1)
        let core = coreAndPre[0].split(separator: ".").map { Int($0) ?? 0 }
        let pre = coreAndPre.count > 1 ? String(coreAndPre[1]) : nil
        return (core, pre)
    }

    /// 프리릴리스 비교 — 있음 < 없음, 동일이면 사전식 (SemVer §11.4)
    static func comparePrerelease(_ lhs: String?, _ rhs: String?) -> ComparisonResult {
        switch (lhs, rhs) {
        case (nil, nil): return .orderedSame
        case (nil, _): return .orderedDescending
        case (_, nil): return .orderedAscending
        case let (l?, r?): return l.compare(r)
        }
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
