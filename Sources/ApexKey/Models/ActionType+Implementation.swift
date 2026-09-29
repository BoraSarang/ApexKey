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
    /// **컴파일 타임 정합성**: 아래 switch 에 `default:`가 없고 153개 case를 빠짐없이 나열한다.
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
             .menuCommand, .outputToVariable, .paste, .pauseUntilInput, .repeatEach,
             .repeatLoop, .runScriptInShell, .runShortcut, .script, .setVariable,
             .stopShortcut, .system, .url, .wait,
             // 텍스트 액션 11종 — E-MAC-TEXT-6001 (ExecutionEngine.executeTextAction)
             .text, .combineText, .splitText, .trimWhitespace, .replaceText,
             .regex, .matchText, .count, .formatNumber, .getClipboard, .setClipboard,
             // 수치·날짜·목록 보조 12종 — E-MAC-TEXT-6002 (ExecutionEngine.executeDataAction)
             .changeCase, .sort, .surroundText, .wordCount, .calculate, .math,
             .number, .outputDifference, .base64Encode, .hash, .uuid, .dateFormatter:
            return .implemented
        case .imagePlayground, .useModel, .writingTool:
            return .stub
        case .dialog, .clipText, .moveToFront, .wakeDisplay,
             .clearRecents, .preventSleep, .wallpaper, .darkMode, .focusMode,
             .screenshot, .pdf, .network, .bluetooth, .timer, .stopwatch,
             .location, .airDrop, .newQuickNote, .newNote, .readTable,
             .emailData, .date, .quickLook, .photos, .musicAndVideo,
             .playMusic, .playPodcast, .tuneStation, .radio, .viewPhotos,
             .album, .randomPhoto, .slideshow, .getLastPhoto, .camera,
             .rotateImage, .cropImage, .trimVideo, .takeScreenshot,
             .saveOutput, .setVolumeMedia, .moveMedia, .bookmark, .podcasts,
             .news, .stocks, .videoDownloader, .editDocument, .translate,
             .textEditShortcut, .noteActions, .createNote,
             .setParagraphStyle, .newDocument, .viewDocument, .mail,
             .setMailBody, .setMailRecipients, .drive, .oneDrive, .box,
             .getFiles, .moveFiles, .renameFiles, .extractArchive,
             .externalStorage, .fileActions, .getConfirmation,
             .getAttachment, .getDictionary, .listActions,
             .adjustDate, .typeNumber, .typeText,
             .typeDateTime,
             .htmlToMarkdown, .measurement, .scanQRCode,
             .recognizeText, .recognizeAnimal, .detectLanguage, .map,
             .transportation, .message, .email, .calendar, .reminders,
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

    /// 카탈로그에서 기본 노출할 액션 (구현 완료만)
    static var catalogVisible: [ActionType] { allCases.filter(\.isSelectable) }

    /// 미구현·스텁 목록 (진단·점검용)
    static var notImplemented: [ActionType] {
        allCases.filter { $0.implementation != .implemented }
    }
}
