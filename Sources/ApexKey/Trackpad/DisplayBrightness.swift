import Foundation
import CoreGraphics
import Darwin

/// 내장 디스플레이 밝기 — `DisplayServices.framework`(비공개)를 **dlopen으로만** 쓴다.
///
/// 링크하지 않는 이유: OS 업데이트로 프레임워크/심볼이 사라져도 앱이 뜨지 못하는 일이
/// 없어야 한다. 실패하면 `isAvailable = false`가 되고, 밝기 대상만 조용히 비활성화된다
/// (볼륨·워크플로우·제스처는 그대로 동작).
///
/// 격리: 이 파일 밖에서는 `dlopen`/`dlsym`/`DisplayServices`를 쓰지 않는다.
/// `scripts/check-trackpad-boundary.py`가 기계적으로 검사한다.
final class DisplayBrightness {
    static let shared = DisplayBrightness()

    private typealias GetFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetFn = @convention(c) (CGDirectDisplayID, Float) -> Int32
    private typealias CanChangeFn = @convention(c) (CGDirectDisplayID) -> Int32

    private let handle: UnsafeMutableRawPointer?
    private let getFn: GetFn?
    private let setFn: SetFn?
    private let displayID: CGDirectDisplayID

    /// 읽기·쓰기가 실제로 가능한가 (내장 디스플레이 + 심볼)
    let isAvailable: Bool

    private init() {
        let path = "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"
        guard let handle = dlopen(path, RTLD_NOW) else {
            self.handle = nil
            self.getFn = nil
            self.setFn = nil
            self.displayID = 0
            self.isAvailable = false
            Logger.error("E-MAC-TPAD-1011", "밝기 프레임워크를 불러오지 못했습니다")
            return
        }

        let get = dlsym(handle, "DisplayServicesGetBrightness").map {
            unsafeBitCast($0, to: GetFn.self)
        }
        let set = dlsym(handle, "DisplayServicesSetBrightness").map {
            unsafeBitCast($0, to: SetFn.self)
        }
        let canChange = dlsym(handle, "DisplayServicesCanChangeBrightness").map {
            unsafeBitCast($0, to: CanChangeFn.self)
        }
        let id = Self.preferredDisplay(canChange: canChange)

        self.handle = handle
        self.getFn = get
        self.setFn = set
        self.displayID = id

        var probe: Float = 0
        let readable = get != nil && get?(id, &probe) == 0
        let writable = set != nil && (canChange?(id) ?? 1) != 0
        self.isAvailable = id != 0 && readable && writable

        if !isAvailable {
            Logger.error("E-MAC-TPAD-1012", "밝기 제어를 사용할 수 없습니다 (display \(id))")
        }
    }

    deinit {
        if let handle { dlclose(handle) }
    }

    /// 현재 밝기 0.0 ... 1.0
    func current() -> Float? {
        guard isAvailable, let getFn else { return nil }
        var value: Float = 0
        guard getFn(displayID, &value) == 0, value.isFinite else { return nil }
        return min(max(value, 0), 1)
    }

    /// 밝기 설정. 성공하면 true.
    @discardableResult
    func set(_ value: Float) -> Bool {
        guard isAvailable, let setFn else { return false }
        return setFn(displayID, min(max(value, 0), 1)) == 0
    }

    // MARK: - 디스플레이 선택

    /// 내장 디스플레이를 우선한다. 없으면 밝기 변경이 가능한 디스플레이,
    /// 그것도 없으면 주 디스플레이를 쓴다(읽기 실패 시 `isAvailable = false`).
    private static func preferredDisplay(canChange: CanChangeFn?) -> CGDirectDisplayID {
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        let status = ids.withUnsafeMutableBufferPointer {
            CGGetActiveDisplayList(16, $0.baseAddress, &count)
        }
        let displays = status == .success ? Array(ids.prefix(Int(count))) : []

        if let builtin = displays.first(where: { CGDisplayIsBuiltin($0) != 0 }) {
            return builtin
        }
        if let changeable = displays.first(where: { (canChange?($0) ?? 0) != 0 }) {
            return changeable
        }
        return CGMainDisplayID()
    }
}
