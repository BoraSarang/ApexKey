import XCTest
@testable import ApexKey

/// R-20261121-01 — 앱 탐색 재귀 스캔.
///
/// `/Applications` 하위 폴더에 설치된 앱(예: `Adobe…/Photoshop.app`)을 찾는지,
/// 앱 번들 **내부**로는 들어가지 않는지 임시 디렉터리로 검증한다.
final class AppFinderTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppFinderTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let root { try? FileManager.default.removeItem(at: root) }
    }

    func testScanFindsAppsInNestedFolders() throws {
        let app = try makeApp(
            at: root.appendingPathComponent("Vendor/Product.app"),
            bundleID: "com.example.nested"
        )
        var apps: [AppItem] = []
        AppFinder.scan(root, depth: 2, into: &apps)
        XCTAssertEqual(apps.map(\.bundleID), ["com.example.nested"])
        XCTAssertEqual(
            apps.first.map { URL(fileURLWithPath: $0.path).resolvingSymlinksInPath().path },
            app.resolvingSymlinksInPath().path
        )
    }

    func testScanDoesNotDescendIntoAppBundles() throws {
        let outer = try makeApp(
            at: root.appendingPathComponent("Outer.app"),
            bundleID: "com.example.outer"
        )
        _ = try makeApp(
            at: outer.appendingPathComponent("Contents/Helpers/Helper.app"),
            bundleID: "com.example.helper"
        )
        var apps: [AppItem] = []
        AppFinder.scan(root, depth: 2, into: &apps)
        XCTAssertEqual(apps.map(\.bundleID), ["com.example.outer"])
    }

    // MARK: - 도우미

    @discardableResult
    private func makeApp(at url: URL, bundleID: String) throws -> URL {
        let contents = url.appendingPathComponent("Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let plist: [String: Any] = [
            "CFBundleIdentifier": bundleID,
            "CFBundleName": url.deletingPathExtension().lastPathComponent,
            "CFBundlePackageType": "APPL",
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: contents.appendingPathComponent("Info.plist"))
        return url
    }
}
