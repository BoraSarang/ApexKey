import Foundation

/// 단축키로 트리거할 액션의 종류
enum ActionType: String, Codable, CaseIterable, Identifiable {
    case launchApp        // 앱 실행/포커스/토글
    case menuCommand      // 타 앱의 메뉴 명령 실행 (AXUIElement)
    case file             // 파일/폴더 열기
    case url              // URL 열기
    case script           // 셸 스크립트 실행
    case system           // 시스템 동작
    case paste            // 붙여넣기 (클립보드 또는 특정 문자열)
    case wait             // N초 대기
    case coordinateClick  // 좌표 클릭
    case pauseUntilInput  // 사이보그 모드 — 입력 대기
    case macro            // 매크로 녹화

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .launchApp:   return "앱 실행/토글"
        case .menuCommand: return "메뉴 명령"
        case .file:        return "파일/폴더"
        case .url:         return "URL"
        case .script:      return "스크립트"
        case .system:      return "시스템"
        case .paste:       return "붙여넣기"
        case .wait:        return "대기"
        case .coordinateClick: return "좌표 클릭"
        case .pauseUntilInput: return "입력 대기"
        case .macro: return "매크로 녹화"
        }
    }

    var systemImage: String {
        switch self {
        case .launchApp:   return "square.and.arrow.up"
        case .menuCommand: return "menubar"
        case .file:        return "folder"
        case .url:         return "link"
        case .script:      return "terminal"
        case .system:      return "gearshape"
        case .paste:       return "clipboard"
        case .wait:        return "clock"
        case .coordinateClick: return "mousepointer"
        case .pauseUntilInput: return "pause.circle"
        case .macro:       return "record"
        }
    }
}
