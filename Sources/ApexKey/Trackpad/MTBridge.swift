import Foundation
import CoreFoundation

/// 트랙패드 원시 접점 한 개 (정규화 좌표, 좌상단 0,0 → 우하단 1,1)
struct TrackpadTouch: Equatable, Codable {
    var x: Float
    var y: Float
}

/// 한 프레임의 접점 묶음 — 테스트에서 JSON fixture로 재생할 수 있도록 Codable.
struct TrackpadFrame: Codable {
    var timestamp: Double
    var touches: [TrackpadTouch]
}

/// 비공개 `MultitouchSupport.framework` 브리지 — **이 파일 밖으로 새지 않는다**.
///
/// 설계 원칙
/// - 심볼은 `dlopen`/`dlsym`으로 **화이트리스트만** 해석한다.
/// - 패밀리 ID·디바이스 ID 조회 심볼은 **호출하지 않는다**
///   (macOS 26/27에서 SIGSEGV — 스파이크 실측). 이 파일에 이름조차 두지 않는다.
/// - 레이아웃이 바뀌면 값이 말이 안 되므로, 첫 프레임에서 **자체 검증**하고
///   실패하면 `isAvailable = false`로 기능만 끈다(앱은 계속 동작).
final class MTBridge {
    /// C 콜백에는 컨텍스트 포인터가 없어 전역 단일 인스턴스를 쓴다.
    private static var active: MTBridge?

    /// 프레임 수신 콜백 — 콜백 스레드(메인 아님)에서 호출된다.
    var onFrame: ((TrackpadFrame) -> Void)?

    private(set) var isAvailable = false
    private(set) var deviceCount = 0
    private(set) var lastError: String?

    private var frameworkHandle: UnsafeMutableRawPointer?
    private var deviceList: CFMutableArray?
    private var devices: [UnsafeMutableRawPointer] = []

    private var registerCallback: MTRegisterFn?
    private var startDevice: MTStartFn?
    private var stopDevice: MTStopFn?
    private var isBuiltInFn: MTIsBuiltInFn?

    /// 레이아웃 검증을 이미 통과했는지 (프레임마다 재검증하지 않는다)
    private var layoutValidated = false
    private var invalidFrameCount = 0

    // MARK: - 심볼 타입

    private typealias MTDeviceCreateListFn = @convention(c) () -> Unmanaged<CFMutableArray>?
    private typealias MTContactCallback = @convention(c) (Int32, UnsafeMutableRawPointer?, Int32, Double, Int32) -> Int32
    private typealias MTRegisterFn = @convention(c) (UnsafeMutableRawPointer, MTContactCallback) -> Void
    private typealias MTStartFn = @convention(c) (UnsafeMutableRawPointer, Int32) -> Int32
    private typealias MTStopFn = @convention(c) (UnsafeMutableRawPointer) -> Int32
    private typealias MTIsBuiltInFn = @convention(c) (UnsafeMutableRawPointer) -> Bool

    // MARK: - 접점 구조체 (96바이트)
    //
    // offset  의미
    //   0     frame          Int32
    //   8     timestamp      Double
    //  16     identifier     Int32
    //  20     state          Int32
    //  24     fingerCount    Int32
    //  28     (예약)         Int32
    //  32     normalized.pos.x  Float   ← 0..1
    //  36     normalized.pos.y  Float   ← 0..1
    //  40     normalized.vel.x  Float
    //  44     normalized.vel.y  Float
    //  48     size           Float
    //  52     (예약)         Int32
    //  56     angle          Float
    //  60     majorAxis      Float
    //  64     minorAxis      Float
    //  68     absolute.pos.x  Float
    //  72     absolute.pos.y  Float
    //  76     absolute.vel.x  Float
    //  80     absolute.vel.y  Float
    //  84     (예약)         Int32 x2
    //  92     zDensity       Float   ← 압력
    //
    // 4바이트 정렬을 위해 `UnsafeRawPointer.load(fromByteOffset:as:)`로 직접 읽는다.
    // Swift 구조체 멤버 정렬에 의존하면 패딩이 어긋날 수 있기 때문이다.
    private static let positionXOffset = 32
    private static let positionYOffset = 36
    private static let fingerCountOffset = 24
    private static let pressureOffset = 92
    private static let fingerStride = 96
    private static let maxFingers = 15

    // MARK: - 수명주기

    /// 프레임워크 로드 + 디바이스 열거 + 콜백 등록 + 시작
    @discardableResult
    func start() -> Bool {
        guard !isAvailable else { return true }
        guard loadFramework() else { return false }
        guard enumerateDevices(), !devices.isEmpty else {
            lastError = "no-device"
            Logger.error("E-MAC-TPAD-1001", "트랙패드 디바이스를 찾지 못했습니다")
            return false
        }
        MTBridge.active = self
        for device in devices {
            registerCallback?(device, MTBridge.contactCallback)
            _ = startDevice?(device, 0)
        }
        isAvailable = true
        Logger.info("Trackpad", "[TPAD] 시작 — 디바이스 \(devices.count)개")
        return true
    }

