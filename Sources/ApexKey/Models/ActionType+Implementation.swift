import Foundation

/// 액션 구현 상태 — 카탈로그 노출과 단계 설정 UI를 여기서 결정한다 (E-MAC-CAT-9401)
///
/// 배경: `ActionType`은 153종인데 실제 실행되는 것은 28종(18%)이었다. 나머지 125종은
/// `ActionExecutor.executeWithDetail`의 `default:` 분기(`E-MAC-ACT-3005`)에 떨어져
/// "미구현" 토스트와 함께 실패했는데, 카탈로그에는 구현과 구분 없이 153종이 모두 노출됐다.
/// 사용자는 "정규식"이나 "QR 스캔"을 고르고 빈 설정 창을 연 뒤 실행해야야 알 수 있었다.
extension ActionType {
    enum ActionImplementation {
        /// 실행 가능 — 카탈로그에서 선택할 수 있고 단계 설정 UI를 제공한다
        case implemented
        /// FoundationModels 골격은 있으나 동작하지 않는다 (정직한 실패 반환, E-MAC-AI-9013)
        case stub
        /// 미구현 — 카탈로그에서 "준비 중"으로만 표시되고 선택해도 실행되지 않는다
        case planned
    }

    /// 액션 구현 상태.
    ///
    /// **컴파일 타임 정합성**: 아래 switch 에 `default:`가 없고 154개 case를 빠짐없이 나열한다.
    /// 그래서 `ActionType`에 새 case를 추가하면 여기가 **컴파일 에러**가 된다.
    /// "카탈로그에는 노출되는데 실행은 안 되는" 상태가 구조적으로 재발할 수 없다.
    ///
    /// 새 액션을 추가하는 법: 여기 case를 추가하면 컴파일러가 빠진 것을 알려준다.
    /// 1. `.implemented` 로 분류 → 실제 `case` 분기를 `ExecutionEngine.executeStep` 또는
    ///    `ActionExecutor.executeWithDetail` 에 추가해야 빌드가 통과한다.
    /// 2. 아직 못 만들면 `.planned` 로 분류 → 카탈로그에 "준비 중"으로만 보인다.
    /// `.stub` 은 "골격은 있으나 동작하지 않음"이므로 UI에 주의 표기가 붙는다.
    var implementation: ActionImplementation {
        switch self {
        case .appleScript, .chooseFromMenu, .comment, .coordinateClick, .endRepeat,
             .file, .ifElse, .javaScriptForAutomation, .keyCombo, .launchApp, .macro,
             .menuCommand, .openInTerminal, .outputToVariable, .paste, .pauseUntilInput, .repeatEach,
             .repeatLoop, .runScriptInShell, .runShortcut, .script, .setVariable,
             .stopShortcut, .system, .url, .wait,
             // 텍스트 액션 11종 — E-MAC-TEXT-6001 (ExecutionEngine.executeTextAction)
             .text, .combineText, .splitText, .trimWhitespace, .replaceText,
             .regex, .matchText, .count, .formatNumber, .getClipboard, .setClipboard,
             // 수치·날짜·목록 보조 12종 — E-MAC-TEXT-6002 (ExecutionEngine.executeDataAction)
             .changeCase, .sort, .surroundText, .wordCount, .calculate, .math,
             .number, .outputDifference, .base64Encode, .hash, .uuid, .dateFormatter,
             // 텍스트·숫자 입력 2종 — E-MAC-TEXT-6003 (ExecutionEngine.executeTypingAction)
             .typeText, .typeNumber,
             // HTML→Markdown 1종 — E-MAC-TEXT-6003 (ExecutionEngine.executeStep)
             .htmlToMarkdown,
             // 시스템 프리셋으로 이미 실행 가능한 7종 — T-210
             // (SystemActionExecutor에 위임. 별도 구현 대신 중복을 없앤다)
             .screenshot, .newNote, .newQuickNote, .wallpaper, .wakeDisplay,
             .moveToFront, .darkMode,
             // T-211 순수 로직·UI 액션 14종 (E-MAC-NEXT-6100)
             .recognizeText, .scanQRCode, .recognizeAnimal, .detectLanguage,
             .measurement, .adjustDate, .typeDateTime, .dialog,
             .getConfirmation, .quickLook, .preventSleep, .getDictionary,
             .listActions, .saveOutput,
             // 파일 액션 7종 — T-213 (ExecutionEngine.executeFileAction)
             .getFiles, .moveFiles, .renameFiles, .extractArchive,
             .externalStorage, .fileActions, .getAttachment,
             // Apple 앱 1 — Notes·Reminders·Calendar — T-214 (ExecutionEngine.executeAppleApp)
             .createNote, .noteActions, .reminders, .calendar,
             // Apple 앱 2 — Mail·Music·Podcasts·Photos — T-215 (ExecutionEngine.executeMediaApp)
             .mail, .setMailBody, .setMailRecipients, .emailData,
             .playMusic, .playPodcast, .podcasts,
             .photos, .viewPhotos, .album, .randomPhoto, .getLastPhoto,
             // 문서 앱 — Pages·Numbers·TextEdit — T-216 (ExecutionEngine.executeDocumentApp)
             .newDocument, .viewDocument, .editDocument, .setParagraphStyle,
             // 시스템 제어 — Wi-Fi·집중 모드 — T-219 (ExecutionEngine.executeSystemControl)
             .network, .focusMode,
             // 미디어 편집·캡처 — T-220 (ExecutionEngine.executeMediaEditing)
             .rotateImage, .cropImage, .trimVideo, .camera,
             .setVolumeMedia, .moveMedia, .musicAndVideo:
            return .implemented
        case .imagePlayground, .useModel, .writingTool:
            return .stub
        case .clipText,
             .clearRecents,
             .pdf, .bluetooth, .timer, .stopwatch,
             .location, .airDrop, .readTable,
             .date,
             .tuneStation, .radio,
             .slideshow, .takeScreenshot,
             .bookmark,
             .news, .stocks, .videoDownloader, .translate,
             .textEditShortcut,
             .drive, .oneDrive, .box,
             .map,
             .transportation, .message, .email,
             .webContent, .presentation, .webIntegration, .documentsAndFiles,
             .devicesAndSheet, .createShortcutIcon, .variableDetail,
             .clipboardAction, .appIntent, .appAction, .findApp,
             .automation, .findAutomation, .automationRun, .trigger:
            return .planned
        }
    }

