import CoreGraphics
import Foundation

/// 1손가락 에지 슬라이드 동안 커서를 붙잡아 두는 앵커.
///
/// 1손가락 제스처는 커서 이동과 같은 입력이라, 그대로 두면 슬라이드할 때마다
/// 포인터가 화면을 가로지른다. 그래서 **활성화 시점에** 커서를 분리하고
/// 손을 떼면 **진입 전 위치로 되돌린다**.
///
/// 안전 불변식
/// - `release()`는 **멱등**이다. 여러 경로(정상 종료·취소·엔진 정지·프레임 끊김·
///   앱 종료)에서 몇 번을 불러도 커서는 한 번만 되돌아간다.
/// - `hold()` 상태에서 5초가 지나면 워치독이 스스로 푼다.
///   (앱이 멈춰도 커서가 잠긴 채 남지 않게)
/// - `cancel()`은 되돌리지 않는다 — 추적만 하다 만 입력은 커서 이동이 정상이다.
@MainActor
final class PointerAnchor {
    private var remembered: CGPoint?
    private var held = false
    private var watchdog: DispatchWorkItem?

    /// 커서를 분리해 붙잡고 있는가 (테스트·UI 표시용)
    var isHolding: Bool { held }

    // MARK: - 공개 API

    /// 세션 시작 — 커서 위치만 기억한다. 아직 분리하지 않는다.
    /// (진입 판정에 실패하면 커서는 정상적으로 움직여야 한다)
    func remember() {
        guard remembered == nil else { return }
        remembered = CGEvent(source: nil)?.location
    }

    /// 슬라이더 활성화 — 커서를 분리하고 기억한 위치에 묶는다.
    func hold() {
        guard !held else { return }
        if remembered == nil { remembered = CGEvent(source: nil)?.location }
        CGAssociateMouseAndMouseCursorPosition(0)
        held = true
        armWatchdog()
    }

    /// 세션 종료 — 커서를 복원하고 다시 연결한다.
    func release() {
        watchdog?.cancel()
        watchdog = nil
        guard held else {
            // 붙잡은 적이 없으면 되돌릴 것도 없다. 기억만 비운다.
            remembered = nil
            return
        }
        if let remembered {
            CGWarpMouseCursorPosition(remembered)
        }
        CGAssociateMouseAndMouseCursorPosition(1)
        remembered = nil
        held = false
    }

    /// 세션 취소 — 활성화 전이면 아무것도 하지 않는다.
    func cancel() {
        guard held else {
            remembered = nil
            watchdog?.cancel()
            watchdog = nil
            return
        }
        release()
    }

    // MARK: - 워치독

    private func armWatchdog() {
        watchdog?.cancel()
        let item = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.held else { return }
                Logger.error("E-MAC-TPAD-3001", "포인터 앵커 워치독 — 커서를 강제로 복원합니다")
                self.release()
            }
        }
        watchdog = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: item)
    }
}
