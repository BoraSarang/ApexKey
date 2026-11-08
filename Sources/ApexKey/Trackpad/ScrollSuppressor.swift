import Foundation
import CoreGraphics
import ApplicationServices

/// 에지 슬라이더가 동작하는 **동안에만** 스크롤 이벤트를 삼키는 억제기.
///
/// - `CGEventTap`은 전용 스레드의 런루프에서 돌린다(메인 스레드 블로킹 금지).
/// - 탭은 한 번 만들고 계속 살려 둔다. 켜고 끄는 것은 원자적 플래그다
///   (탭을 매번 생성/해제하면 비용이 크고, 해제 중 이벤트 유실 구간이 생긴다).
/// - `kCGEventTapDisabledByTimeout`을 받으면 **즉시 재활성**한다. 3회 연속 실패하면
///   억제를 포기한다(스크롤이 영구히 막히는 것을 방지).
/// - 권한은 기존 **Accessibility**를 그대로 쓴다 (Input Monitoring 불필요 — 스파이크 실측).
final class ScrollSuppressor {
    private(set) var isAvailable = false
    private(set) var lastError: String?

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var thread: Thread?
    private var activeRunLoop: CFRunLoop?
    private var ready = DispatchSemaphore(value: 0)
    private var consecutiveTimeouts = 0

    private var lock = os_unfair_lock_s()
    private var swallowingFlag = false

    // MARK: - 공개 API

    /// 억제 플래그 설정. 켜는데 탭이 없으면 먼저 만든다.
    func setSwallowing(_ on: Bool) {
        if on { _ = prepare() }
        os_unfair_lock_lock(&lock)
        swallowingFlag = on
        os_unfair_lock_unlock(&lock)
    }

    /// 탭을 미리 만들어 둔다. 성공 여부 반환.
    @discardableResult
    func prepare() -> Bool {
        if isAvailable { return true }
        guard PermissionHelper.isAccessibilityTrusted else {
            lastError = "no-accessibility"
            return false
        }
        // 이전 실패 흔적 정리
        if thread != nil { teardown() }
        ready = DispatchSemaphore(value: 0)
        let t = Thread { [weak self] in self?.runTapLoop() }
        t.name = "ApexKey.ScrollSuppressor"
        t.qualityOfService = .userInteractive
        thread = t
        t.start()
        // 탭 생성은 스레드에서 비동기로 끝난다 — 최대 0.5초 대기
        _ = ready.wait(timeout: .now() + 0.5)
        return isAvailable
    }

    func stop() {
        setSwallowing(false)
        teardown()
    }

    // MARK: - 내부

    private var isSwallowing: Bool {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return swallowingFlag
    }

    private func teardown() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        tap = nil
        if let source, let loop = activeRunLoop {
            CFRunLoopRemoveSource(loop, source, .commonModes)
        }
        source = nil
        if let loop = activeRunLoop {
            CFRunLoopStop(loop)
        }
        activeRunLoop = nil
        thread = nil
        isAvailable = false
    }

    private func runTapLoop() {
        let mask = CGEventMask(1 << CGEventType.scrollWheel.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: ScrollSuppressor.tapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            lastError = "tap-create-failed"
            Logger.error("E-MAC-TPAD-2001", "스크롤 억제 탭 생성 실패")
            isAvailable = false
            ready.signal()
            return
        }

        self.tap = tap
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.source = runLoopSource
        let loop = CFRunLoopGetCurrent()
        self.activeRunLoop = loop
        CFRunLoopAddSource(loop, runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isAvailable = true
        Logger.info("ScrollSuppressor", "[SUPPRESS] 탭 준비 완료")
        ready.signal()
        CFRunLoopRun()
    }

    private func reEnableIfPossible() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
    }

    private static let tapCallback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else { return Unmanaged.passUnretained(event) }
        let suppressor = Unmanaged<ScrollSuppressor>.fromOpaque(userInfo).takeUnretainedValue()

        switch type {
        case .tapDisabledByTimeout:
            suppressor.consecutiveTimeouts += 1
            if suppressor.consecutiveTimeouts >= 3 {
                Logger.error("E-MAC-TPAD-2002", "스크롤 억제 탭 3회 연속 비활성 — 억제 해제")
                suppressor.setSwallowing(false)
                suppressor.isAvailable = false
            } else {
                suppressor.reEnableIfPossible()
            }
            return Unmanaged.passUnretained(event)

        case .tapDisabledByUserInput:
            suppressor.reEnableIfPossible()
            return Unmanaged.passUnretained(event)

        case .scrollWheel:
            suppressor.consecutiveTimeouts = 0
            return suppressor.isSwallowing ? nil : Unmanaged.passUnretained(event)

        default:
            return Unmanaged.passUnretained(event)
        }
    }
}