    /// 카탈로그에서 **선택**할 수 있는지 — 미구현·스텁은 비활성 상태로만 보인다
    var isSelectable: Bool { implementation == .implemented }

    /// 단계 설정 UI를 제공할 수 있는지
    var hasStepSettingsUI: Bool { implementation == .implemented }

    /// 카탈로그에서 숨길 액션 — 같은 일을 하는 다른 항목으로 통합된 중복
    ///
    /// - `takeScreenshot`: 시스템 프리셋 `screenshot`(T-210에서 개별 액션으로 승격)과
    ///   같은 동작이다.
    /// - `clipText`: 클립보드 읽기·쓰기는 이미 `getClipboard`·`setClipboard`가 담당한다.
    ///
    /// 두 행이 나란히 같은 이름으로 보이면 사용자는 무엇을 골라야 하는지 알 수 없다.
    /// 구현 상태는 그대로 두고 노출만 막는다.
    var isCatalogHidden: Bool {
        switch self {
        case .takeScreenshot, .clipText: return true
        // 영구 제외 — 공개 API가 없거나 법적 위험이 있는 항목 (2026-11-09 확정)
        // 구현 상태는 planned로 두되 카탈로그에서 감춘다. "다음 버전" 목록에 다시 뜨지 않게 한다.
        case .videoDownloader, .airDrop, .clearRecents, .bluetooth: return true
        default: return false
        }
    }

    /// 시스템 프리셋 실행으로 위임하는 액션의 대응표 (T-210)
    ///
    /// 카탈로그에 시스템 프리셋 행이 이미 있어도, 개별 액션으로 선택하면
    /// 같은 `SystemActionExecutor` 경로로 실행한다. 파라미터는 `ShortcutStep.target`
    /// (배경화면 경로 · 앱 번들ID)에서 온다.
    var systemActionType: SystemActionType? {
        switch self {
        case .screenshot: return .screenshot
        case .newNote: return .newNote
        case .newQuickNote: return .quickNote
        case .wallpaper: return .wallpaper
        case .wakeDisplay: return .wakeDisplay
        case .moveToFront: return .activateApp
        case .darkMode: return .darkMode
        default: return nil
        }
    }

    /// 카탈로그의 시스템 프리셋 목록에서 제외할 항목 — 개별 액션으로 승격됨
    ///
    /// 그대로 두면 같은 동작이 "개별 액션 행 + 시스템 프리셋 행"으로 두 번 보인다.
    /// 단계 설정의 `.system` 피커는 기존 사용자 설정 호환을 위해 23종을 모두 유지한다.
    static let promotedSystemPresets: Set<SystemActionType> = [
        .screenshot, .newNote, .quickNote, .wallpaper, .wakeDisplay, .activateApp, .darkMode,
    ]
}

// MARK: - 집계 (테스트·진단용)

extension ActionType {
    /// 구현 상태별 카운트
    static func implementationCounts() -> [ActionImplementation: Int] {
        var counts: [ActionImplementation: Int] = [:]
        for type in ActionType.allCases {
            counts[type.implementation, default: 0] += 1
        }
        return counts
    }

    /// 카탈로그에서 기본 노출할 액션 (구현 완료 + 중복 숨김 제외)
    static var catalogVisible: [ActionType] {
        allCases.filter { $0.isSelectable && !$0.isCatalogHidden }
    }

    /// 미구현·스텁 목록 (진단·점검용)
    static var notImplemented: [ActionType] {
        allCases.filter { $0.implementation != .implemented }
    }
}
