import XCTest
@testable import ApexKey

/// 테마 활성 ID 단일 출처 회귀 테스트 (PLAN_v0.21 T-155 / E-MAC-UX-9011)
///
/// `ThemeConfigurationStore`는 `"activeThemeId"`, `ThemeManager`는
/// `ConfigStore.PrefKeys.activeThemeId`(`"ApexKeyActiveThemeId"`)를 쓰고 있었다.
/// 두 값을 잇는 코드가 0건이라 `loadActiveThemeId()`가 항상 nil을 반환했고,
/// `loadActiveTheme()`는 언제나 nil, `deleteTheme`의 활성 참조 정리도 실행되지 않았다.
@MainActor
final class ThemeActiveIdSingleSourceTests: XCTestCase {

    private var defaults: UserDefaults { .standard }
    private let canonicalKey = ConfigStore.PrefKeys.activeThemeId
    /// 구 키 — 값이写入됐던 적이 없어야 한다
    private let legacyKey = "activeThemeId"

    override func setUp() {
        super.setUp()
        defaults.removeObject(forKey: canonicalKey)
        defaults.removeObject(forKey: legacyKey)
    }

    override func tearDown() {
        defaults.removeObject(forKey: canonicalKey)
        defaults.removeObject(forKey: legacyKey)
        super.tearDown()
    }

    /// ThemeConfigurationStore가 정본 키에 읽고 써야 한다
    func testStoreUsesCanonicalKey() {
        let id = UUID()
        ThemeConfigurationStore.saveActiveThemeId(id)
        XCTAssertEqual(
            defaults.string(forKey: canonicalKey), id.uuidString,
            "정본 키에 기록되지 않음 — ThemeManager와 어긋남"
        )
    }

    /// ThemeManager가 읽는 키와 ThemeConfigurationStore가 읽는 키가 같아야 한다
    func testBothLayersSeeTheSameValue() {
        let id = UUID()
        ThemeConfigurationStore.saveActiveThemeId(id)
        // ThemeManager가 기동 시 읽는 것과 같은 키/같은 해석을 사용한다
        let readBack = defaults.string(forKey: canonicalKey).flatMap(UUID.init(uuidString:))
        XCTAssertEqual(readBack, id, "ThemeManager 관점의 읽기와 불일치")
        XCTAssertEqual(ThemeConfigurationStore.loadActiveThemeId(), id)
    }

    /// 구 키에는 값을 남기지 않아야 한다 (두 번째 출처가 다시 생기지 않도록)
    func testLegacyKeyIsNotWritten() {
        ThemeConfigurationStore.saveActiveThemeId(UUID())
        XCTAssertNil(
            defaults.object(forKey: legacyKey),
            "구 키에 값이 기록됨 — 정본과 별개로 두 번째 진실이 유지됨"
        )
    }

    /// nil 저장은 두 키 모두 정리되어야 한다
    func testClearingRemovesValue() {
        let id = UUID()
        ThemeConfigurationStore.saveActiveThemeId(id)
        ThemeConfigurationStore.saveActiveThemeId(nil)
        XCTAssertNil(ThemeConfigurationStore.loadActiveThemeId())
        XCTAssertNil(defaults.object(forKey: canonicalKey))
        XCTAssertNil(defaults.object(forKey: legacyKey))
    }

    /// 내장 테마를 활성으로 지정하면 loadActiveTheme가 실제로 로드되어야 한다.
    /// 이전에는 loadActiveThemeId()가 항상 nil이라 이 경로가 죽어 있었다.
    func testLoadActiveThemeActuallyResolvesBuiltInTheme() throws {
        ThemeConfigurationStore.installBuiltInThemesIfNeeded()
        let builtIn = try XCTUnwrap(
            CustomTheme.allBuiltInPresets.first,
            "내장 테마 프리셋이 하나 이상 있어야 함"
        )
        ThemeConfigurationStore.saveActiveThemeId(builtIn.metadata.id)

        let loaded = try XCTUnwrap(
            ThemeConfigurationStore.loadActiveTheme(),
            "loadActiveTheme이 nil — 활성 ID 해석 경로가 죽어 있음"
        )
        XCTAssertEqual(loaded.metadata.id, builtIn.metadata.id)
    }

    /// 활성 테마를 삭제하면 활성 참조가 정리되어야 한다 (이전엔 항상 false였다)
    func testDeletingActiveThemeClearsActiveReference() throws {
        ThemeConfigurationStore.installBuiltInThemesIfNeeded()
        // 커스텀 테마를 하나 만들어 활성으로 지정한 뒤 삭제
        let custom = CustomTheme.allBuiltInPresets[0]
        var customCopy = custom
        customCopy.metadata.id = UUID()
        customCopy.metadata.name = "테스트 테마"
        customCopy.isBuiltIn = false
        ThemeConfigurationStore.saveTheme(customCopy)
        ThemeConfigurationStore.saveActiveThemeId(customCopy.metadata.id)

        let deleted = ThemeConfigurationStore.deleteTheme(id: customCopy.metadata.id)
        XCTAssertTrue(deleted, "커스텀 테마 삭제 실패")
        XCTAssertNil(
            ThemeConfigurationStore.loadActiveThemeId(),
            "활성 테마를 삭제했는데 활성 참조가 남음"
        )
    }
}
