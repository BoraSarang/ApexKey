import Foundation

/// macOS 시스템 단축키 점유 검사 (M-04)
///
/// `~/Library/Preferences/com.apple.symbolichotkeys.plist`의 `AppleSymbolicHotKeys`를 읽어
/// 현재 켜진(enabled) 시스템 단축키 집합을 Carbon keyCode+flags로 변환한다.
/// MenuDart식 "경고 + 이동/강행/취소"의 판정 근거. 차단은 하지 않고 경고만 한다.
///
/// plist 포맷 (실측, 2026-10-06):
/// `parameters = [문자코드, 가상키코드, Cocoa 수식키]` + `type == "standard"`.
/// Cocoa 수식키(NSEvent.ModifierFlags): shift 1<<17, control 1<<18, option 1<<19, command 1<<20.
/// 매핑표에 없는 조합·파싱 실패는 **차단하지 않고 무시**한다(오탐 과차단보다 미탐이 낫다).
/// plist를 읽지 못하면 빈 집합을 반환한다(fail-open — 경고 기능만 비활성).
enum SystemHotkeyInspector {

    /// Cocoa 수식키 → Carbon flags (KeyboardUtil 마스크 기준)
    static func carbonModifiers(fromCocoa cocoa: UInt32) -> UInt32 {
        var result: UInt32 = 0
        if cocoa & (1 << 17) != 0 { result |= KeyboardUtil.shiftMask }
        if cocoa & (1 << 18) != 0 { result |= KeyboardUtil.controlMask }
        if cocoa & (1 << 19) != 0 { result |= KeyboardUtil.optionMask }
        if cocoa & (1 << 20) != 0 { result |= KeyboardUtil.cmdMask }
        return result
    }

    /// plist 딕셔너리 → 켜진 시스템 단축키 목록 (순수 파싱, 테스트 가능)
    static func parse(from root: [String: Any]) -> [HotKeyCombo] {
        guard let all = root["AppleSymbolicHotKeys"] as? [String: Any] else { return [] }
        var result: [HotKeyCombo] = []
        for (_, entry) in all {
            guard let dict = entry as? [String: Any],
                  (dict["enabled"] as? Bool) == true,
                  let value = dict["value"] as? [String: Any],
                  (value["type"] as? String) == "standard",
                  let params = value["parameters"] as? [NSNumber],
                  params.count == 3 else { continue }
            let keyCode = params[1].uint32Value
            // 65535 = 키 없음 자리표시 — 비교 불가이므로 제외
            guard keyCode != 65535 else { continue }
            let carbon = carbonModifiers(fromCocoa: params[2].uint32Value)
            // 수식키 없는 시스템 단축키는 글로벌 핫키와 충돌하지 않으므로 제외
            guard carbon != 0 else { continue }
            result.append(HotKeyCombo(keyCode: keyCode, modifiers: carbon))
        }
        return result
    }

    /// 현재 켜진 시스템 단축키 목록. 실패 시 [] (경고만 생략, 저장은 계속됨).
    static func claimedCombos() -> [HotKeyCombo] {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences/com.apple.symbolichotkeys.plist")
        guard let data = try? Data(contentsOf: url),
              let root = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let dict = root as? [String: Any] else { return [] }
        return parse(from: dict)
    }

    /// 키 입력마다 plist를 읽지 않도록 짧게 캐시 (시스템 설정 변경은 수 초 내 반영)
    private static var cache: (at: Date, combos: [HotKeyCombo])?
    static func cachedClaimedCombos(ttl: TimeInterval = 10) -> [HotKeyCombo] {
        if let cache, Date().timeIntervalSince(cache.at) < ttl { return cache.combos }
        let combos = claimedCombos()
        cache = (Date(), combos)
        return combos
    }

    /// combo가 켜진 시스템 단축키와 겹치는가
    static func claims(_ combo: HotKeyCombo, in claimed: [HotKeyCombo]? = nil) -> Bool {
        guard !combo.isEmpty else { return false }
        let list = claimed ?? claimedCombos()
        return list.contains { $0.matches(combo) }
    }
}
