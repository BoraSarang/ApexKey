import Foundation
import IOKit.pwr_mgt

/// 잠자기 방지 (T-211) — 전원 어서션
///
/// 왜 `caffeinate` 프로세스가 아니라 어서션인가: 자식 프로세스는 부모 앱이
/// 종료돼도 OS가 함께 정리하지 않는다. 그러면 ApexKey를 끈 뒤에도 잠자기가
/// 계속 막힌다. `IOPMAssertion`은 **프로세스 수명에 묶여** 앱이 종료되면
/// 시스템이 자동으로 해제한다. "켜짐"이 앱 수명과 정확히 일치한다.
final class PreventSleepController {
    static let shared = PreventSleepController()

    private let lock = NSLock()
    private var assertionID: IOPMAssertionID = 0
    private var assertionActive = false
    /// 테스트 실행 중에는 실제 어서션을 만들지 않고 의도만 기록한다
    private var simulatedActive = false

    private init() {}

    var isActive: Bool {
        lock.lock()
        defer { lock.unlock() }
        if KeySender.suppressesPublish { return simulatedActive }
        return assertionActive
    }

    /// 켜기/끄기. 이미 원하는 상태면 no-op.
    @discardableResult
    func setActive(_ active: Bool) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        if KeySender.suppressesPublish {
            simulatedActive = active
            return true
        }

        if active {
            guard !assertionActive else { return true }
            var id: IOPMAssertionID = 0
            let result = IOPMAssertionCreateWithName(
                kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "ApexKey is preventing sleep" as CFString,
                &id
            )
            guard result == kIOReturnSuccess else {
                Logger.error(
                    "E-MAC-NEXT-6101",
                    "Power assertion failed (IOReturn \(result))"
                )
                return false
            }
            assertionID = id
            assertionActive = true
            Logger.info("PreventSleep", "잠자기 방지 시작 (assertion \(id))")
            return true
        } else {
            guard assertionActive else { return true }
            IOPMAssertionRelease(assertionID)
            assertionID = 0
            assertionActive = false
            Logger.info("PreventSleep", "잠자기 방지 종료")
            return true
        }
    }

    @discardableResult
    func toggle() -> Bool {
        setActive(!isActive)
    }

    /// 사용자에게 보여줄 상태 문구
    var statusText: String {
        isActive ? "ui.next_action.prevent_sleep_on".localized
                 : "ui.next_action.prevent_sleep_off".localized
    }
}
