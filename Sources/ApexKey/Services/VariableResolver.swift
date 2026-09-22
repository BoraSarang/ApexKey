import Foundation
import AppKit
import IOKit
#if canImport(CoreWLAN)
import CoreWLAN
#endif

/// 변수 해석 엔진 — 사용자 변수, 매직 변수, 특수 변수, 서식 토큰을 해석한다
struct VariableResolver {
    /// 해석 컨텍스트 (실행 중 상태)
    struct ResolveContext {
        var variables: [UUID: VariableValue] = [:]
        var stepOutputs: [UUID: VariableValue] = [:]  // 매직 변수 (단계 출력)
        var lastOutput: VariableValue = .null
        var shortcutInput: VariableValue = .null      // 단축어 입력
        var repeatIndex: Int? = nil
        var repeatItem: VariableValue = .null
        
        init() {}
    }
    
    // MARK: - 변수 값 해석
    
    /// VariableValue → 표시 문자열 (프롬프트 치환용)
    static func stringValue(_ value: VariableValue) -> String {
        switch value {
        case .text(let v): return v
        case .number(let v):
            // 정수는 ".0" 없이 표시 (예: 2 → "2", 2.5 → "2.5")
            if v == v.rounded() { return String(Int(v)) }
            return String(v)
        case .boolean(let v): return v ? "variable.boolean_true".localized : "variable.boolean_false".localized
        case .list(let arr): return arr.map { stringValue($0) }.joined(separator: ", ")
        case .dictionary(let dict): return dict.map { "\($0.key): \(stringValue($0.value))" }.joined(separator: ", ")
        case .file(let url): return url.path
        case .image: return "variable.image".localized
        case .date(let d): return d.formatted(date: .abbreviated, time: .shortened)
        case .null: return ""
        }
    }
    
    /// 토큰을 단일 변수 값으로 해석 (매직/특수/사용자/UUID 순)
    static func resolveToken(_ token: String, context: ResolveContext) -> VariableValue {
        // 1. 매직 변수 토큰: {마법변수:stepID:name}
        let trimmed = token.trimmingCharacters(in: CharacterSet(charactersIn: "{}")).trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("마법변수:") {
            let parts = trimmed.components(separatedBy: ":")
            if parts.count >= 2, let stepID = UUID(uuidString: parts[1]) {
                return context.stepOutputs[stepID] ?? .null
            }
        }
        
        // 2. 특수 변수 토큰: {clipboard}, {currentDate}, ...
        if let special = SpecialVariable(rawValue: trimmed) {
            return resolveSpecialVariable(special, context: context)
        }
        
        // 3. 사용자 변수 ID (UUID)
        if let uuid = UUID(uuidString: trimmed) {
            return context.variables[uuid] ?? .null
        }
        
        return .null
    }
    
    /// 특수 변수 해석
    static func resolveSpecialVariable(_ special: SpecialVariable, context: ResolveContext) -> VariableValue {
        switch special {
        case .clipboard:
            return .text(NSPasteboard.general.string(forType: .string) ?? "")
        case .currentDate:
            return .date(Date())
        case .deviceName:
            return .text(Host.current().localizedName ?? "Mac")
        case .lastResult:
            return context.lastOutput
        case .shortcutInput:
            return context.shortcutInput
        case .repeatIndex:
            if let idx = context.repeatIndex {
                return .number(Double(idx))
            }
            return .null
        case .repeatItem:
            return context.repeatItem
        case .askEachTime:
            return .null  // UI에서 별도 처리
        case .batteryLevel:
            return .number(batteryLevel())
        case .wifiName:
            return .text(getWiFiName() ?? "")
        }
    }
    
    // MARK: - 문자열 치환
    
    /// 문자열 내 모든 변수 토큰 치환
    static func resolveText(_ text: String, context: ResolveContext) -> String {
        var resolved = text
        
        // 매직 변수 토큰 치환: {마법변수:stepID:name}
        let magicPattern = #"\{마법변수:([^:]+):([^}]+)\}"#
        if let regex = try? NSRegularExpression(pattern: magicPattern) {
            let range = NSRange(location: 0, length: resolved.utf16.count)
            let matches = regex.matches(in: resolved, range: range).reversed()
            for match in matches {
                guard let fullRange = Range(match.range, in: resolved),
                      let stepIDRange = Range(match.range(at: 1), in: resolved) else { continue }
                let stepIDStr = String(resolved[stepIDRange])
                if let stepID = UUID(uuidString: stepIDStr),
                   let value = context.stepOutputs[stepID] {
                    resolved.replaceSubrange(fullRange, with: stringValue(value))
                }
            }
        }
        
        // 특수 변수 토큰 치환: {clipboard}, {currentDate}, ...
            // 비ASCII(한글 등) 변수명 포함 · `name:UUID` 인용 문법 유지 [E-MAC-UX-9002]
            let specialPattern = #"\{([^{}:]+)\}"#
        if let regex = try? NSRegularExpression(pattern: specialPattern) {
            let range = NSRange(location: 0, length: resolved.utf16.count)
            let matches = regex.matches(in: resolved, range: range).reversed()
            for match in matches {
                guard let fullRange = Range(match.range, in: resolved),
                      let varRange = Range(match.range(at: 1), in: resolved) else { continue }
                let varName = String(resolved[varRange])
                if let special = SpecialVariable(rawValue: varName) {
                    let value = resolveSpecialVariable(special, context: context)
                    resolved.replaceSubrange(fullRange, with: stringValue(value))
                }
            }
        }
        
        return resolved
    }
    
    // MARK: - 시스템 정보
    
    static func batteryLevel() -> Double {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return 1.0 }
        defer { IOObjectRelease(service) }
        
        var current: Int = 100
        if let currentRaw = IORegistryEntryCreateCFProperty(service, "CurrentCapacity" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? NSNumber {
            current = currentRaw.intValue
        }
        
        return Double(current) / 100.0
    }
    
    static func getWiFiName() -> String? {
        #if canImport(CoreWLAN)
        if #available(macOS 13.0, *) {
            let client = CWWiFiClient.shared()
            guard let interface = client.interface(), let ssid = interface.ssid() else {
                return nil
            }
            return ssid
        }
        #endif
        return nil
    }
}
