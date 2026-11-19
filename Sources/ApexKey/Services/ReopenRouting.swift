import AppKit
import Carbon

/// 재실행·실행 시 어떤 표면을 보여줄지 결정하는 순수 라우팅.
///
/// 배경: 메뉴바·Dock 아이콘을 모두 끄면 앱으로 들어갈 눈에 보이는 입구가 사라진다.
/// Finder/Spotlight에서 `.app`을 다시 열면 실행 중인 인스턴스에
/// `applicationShouldHandleReopen`이 오므로, 그때 설정 창을 열어 복구한다.
enum ReopenPresentation: Equatable {
    /// 이미 보이는 창을 앞으로 가져온다.
    case bringForward
    /// 설정 창을 연다.
    case settings
}

enum ReopenRouter {
    /// 이미 실행 중인 앱을 다시 열었을 때의 표면.
    static func reopen(hasVisibleWindow: Bool) -> ReopenPresentation {
        hasVisibleWindow ? .bringForward : .settings
    }

    /// 앱이 꺼져 있을 때 수동 실행했을 때 설정 창을 띄울지.
    /// - 아이콘이 하나라도 켜져 있으면 기존처럼 조용히 시작한다.
    /// - 로그인 자동 시작은 사용자가 부른 실행이 아니므로 숨김을 유지한다.
    static func launch(
        showInMenuBar: Bool,
        showInDock: Bool,
        launchedAsLoginItem: Bool
    ) -> ReopenPresentation? {
        guard !showInMenuBar, !showInDock, !launchedAsLoginItem else { return nil }
        return .settings
    }
}

/// 실행 경로 판정 — 로그인 자동 시작과 수동 실행을 구분한다.
enum LaunchContext {
    /// `kAEOpenApplication` 이벤트에 `keyAELaunchedAsLogInItem`이 있으면 로그인 시작.
    /// (AERegistry.h: "application was launched as a login item and probably shouldn't
    ///  open up untitled documents, etc.")
    static func isLoginItemLaunch() -> Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent,
              event.eventClass == AEEventClass(kCoreEventClass),
              event.eventID == AEEventID(kAEOpenApplication) else {
            return false
        }
        return event.paramDescriptor(forKeyword: AEKeyword(keyAELaunchedAsLogInItem)) != nil
    }
}
