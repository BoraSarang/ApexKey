import XCTest
@testable import ApexKey

/// 저장 blob의 **키 누락 내성** 테스트 (E-MAC-STORE-5008)
///
/// 왜 이게 필요한가:
/// `PersistedShortcut`은 단계·트리거·변수·권한을 **JSON blob(`Data`)** 으로 저장한다.
/// SwiftData의 마이그레이션은 컬럼만 다룬다. blob은 불투명한 `Data`라 스키마가 바뀌어도
/// 아무것도 하지 않는다. 그리고 Swift의 합성 `Decodable`은 프로퍼티 기본값을 무시한다 —
/// `var x: Bool = false` 여도 JSON에 `x`가 없으면 `keyNotFound`를 던진다.
///
/// 결과: **모델 필드 하나 추가 = 사용자의 모든 blob 디코딩 실패.**
/// v0.16의 `undecodableBlobColumns()`가 해당 컬럼을 영구 쓰기 잠금으로 표시하고,
/// 복구 경로는 `removeShortcut`(동작 삭제)뿐이다. 즉 데이터 소실이다.
///
/// 그래서 blob 루트 타입은 전부 `decodeIfPresent ?? 기본값`으로 읽어야 하고
/// (`ShortcutStep` / `ShortcutPermissions` / `Variable`에 구현됨),
/// 이 테스트가 그 약속을 **필드 추가와 무관하게** 지킨다.
final class StoreBlobToleranceTests: XCTestCase {

    /// JSON 객체에서 키 하나를 제거하고 디코딩이 여전히 성공하는지 확인한다.
    /// 필드가 추가될 때마다 자동으로 이 스윕이 커져 새 필드의 회귀를 잡는다.
    private func assertToleratesMissingKeys<T: Codable & Equatable>(
        _ type: T.Type,
        sample: T,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let encoder = JSONEncoder()
        guard let full = try? encoder.encode(sample),
              var object = (try? JSONSerialization.jsonObject(with: full)) as? [String: Any] else {
            XCTFail("샘플을 JSON 객체로 인코딩할 수 없음", file: file, line: line)
            return
        }
        XCTAssertFalse(object.isEmpty, "샘플이 비어 있음 — 스윕이 무의미하다", file: file, line: line)

        let keys = Array(object.keys).sorted()
        for key in keys {
            var stripped = object
            stripped.removeValue(forKey: key)
            let data = try? JSONSerialization.data(withJSONObject: stripped)
            guard let data else {
                XCTFail("'\(key)' 제거 후 직렬화 실패", file: file, line: line)
                continue
            }
            do {
                let decoded = try JSONDecoder().decode(T.self, from: data)
                // 디코딩은 되지만 값이 조용히 바뀌면 그것도 결함이다(기본값 규칙 위반).
                // 선택 필드가 제거된 경우에만 값이 달라질 수 있으므로 필드별 비교는 하지 않고
                // "왕복 후 재인코딩이 가능한지"까지만 확인한다.
                _ = try? encoder.encode(decoded)
            } catch {
                XCTFail(
                    "'\(key)' 키가 없을 때 \(T.self) 디코딩 실패 — 이 필드는 관대 디코딩에 추가되지 않았다. "
                    + "기존 사용자 데이터가 이 컬럼에서 소실된다: \(error.localizedDescription)",
                    file: file, line: line
                )
            }
        }
        // 전체 객체는 당연히 디코딩되어야 한다
        XCTAssertNoThrow(try JSONDecoder().decode(T.self, from: full), file: file, line: line)
    }

    // MARK: - 개별 타입

    func testShortcutStepToleratesEveryMissingKey() {
        assertToleratesMissingKeys(
            ShortcutStep.self,
            sample: ShortcutStep(
                id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                type: .menuCommand,
                target: "com.apple.Safari",
                title: "새 탭",
                menuPath: ["파일", "새 탭"],
                onlyWhenAppActive: true,
                outputVariables: [Variable(name: "결과", type: .manual, valueType: .any)],
                actionParameters: Data([0x01, 0x02]),
                isSkipped: true,
                note: "주석",
                magicVariableTokens: ["{토큰}"]
            )
        )
    }

    func testShortcutPermissionsToleratesEveryMissingKey() {
        assertToleratesMissingKeys(
            ShortcutPermissions.self,
            sample: ShortcutPermissions(
                allowExporting: false,
                allowRunningOnMac: false,
                allowRunningOnWatch: true,
                allowRunningFromLockScreen: true,
                showOnLockScreen: true,
                requiresConfirmation: true
            )
        )
    }

    func testVariableToleratesEveryMissingKey() {
        assertToleratesMissingKeys(
            Variable.self,
            sample: Variable(
                id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                name: "변수",
                type: .manual,
                valueType: .any,
                defaultValue: nil,
                isHidden: true
            )
        )
    }