    func stop() {
        guard isAvailable else { return }
        for device in devices {
            _ = stopDevice?(device)
        }
        devices.removeAll()
        deviceList = nil
        if MTBridge.active === self { MTBridge.active = nil }
        isAvailable = false
        layoutValidated = false
        Logger.info("Trackpad", "[TPAD] 정지")
    }

    // MARK: - 로드

    private func loadFramework() -> Bool {
        let path = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
        guard let handle = dlopen(path, RTLD_NOW) else {
            let reason = dlerror().map { String(cString: $0) } ?? "unknown"
            lastError = reason
            Logger.error("E-MAC-TPAD-1002", "MultitouchSupport 로드 실패: \(reason)")
            return false
        }
        frameworkHandle = handle

        guard let createListSym = dlsym(handle, "MTDeviceCreateList"),
              let registerSym = dlsym(handle, "MTRegisterContactFrameCallback"),
              let startSym = dlsym(handle, "MTDeviceStart") else {
            lastError = "missing-symbol"
            Logger.error("E-MAC-TPAD-1003", "필수 심볼 누락 (MTDeviceCreateList/MTRegisterContactFrameCallback/MTDeviceStart)")
            dlclose(handle)
            frameworkHandle = nil
            return false
        }
        createList = unsafeBitCast(createListSym, to: MTDeviceCreateListFn.self)
        registerCallback = unsafeBitCast(registerSym, to: MTRegisterFn.self)
        startDevice = unsafeBitCast(startSym, to: MTStartFn.self)
        stopDevice = dlsym(handle, "MTDeviceStop").map { unsafeBitCast($0, to: MTStopFn.self) }
        isBuiltInFn = dlsym(handle, "MTDeviceIsBuiltIn").map { unsafeBitCast($0, to: MTIsBuiltInFn.self) }
        return true
    }

    private var createList: MTDeviceCreateListFn?

    private func enumerateDevices() -> Bool {
        guard let createList, let list = createList()?.takeRetainedValue() else {
            lastError = "create-list-failed"
            return false
        }
        deviceList = list
        let count = CFArrayGetCount(list)
        var found: [UnsafeMutableRawPointer] = []
        for index in 0..<count {
            guard let raw = CFArrayGetValueAtIndex(list, index) else { continue }
            let device = UnsafeMutableRawPointer(mutating: raw)
            // 내장 트랙패드만 사용한다(외장 Magic Trackpad도 builtin=1로 보고된다).
            // 판별 심볼이 없으면 전부 사용.
            if let isBuiltInFn, !isBuiltInFn(device) { continue }
            found.append(device)
        }
        devices = found
        deviceCount = found.count
        return true
    }

    // MARK: - C 콜백

    private static let contactCallback: MTContactCallback = { _, fingerData, count, timestamp, _ in
        guard let bridge = MTBridge.active, let base = fingerData, count > 0 else { return 0 }
        let n = min(Int(count), MTBridge.maxFingers)
        var touches: [TrackpadTouch] = []
        touches.reserveCapacity(n)
        var allValid = true
        for i in 0..<n {
            let offset = i * MTBridge.fingerStride
            let x = base.load(fromByteOffset: offset + MTBridge.positionXOffset, as: Float.self)
            let y = base.load(fromByteOffset: offset + MTBridge.positionYOffset, as: Float.self)
            // 좌표가 0..1 범위를 크게 벗어나면 레이아웃이 바뀐 것 → 기능 정지
            if !x.isFinite || !y.isFinite || x < -0.15 || x > 1.15 || y < -0.15 || y > 1.15 {
                allValid = false
                break
            }
            touches.append(TrackpadTouch(x: x, y: y))
        }
        guard allValid, !touches.isEmpty else {
            bridge.handleInvalidFrame()
            return 0
        }
        bridge.layoutValidated = true
        bridge.invalidFrameCount = 0
        bridge.onFrame?(TrackpadFrame(timestamp: timestamp, touches: touches))
        return 0
    }

    private func handleInvalidFrame() {
        invalidFrameCount += 1
        // 연속 30프레임(약 0.5초) 이상 값이 말이 안 되면 레이아웃이 바뀐 것으로 판단
        guard invalidFrameCount >= 30, !layoutValidated else { return }
        Logger.error("E-MAC-TPAD-1004", "터치 프레임 레이아웃 검증 실패 — 트랙패드 기능을 끕니다")
        lastError = "layout-mismatch"
        DispatchQueue.main.async { [weak self] in
            self?.stop()
            NotificationCenter.default.post(name: .trackpadUnavailable, object: nil)
        }
    }
}

extension Notification.Name {
    /// 이 macOS에서 트랙패드 입력을 읽을 수 없음 (레이아웃 변경·프레임워크 부재)
    static let trackpadUnavailable = Notification.Name("ApexKey.trackpadUnavailable")
}
