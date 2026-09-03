import SwiftUI

@main
struct ApexKeyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // 설정 창은 AppDelegate.showSettingsPanel(AppKit, ⌘,)가 전담한다.
        // SwiftUI Settings { EmptyView() } scene이 있으면 Cmd+, 가 빈 설정창을 띄우는
        // 근본 원인(자동 "설정…" 메뉴 연결 + 실제 설정항목 충돌)이 되므로 제거한다.
        // LSUIElement 메뉴바 앱이라 실행 시 윈도우를 자동 생성하지 않는 빈 scene을 둔다.
        WindowGroup {
            EmptyView()
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            // SwiftUI가 자동 생성하는 파일/편집 메뉴의 Cmd+, 연결을 만들지 않는다.
        }
    }
}