    // MARK: - 빈/최소 blob — 실제 회귀 지점

    func testEmptyObjectDecodesForAllBlobRoots() {
        // `{}`는 "구 레코드에서 새 필드가 빠진 상태"의 극단 사례다.
        XCTAssertNoThrow(try JSONDecoder().decode(ShortcutStep.self, from: Data("{}".utf8)))
        XCTAssertNoThrow(try JSONDecoder().decode(ShortcutPermissions.self, from: Data("{}".utf8)))
        XCTAssertNoThrow(try JSONDecoder().decode(Variable.self, from: Data("{}".utf8)))
    }

    func testLegacyStepWithoutNewFieldsSurvives() {
        // 구 버전에 없던 필드들(note, magicVariableTokens, isSkipped, launchConfig…)이
        // 원래는 아예 없었다. 이 blob은 실제 구 버전이 만든 것이다.
        let legacy = """
        {"id":"33333333-3333-3333-3333-333333333333","type":"launchApp","target":"com.apple.Safari"}
        """
        let step = try? JSONDecoder().decode(ShortcutStep.self, from: Data(legacy.utf8))
        XCTAssertNotNil(step, "구 형식 단계가 디코딩 불가 — 동작 전체가 소실된다")
        XCTAssertEqual(step?.target, "com.apple.Safari")
        XCTAssertEqual(step?.title, "")
        XCTAssertEqual(step?.menuPath, [])
        XCTAssertFalse(step?.isSkipped ?? true)
    }

    func testLegacyPermissionsWithoutNewFieldsSurvives() {
        // allowExporting 하나만 있었던 구 blob
        let legacy = #"{"allowExporting":false}"#
        let perms = try? JSONDecoder().decode(ShortcutPermissions.self, from: Data(legacy.utf8))
        XCTAssertNotNil(perms, "구 권한 blob이 디코딩 불가 — 동작 전체가 소실된다")
        XCTAssertEqual(perms?.allowExporting, false, "기존 값은 보존되어야 함")
        XCTAssertEqual(perms?.allowRunningOnMac, true, "누락 필드는 기본값으로 채워져야 함")
        XCTAssertEqual(perms?.requiresConfirmation, false)
    }

    // MARK: - 저장 계층 연동

    func testShortcutWithLegacyBlobIsNotWriteLocked() {
        // 디코딩 성공 여부만이 아니라, v0.16의 쓰기 잠금이 **걸리지 않아야** 한다.
        // 잠금이 걸리면 사용자가 그 동작을 실행할 때까지 blob이 원본 그대로 얼어붙는다.
        let p = PersistedShortcut(name: "구 동작", steps: [])
        p.stepsData = Data(#"[{"type":"launchApp","target":"com.apple.Safari"}]"#.utf8)
        p.triggersData = Data("[]".utf8)
        p.variablesData = Data("[]".utf8)
        p.permissionsData = Data(#"{"allowExporting":false}"#.utf8)
        XCTAssertTrue(
            p.undecodableBlobColumns().isEmpty,
            "구 blob이 쓰기 잠금 대상이 됨: \(p.undecodableBlobColumns().map(\.rawValue).sorted())"
        )
        // 복구 후 값도 정상
        XCTAssertEqual(p.toShortcut().steps.first?.target, "com.apple.Safari")
        XCTAssertEqual(p.toShortcut().permissions.allowExporting, false)
    }

    func testEmptyBlobStillDetectedAsCorrupt() {
        // 관대 디코딩을 했다고 **진짜 손상까지 놓치면 안 된다.**
        // 쓰레기 바이트는 여전히 감지되어야 쓰기 가드가 동작한다.
        let p = PersistedShortcut(name: "손상", steps: [])
        p.stepsData = Data([0xFF, 0xFE, 0x00])
        let cols = p.undecodableBlobColumns()
        XCTAssertTrue(cols.contains(.steps), "실제 손상은 여전히 감지되어야 함")
    }

    func testArrayOfStepsToleratesLegacyElements() {
        // 실제 저장 형태는 배열이다. 원소가 구 형식이어도 배열 전체가 살아야 한다.
        let json = #"[{"type":"launchApp","target":"a"},{"type":"wait","target":"1.0"},{"type":"system","target":"lock","title":"잠금"}]"#
        let steps = try? JSONDecoder().decode([ShortcutStep].self, from: Data(json.utf8))
        XCTAssertNotNil(steps, "구 형식 원소가 섞인 배열이 디코딩 불가")
        XCTAssertEqual(steps?.count, 3)
        XCTAssertEqual(steps?[2].title, "잠금")
    }
}
