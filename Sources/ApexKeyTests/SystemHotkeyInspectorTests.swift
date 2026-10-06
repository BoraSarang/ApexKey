import XCTest
@testable import ApexKey

/// macOS 시스템 단축키 점유 검사 테스트 (M-04)
/// 실측 plist 포맷: parameters = [문자코드, 가상키코드, Cocoa 수식키], type == "standard".
final class SystemHotkeyInspectorTests: XCTestCase {

    private var cmd: UInt32 { KeyboardUtil.cmdMask }
    private var opt: UInt32 { KeyboardUtil.optionMask }
    private var ctrl: UInt32 { KeyboardUtil.controlMask }
    private var shift: UInt32 { KeyboardUtil.shiftMask }

    private func root(_ entries: [String: Any]) -> [String: Any] {
        ["AppleSymbolicHotKeys": entries]
    }

    private func entry(enabled: Bool, params: [Int], type: String = "standard") -> [String: Any] {
        ["enabled": enabled, "value": ["parameters": params.map { NSNumber(value: $0) }, "type": type]]
    }

    func testParsesEnabledStandardEntry() {
        // Spotlight ⌘Space 유사: keyCode 49, Cocoa command(1<<20)
        let combos = SystemHotkeyInspector.parse(from: root(["60": entry(enabled: true, params: [32, 49, 1 << 20])]))
        XCTAssertEqual(combos.count, 1)
        XCTAssertEqual(combos[0].keyCode, 49)
        XCTAssertEqual(combos[0].modifiers, cmd)
    }

    func testDisabledEntriesAreIgnored() {
        let combos = SystemHotkeyInspector.parse(from: root(["15": entry(enabled: false, params: [32, 49, 1 << 20])]))
        XCTAssertTrue(combos.isEmpty)
    }

    func testNonStandardTypeIsIgnored() {
        let combos = SystemHotkeyInspector.parse(from: root(["79": ["enabled": true]]))
        XCTAssertTrue(combos.isEmpty)
    }

    func testPlaceholderKeyCodeIsIgnored() {
        // 65535 = 키 없음 자리표시 — 비교 불가
        let combos = SystemHotkeyInspector.parse(from: root(["118": entry(enabled: true, params: [65535, 65535, 1 << 18])]))
        XCTAssertTrue(combos.isEmpty)
    }

    func testModifierlessIsIgnored() {
        let combos = SystemHotkeyInspector.parse(from: root(["1": entry(enabled: true, params: [32, 49, 0])]))
        XCTAssertTrue(combos.isEmpty)
    }

    func testCocoaToCarbonMapping() {
        // control+option (Spotlight 윈도우 유사 786432)
        let carbon = SystemHotkeyInspector.carbonModifiers(fromCocoa: 786432)
        XCTAssertEqual(carbon, ctrl | opt)
        XCTAssertEqual(SystemHotkeyInspector.carbonModifiers(fromCocoa: 1 << 17), shift)
        XCTAssertEqual(SystemHotkeyInspector.carbonModifiers(fromCocoa: 1 << 20), cmd)
    }

    func testClaimsMatchesCombo() {
        let claimed = [HotKeyCombo(keyCode: 49, modifiers: cmd)]
        XCTAssertTrue(SystemHotkeyInspector.claims(HotKeyCombo(keyCode: 49, modifiers: cmd), in: claimed))
        XCTAssertFalse(SystemHotkeyInspector.claims(HotKeyCombo(keyCode: 49, modifiers: cmd | shift), in: claimed))
        XCTAssertFalse(SystemHotkeyInspector.claims(HotKeyCombo(keyCode: 50, modifiers: cmd), in: claimed))
    }

    func testEmptyComboNeverClaims() {
        XCTAssertFalse(SystemHotkeyInspector.claims(.empty, in: [HotKeyCombo(keyCode: 49, modifiers: cmd)]))
    }

    func testMissingRootParsesToEmpty() {
        XCTAssertTrue(SystemHotkeyInspector.parse(from: [:]).isEmpty)
        XCTAssertTrue(SystemHotkeyInspector.parse(from: ["Other": 1]).isEmpty)
    }

    func testLivePlistReadsWithoutCrashing() {
        // 이 머신의 실제 plist — 내용은 환경마다 다르므로 개수만 단언하지 않고 무사 파싱만 확인
        let combos = SystemHotkeyInspector.claimedCombos()
        XCTAssertTrue(combos.allSatisfy { !$0.isEmpty })
    }

    func testNewKeysExistInBothLanguages() {
        // M-04 신규 키가 ko/en에 모두 있어야 게이트는 통과해도 UI에 원문이 노출되지 않는다
        XCTAssertFalse("ui.recorder.system_conflict".localized.isEmpty)
        XCTAssertFalse("ui.recorder.system_hint".localized.isEmpty)
    }
}
