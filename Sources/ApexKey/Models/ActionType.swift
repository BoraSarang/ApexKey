import Foundation

// MARK: - ActionType 카테고리 기반 구조

/// 액션 카테고리
enum ActionCategory: String, Codable, CaseIterable, Identifiable {
    case essential        // 필수 액션 (앱실행, 시스템, 파일/URL, 스크립트, 텍스트, 다이얼로그)
    case scripting        // 코딩/스크립팅 (AppleScript, JavaScript)
    case media            // 미디어 (미리보기, 포토북, 음악, 비디오)
    case documents        // 문서 (문서편집, 번역, 텍스트, 메모, 경로)
    case location         // 위치 & 교통 (지도, 열차/버스)
    case content          // 콘텐츠 제작 (이메일, 메시지, 캘린더, 할일, 웹설정, 프레젠테이션)
    case accessories      // 주변기기 & 웹 (웹연동, 문서변환, 주변기기, 상자)
    case flowControl      // 흐름 제어 (반복, 조건문, 선택, 중지, 연산)
    case variables        // 변수 (변수 설정/상세, 클립보드,odate)
    case ai               // Apple Intelligence (모델사용, 라이팅투올, 이미지플레이그라운드)
    case appIntents       // 앱 (App Intents 실행, 앱별 동작)
    case automation       // 자동화 (트리거, 개인 자동화)
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .essential:    return "필수"
        case .scripting:    return "코딩/스크립팅"
        case .media:        return "미디어"
        case .documents:    return "문서"
        case .location:     return "위치 & 교통"
        case .content:      return "콘텐츠 제작"
        case .accessories:  return "주변기기 & 웹"
        case .flowControl:  return "흐름 제어"
        case .variables:    return "변수"
        case .ai:           return "Apple Intelligence"
        case .appIntents:   return "앱"
        case .automation:   return "자동화"
        }
    }
    
    var systemImage: String {
        switch self {
        case .essential:    return "star.fill"
        case .scripting:    return "chevron.left.forwardslash.chevron.right"
        case .media:        return "play.circle"
        case .documents:    return "doc.text"
        case .location:     return "mappin.circle"
        case .content:      return "envelope"
        case .accessories:  return "printer"
        case .flowControl:  return "arrow.triangle.branch"
        case .variables:    return "text.badge.plus"
        case .ai:           return "sparkles"
        case .appIntents:   return "app.badge.checkmark"
        case .automation:   return "bolt.heart"
        }
    }
    
    /// 해당 카테고리의 액션 타입 목록
    var actionTypes: [ActionType] {
        switch self {
        case .essential:    return [.launchApp, .menuCommand, .file, .url, .script, .system, .paste, .wait, .coordinateClick, .pauseUntilInput, .macro, .dialog, .text, .clipText, .moveToFront, .wakeDisplay, .clearRecents, .preventSleep, .wallpaper, .darkMode, .focusMode, .screenshot, .pdf, .network, .bluetooth, .timer, .stopwatch, .location, .airDrop, .newQuickNote, .newNote, .readTable, .emailData, .date]
        case .scripting:    return [.appleScript, .javaScriptForAutomation]
        case .media:        return [.quickLook, .photos, .musicAndVideo, .playMusic, .playPodcast, .tuneStation, .radio, .viewPhotos, .album, .randomPhoto, .slideshow, .getLastPhoto, .camera, .rotateImage, .cropImage, .trimVideo, .takeScreenshot, .saveOutput, .setVolumeMedia, .moveMedia, .bookmark, .podcasts, .news, .stocks, .videoDownloader]
        case .documents:    return [.editDocument, .translate, .textEditShortcut, .noteActions, .createNote, .setParagraphStyle, .newDocument, .viewDocument, .mail, .setMailBody, .setMailRecipients, .drive, .oneDrive, .box, .getFiles, .moveFiles, .renameFiles, .extractArchive, .externalStorage, .fileActions, .getConfirmation, .getAttachment, .getDictionary, .dateFormatter, .listActions, .adjustDate, .formatNumber, .math, .hash, .uuid, .outputDifference, .typeNumber, .typeText, .getClipboard, .setClipboard, .regex, .typeDateTime, .sort, .changeCase, .replaceText, .combineText, .matchText, .splitText, .trimWhitespace, .surroundText, .count, .wordCount, .calculate, .base64Encode, .htmlToMarkdown, .measurement, .scanQRCode, .recognizeText, .recognizeAnimal, .detectLanguage]
        case .location:     return [.map, .transportation]
        case .content:      return [.message, .email, .calendar, .reminders, .webContent, .presentation]
        case .accessories:  return [.webIntegration, .documentsAndFiles, .devicesAndSheet, .createShortcutIcon]
        case .flowControl:  return [.runShortcut, .repeatLoop, .repeatEach, .ifElse, .endRepeat, .stopShortcut, .chooseFromMenu, .comment, .setVariable, .variableDetail, .clipboardAction, .runScriptInShell, .number, .outputToVariable]
        case .variables:    return [.setVariable, .variableDetail, .clipboardAction, .number, .outputToVariable]
        case .ai:           return [.useModel, .writingTool, .imagePlayground]
        case .appIntents:   return [.appIntent, .appAction, .findApp]
        case .automation:   return [.automation, .findAutomation]
        }
    }
}

/// 단축키로 트리거할 액션의 종류
enum ActionType: String, Codable, CaseIterable, Identifiable {
    // === 필수 ===
    case launchApp            // 앱 실행/포커스/토글
    case menuCommand          // 타 앱의 메뉴 명령 실행 (AXUIElement)
    case file                 // 파일/폴더 열기
    case url                  // URL 열기
    case script               // 셸 스크립트 실행
    case system               // 시스템 동작 (키보드 이미지 확대, 화면잠금, 재시작, 로그아웃, 슬립, 종료, 그리기.toggle, AirPlay.toggle)
    case paste                // 붙여넣기 (클립보드 또는 특정 문자열)
    case wait                 // N초 대기
    case coordinateClick      // 좌표 클릭
    case pauseUntilInput      // 사이보그 모드 — 입력 대기
    case macro                // 매크로 녹화
    case dialog               // 대화상자 (확인/텍스트입력/가장자리)
    case text                 // 텍스트
    case clipText             // 클립보드에서 텍스트 지정
    case moveToFront          // 앱 전면으로 이동
    case wakeDisplay          // 화면 깨우기
    case clearRecents         // 최근 항목 지우기
    case preventSleep         // 잠자기 방지
    case wallpaper            // 배경화면 설정
    case darkMode             // 다크모드 토글
    case focusMode            // 집중모드 토글
    case screenshot           // 스크린샷
    case pdf                  // PDF로 저장
    case network              // Wi-Fi 컨트롤
    case bluetooth            // 블루투스 컨트롤
    case timer                // 타이머
    case stopwatch            // 스탑워치
    case location             // 위치
    case airDrop              // AirDrop
    case newQuickNote         // 새 빠른 메모
    case newNote              // 새 메모
    case readTable            // 테이블 읽기
    case emailData            // 이메일 데이터
    case date                 // 날짜
    
    // === 코딩/스크립팅 ===
    case appleScript          // AppleScript 실행
    case javaScriptForAutomation  // JavaScript for Automation (JXA)
    
    // === 미디어 ===
    case quickLook            // 빠르게 보기 (Quick Look)
    case photos               // 포토북 (단축어와 포토북 공유, 포토북 저장, 단축어에서 포토북 가져오기, 포토북 상세)
    case musicAndVideo        // 음악 & 비디오 (재생, 음악 관련 상세, 정보, 상세, 항목에 별점, 재생 음악 상세, 현재 재생 목록 상세, 음악 검색)
    case playMusic            // 음악 재생 (Apple Music)
    case playPodcast          // 팟캐스트 재생
    case tuneStation          // TuneIn 라디오국에서 재생
    case radio                // 라디오 (아이튠즈 라디오국)
    case viewPhotos           // 포토북 보기 (최근 항목, 좋아요, 스크린샷, 수제 neckline screenshot 폴더)
    case album                // 포토북 앨범 (포토북 상세, 포토북 앨범에서 검색, 포토북 앨범 항목 수)
    case randomPhoto          // 포토북에서 무작위 사진
    case slideshow            // 포토북 슬라이드쇼 (대상: 포토북 앨범, iOS 장비 카메라 롤)
    case getLastPhoto         // 포토북에서 최근 사진 (커스텀 수량)
    case camera               // 카메라 (사진 촬영)
    case rotateImage          // 이미지 회전
    case cropImage            // 이미지 자르기
    case trimVideo            // 비디오 자르기
    case takeScreenshot       // 스크린샷 캡처
    case saveOutput           // 출력 저장 (대상 선택)
    case setVolumeMedia       // 미디어 볼륨 설정
    case moveMedia            // 미디어 파일 이동 (대상: 현재 재생 항목, 그 외)
    case bookmark             // 즐겨찾기 (대상: 음악, 팟캐스트, 앱)
    case podcasts             // 팟캐스트
    case news                 // 뉴스
    case stocks               // 주식
    case videoDownloader      // 비디오 다운로더 (URL, 이름, 설정)
    
    // === 문서 ===
    case editDocument         // 문서 편집 (대상: 텍스트 편집기, Numbers)
    case translate            // 번역 (대상: 대상 언어, 원본 언어, 텍스트 입력)
    case textEditShortcut     // 텍스트 편집기 단축어 (대상: 클립보드, 세부사항)
    case noteActions          // 메모 동작 (대상: iOS15 노트, MacOS Monterrey 노트, 하위 폴더 동작, 세부사항)
    case createNote           // 메모 만들기 (대상: 전달 메모, 세부사항)
    case setParagraphStyle    // 단락 스타일 설정
    case newDocument          // 새 문서 만들기 (대상: iWork)
    case viewDocument         // 문서 보기 (대상: Numbers, Pages)
    case mail                 // 메일
    case setMailBody          // 메일 본문 설정
    case setMailRecipients    // 메일 수신자 설정
    case drive                // OneDrive (아이템 상세)
    case oneDrive             // OneDrive
    case box                  // Box
    case getFiles             // 파일 가져오기 (대상: iOS15 문서 폴더, 세부사항)
    case moveFiles            // 파일 이동
    case renameFiles          // 파일 이름 바꾸기
    case extractArchive       // 압축 풀기
    case externalStorage      // 외부 저장소
    case fileActions          // 파일 동작 (대상: Unlocker, Default Folder X, DEVONthink, iOS15 문서 폴더, 세부사항)
    case getConfirmation      // 확인 가져오기
    case getAttachment        // 첨부 파일 가져오기
    case getDictionary        // 딕셔너리 가져오기
    case dateFormatter        // 날짜 형식
    case listActions          // 리스트 동작 (대상: iOS15, Mac Monterey)
    case adjustDate           // 날짜 조정
    case formatNumber         // 숫자 형식
    case math                 // 수학
    case hash                 // 해시
    case uuid                 // UUID
    case outputDifference     // 출력 차이
    case typeNumber           // 숫자 입력
    case typeText             // 텍스트 입력
    case getClipboard         // 클립보드 가져오기
    case setClipboard         // 클립보드 설정
    case regex                // 정규 표현식
    case typeDateTime         // 날짜/시간 입력
    case sort                 // 정렬
    case changeCase           // 대소문자 변경
    case replaceText          // 텍스트 교체
    case combineText          // 텍스트 결합
    case matchText            // 텍스트 일치
    case splitText            // 텍스트 분리
    case trimWhitespace       // 공백 정리
    case surroundText         // 텍스트 감싸기
    case count                // 개수 세기
    case wordCount            // 단어 세기
    case calculate            // 계산
    case base64Encode         // Base64 인코딩/디코딩
    case htmlToMarkdown       // HTML을 Markdown으로
    case measurement          // 측정
    case scanQRCode           // QR 코드 스캔
    case recognizeText        // 텍스트 인식
    case recognizeAnimal      // 동물 인식
    case detectLanguage       // 언어 감지
    
    // === 위치 & 교통 ===
    case map                  // 지도 (출발지, 경유지, 도착지, 도착시간, 대중교통 길 안내)
    case transportation       // 지하철/버스 (이번 역, 다음역, 마지막 역)
    
    // === 콘텐츠 제작 ===
    case message              // 메시지 (메시지 내용, 받는 사람, 미리보기 on/off)
    case email                // 이메일 (제목, 받는 사람, 내용, 미리보기 on/off)
    case calendar             // 캘린더 (이벤트 세부사항: 제목, 위치, 모임 참석자, 세부사항)
    case reminders            // 할일 (할일 세부사항: 제목, 기한 날짜, 메모, 세부사항)
    case webContent           // 웹 콘텐츠 (URL에서 특징, 기사 세부사항)
    case presentation         // 프레젠테이션 (대상: Keynote, Numbers, Pages)
    
    // === 주변기기 & 웹 ===
    case webIntegration       // 웹 연동 (Get Contents of URL, Get Dictionary from Input, URLencode, 이미지 업로드)
    case documentsAndFiles    // 문서 & 파일 (세부사항 선택: Darktable, Scrivener)
    case devicesAndSheet      // 주변기기 & 시트 (대상: iOS15, Mac Monterey, 세부사항)
    case createShortcutIcon   // 단축어 아이콘 만들기
    
    // === 흐름 제어 ===
    case runShortcut          // 단축어 실행
    case repeatLoop           // 반복
    case repeatEach           // 각 항목마다 반복
    case ifElse               // If/Otherwise
    case endRepeat            // 반복 종료
    case stopShortcut         // 단축어 중지
    case chooseFromMenu       // 메뉴에서 선택
    case comment              // 코멘트 (annotations)
    
    // === 변수 ===
    case setVariable          // 변수 설정
    case variableDetail       // 변수 상세
    case clipboardAction      // 클립보드 액션
    case runScriptInShell     // 쉘에서 스크립트 실행
    case number               // 숫자
    case outputToVariable     // 출력을 변수로
    
    // === Apple Intelligence ===
    case useModel             // 모델 사용 (AI 설정, 프롬프트, Follow Up, 출력 타입)
    case writingTool          // 라이팅 툴 (교정/다시쓰기/요약/목록/표/톤변경/핵심포인트)
    case imagePlayground      // 이미지 플레이그라운드
    
    // === 앱 (App Intents) ===
    case appIntent            // 앱 (Intent 실행)
    case appAction            // 앱 동작 (Show in App Library)
    case findApp              // 앱 검색
    
    // === 자동화 ===
    case automation           // 개인 자동화 (Create Personal Automation)
    case findAutomation       // 자동화 검색
    case automationRun        // 자동화에서 실행
    case trigger              // 트리거 (When ... is changed/connected)
    
    var id: String { rawValue }
    
    var category: ActionCategory {
        switch self {
        case .launchApp, .menuCommand, .file, .url, .script, .system, .paste, .wait, .coordinateClick, .pauseUntilInput, .macro, .dialog, .text, .clipText, .moveToFront, .wakeDisplay, .clearRecents, .preventSleep, .wallpaper, .darkMode, .focusMode, .screenshot, .pdf, .network, .bluetooth, .timer, .stopwatch, .location, .airDrop, .newQuickNote, .newNote, .readTable, .emailData, .date:
            return .essential
        case .appleScript, .javaScriptForAutomation:
            return .scripting
        case .quickLook, .photos, .musicAndVideo, .playMusic, .playPodcast, .tuneStation, .radio, .viewPhotos, .album, .randomPhoto, .slideshow, .getLastPhoto, .camera, .rotateImage, .cropImage, .trimVideo, .takeScreenshot, .saveOutput, .setVolumeMedia, .moveMedia, .bookmark, .podcasts, .news, .stocks, .videoDownloader:
            return .media
        case .editDocument, .translate, .textEditShortcut, .noteActions, .createNote, .setParagraphStyle, .newDocument, .viewDocument, .mail, .setMailBody, .setMailRecipients, .drive, .oneDrive, .box, .getFiles, .moveFiles, .renameFiles, .extractArchive, .externalStorage, .fileActions, .getConfirmation, .getAttachment, .getDictionary, .dateFormatter, .listActions, .adjustDate, .formatNumber, .math, .hash, .uuid, .outputDifference, .typeNumber, .typeText, .getClipboard, .setClipboard, .regex, .typeDateTime, .sort, .changeCase, .replaceText, .combineText, .matchText, .splitText, .trimWhitespace, .surroundText, .count, .wordCount, .calculate, .base64Encode, .htmlToMarkdown, .measurement, .scanQRCode, .recognizeText, .recognizeAnimal, .detectLanguage:
            return .documents
        case .map, .transportation:
            return .location
        case .message, .email, .calendar, .reminders, .webContent, .presentation:
            return .content
        case .webIntegration, .documentsAndFiles, .devicesAndSheet, .createShortcutIcon:
            return .accessories
        case .runShortcut, .repeatLoop, .repeatEach, .ifElse, .endRepeat, .stopShortcut, .chooseFromMenu, .comment, .setVariable, .variableDetail, .clipboardAction, .runScriptInShell, .number, .outputToVariable:
            return .flowControl
        case .useModel, .writingTool, .imagePlayground:
            return .ai
        case .appIntent, .appAction, .findApp:
            return .appIntents
        case .automation, .findAutomation, .automationRun, .trigger:
            return .automation
        }
    }

    var displayName: String {
        switch self {
        // 필수
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
        case .macro:       return "매크로 녹화"
        case .dialog:      return "대화상자"
        case .text:        return "텍스트"
        case .clipText:    return "클립보드에서 텍스트 지정"
        case .moveToFront: return "앱 전면으로 이동"
        case .wakeDisplay: return "화면 깨우기"
        case .clearRecents: return "최근 항목 지우기"
        case .preventSleep: return "잠자기 방지"
        case .wallpaper:   return "배경화면"
        case .darkMode:    return "다크모드"
        case .focusMode:   return "집중모드"
        case .screenshot:  return "스크린샷"
        case .pdf:         return "PDF"
        case .network:     return "Wi-Fi"
        case .bluetooth:   return "블루투스"
        case .timer:       return "타이머"
        case .stopwatch:   return "스톱워치"
        case .location:    return "위치"
        case .airDrop:     return "AirDrop"
        case .newQuickNote: return "빠른 메모"
        case .newNote:     return "새 메모"
        case .readTable:   return "테이블 읽기"
        case .emailData:   return "이메일 데이터"
        case .date:        return "날짜"
        // 코딩/스크립팅
        case .appleScript: return "AppleScript"
        case .javaScriptForAutomation: return "JavaScript for Automation"
        // 미디어
        case .quickLook:   return "빠르게 보기"
        case .photos:      return "포토북"
        case .musicAndVideo: return "음악 & 비디오"
        case .playMusic:   return "음악 재생"
        case .playPodcast: return "팟캐스트 재생"
        case .tuneStation: return "TuneIn 라디오"
        case .radio:       return "라디오"
        case .viewPhotos:  return "포토북 보기"
        case .album:       return "포토북 앨범"
        case .randomPhoto: return "무작위 사진"
        case .slideshow:   return "슬라이드쇼"
        case .getLastPhoto: return "최근 사진"
        case .camera:      return "카메라"
        case .rotateImage: return "이미지 회전"
        case .cropImage:   return "이미지 자르기"
        case .trimVideo:   return "비디오 자르기"
        case .takeScreenshot: return "스크린샷 캡처"
        case .saveOutput:  return "출력 저장"
        case .setVolumeMedia: return "미디어 볼륨"
        case .moveMedia:   return "미디어 파일 이동"
        case .bookmark:    return "즐겨찾기"
        case .podcasts:    return "팟캐스트"
        case .news:        return "뉴스"
        case .stocks:      return "주식"
        case .videoDownloader: return "비디오 다운로더"
        // 문서
        case .editDocument: return "문서 편집"
        case .translate:   return "번역"
        case .textEditShortcut: return "텍스트 편집기 단축어"
        case .noteActions: return "메모 동작"
        case .createNote:  return "메모 만들기"
        case .setParagraphStyle: return "단락 스타일"
        case .newDocument: return "새 문서"
        case .viewDocument: return "문서 보기"
        case .mail:        return "메일"
        case .setMailBody: return "메일 본문 설정"
        case .setMailRecipients: return "메일 수신자"
        case .drive:       return "OneDrive"
        case .oneDrive:    return "OneDrive"
        case .box:         return "Box"
        case .getFiles:    return "파일 가져오기"
        case .moveFiles:   return "파일 이동"
        case .renameFiles: return "파일 이름 바꾸기"
        case .extractArchive: return "압축 풀기"
        case .externalStorage: return "외부 저장소"
        case .fileActions: return "파일 동작"
        case .getConfirmation: return "확인 가져오기"
        case .getAttachment: return "첨부 파일"
        case .getDictionary: return "딕셔너리"
        case .dateFormatter: return "날짜 형식"
        case .listActions: return "리스트 동작"
        case .adjustDate:  return "날짜 조정"
        case .formatNumber: return "숫자 형식"
        case .math:        return "수학"
        case .hash:        return "해시"
        case .uuid:        return "UUID"
        case .outputDifference: return "출력 차이"
        case .typeNumber:  return "숫자 입력"
        case .typeText:    return "텍스트 입력"
        case .getClipboard: return "클립보드 가져오기"
        case .setClipboard: return "클립보드 설정"
        case .regex:       return "정규 표현식"
        case .typeDateTime: return "날짜/시간 입력"
        case .sort:        return "정렬"
        case .changeCase:  return "대소문자 변경"
        case .replaceText: return "텍스트 교체"
        case .combineText: return "텍스트 결합"
        case .matchText:   return "텍스트 일치"
        case .splitText:   return "텍스트 분리"
        case .trimWhitespace: return "공백 정리"
        case .surroundText: return "텍스트 감싸기"
        case .count:       return "개수 세기"
        case .wordCount:   return "단어 세기"
        case .calculate:   return "계산"
        case .base64Encode: return "Base64"
        case .htmlToMarkdown: return "HTML→Markdown"
        case .measurement: return "측정"
        case .scanQRCode:  return "QR 코드 스캔"
        case .recognizeText: return "텍스트 인식"
        case .recognizeAnimal: return "동물 인식"
        case .detectLanguage: return "언어 감지"
        // 위치 & 교통
        case .map:         return "지도"
        case .transportation: return "대중교통"
        // 콘텐츠 제작
        case .message:     return "메시지"
        case .email:       return "이메일"
        case .calendar:    return "캘린더"
        case .reminders:   return "할일"
        case .webContent:  return "웹 콘텐츠"
        case .presentation: return "프레젠테이션"
        // 주변기기 & 웹
        case .webIntegration: return "웹 연동"
        case .documentsAndFiles: return "문서 & 파일"
        case .devicesAndSheet: return "주변기기 & 시트"
        case .createShortcutIcon: return "단축어 아이콘"
        // 흐름 제어
        case .runShortcut: return "단축어 실행"
        case .repeatLoop:    return "반복"
        case .repeatEach:  return "각 항목마다 반복"
        case .ifElse:      return "If/Otherwise"
        case .endRepeat:   return "반복 종료"
        case .stopShortcut: return "단축어 중지"
        case .chooseFromMenu: return "메뉴에서 선택"
        case .comment:     return "코멘트"
        // 변수
        case .setVariable: return "변수 설정"
        case .variableDetail: return "변수 상세"
        case .clipboardAction: return "클립보드 액션"
        case .runScriptInShell: return "쉘에서 스크립트 실행"
        case .number:      return "숫자"
        case .outputToVariable: return "출력을 변수로"
        // Apple Intelligence
        case .useModel:    return "모델 사용"
        case .writingTool: return "라이팅 툴"
        case .imagePlayground: return "이미지 플레이그라운드"
        // 앱
        case .appIntent:   return "앱 (Intent)"
        case .appAction:   return "앱 동작"
        case .findApp:     return "앱 검색"
        // 자동화
        case .automation:  return "개인 자동화"
        case .findAutomation: return "자동화 검색"
        case .automationRun: return "자동화에서 실행"
        case .trigger:     return "트리거"
        }
    }

    var systemImage: String {
        switch self {
        // 필수
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
        case .dialog:      return "text.bubble"
        case .text:        return "text.alignleft"
        case .clipText:    return "doc.on.clipboard"
        case .moveToFront: return "arrow.up.forward.app"
        case .wakeDisplay: return "display"
        case .clearRecents: return "clock.arrow.circlepath"
        case .preventSleep: return "moon.zzz"
        case .wallpaper:   return "photo"
        case .darkMode:    return "moon.fill"
        case .focusMode:   return "moon.circle"
        case .screenshot:  return "camera.viewfinder"
        case .pdf:         return "doc.richtext"
        case .network:     return "wifi"
        case .bluetooth:   return "antenna.radiowaves.left.and.right"
        case .timer:       return "timer"
        case .stopwatch:   return "stopwatch"
        case .location:    return "mappin.circle"
        case .airDrop:     return "airplayaudio"
        case .newQuickNote: return "rectangle.dashed.badge.record"
        case .newNote:     return "doc.plaintext"
        case .readTable:   return "tablecells"
        case .emailData:   return "envelope"
        case .date:        return "calendar"
        // 코딩/스크립팅
        case .appleScript: return "applelogo"
        case .javaScriptForAutomation: return "chevron.left.forwardslash.chevron.right"
        // 미디어
        case .quickLook:   return "eye"
        case .photos:      return "photo.stack"
        case .musicAndVideo: return "play.circle"
        case .playMusic:   return "music.note"
        case .playPodcast: return "mic.circle"
        case .tuneStation: return "radio"
        case .radio:       return "antenna.radiowaves.left.and.right"
        case .viewPhotos:  return "photo.on.rectangle"
        case .album:       return "rectangle.stack"
        case .randomPhoto: return "shuffle"
        case .slideshow:   return "rectangle.stack.badge.play"
        case .getLastPhoto: return "photo.stack"
        case .camera:      return "camera"
        case .rotateImage: return "arrow.triangle.2.circlepath"
        case .cropImage:   return "crop"
        case .trimVideo:   return "scissors"
        case .takeScreenshot: return "camera.viewfinder"
        case .saveOutput:  return "square.and.arrow.down"
        case .setVolumeMedia: return "speaker.wave.2"
        case .moveMedia:   return "folder.move"
        case .bookmark:    return "bookmark"
        case .podcasts:    return "mic.fill"
        case .news:        return "newspaper"
        case .stocks:      return "chart.line.uptrend.xyaxis"
        case .videoDownloader: return "arrow.down.circle"
        // 문서
        case .editDocument: return "doc.text"
        case .translate:   return "character.bubble"
        case .textEditShortcut: return "textformat"
        case .noteActions: return "note.text"
        case .createNote:  return "plus.square.on.square"
        case .setParagraphStyle: return "paragraphsign"
        case .newDocument: return "doc.badge.plus"
        case .viewDocument: return "doc.text.magnifyingglass"
        case .mail:        return "envelope"
        case .setMailBody: return "text.alignleft"
        case .setMailRecipients: return "person.circle"
        case .drive:       return "cloud"
        case .oneDrive:    return "cloud.fill"
        case .box:         return "archivebox"
        case .getFiles:    return "folder.badge.questionmark"
        case .moveFiles:   return "folder.move"
        case .renameFiles: return "pencil.circle"
        case .extractArchive: return "archivebox"
        case .externalStorage: return "externaldrive"
        case .fileActions: return "doc.text.badge.gearshape"
        case .getConfirmation: return "questionmark.circle"
        case .getAttachment: return "paperclip"
        case .getDictionary: return "list.bullet.rectangle"
        case .dateFormatter: return "calendar.badge.clock"
        case .listActions: return "list.bullet"
        case .adjustDate:  return "calendar.badge.minus"
        case .formatNumber: return "number"
        case .math:        return "function"
        case .hash:        return "number.square"
        case .uuid:        return "fingerprint"
        case .outputDifference: return "minus.plus.circle"
        case .typeNumber:  return "textformat.123"
        case .typeText:    return "textformat"
        case .getClipboard: return "doc.on.clipboard"
        case .setClipboard: return "doc.on.clipboard.fill"
        case .regex:       return "text.magnifyingglass"
        case .typeDateTime: return "calendar.badge.clock"
        case .sort:        return "arrow.up.arrow.down"
        case .changeCase:  return "textformat.abc"
        case .replaceText: return "arrow.triangle.swap"
        case .combineText: return "rectangle.rightthird.inward"
        case .matchText:   return "checkmark.circle"
        case .splitText:   return "rectangle.split.3x1"
        case .trimWhitespace: return "scissors"
        case .surroundText: return "text.badge.plus"
        case .count:       return "number.circle"
        case .wordCount:   return "text.word.spacing"
        case .calculate:   return "function.math"
        case .base64Encode: return "lock.rotation"
        case .htmlToMarkdown: return "doc.richtext"
        case .measurement: return "ruler"
        case .scanQRCode:  return "qrcode.viewfinder"
        case .recognizeText: return "text.viewfinder"
        case .recognizeAnimal: return "pawprint"
        case .detectLanguage: return "globe"
        // 위치 & 교통
        case .map:         return "map"
        case .transportation: return "tram.fill"
        // 콘텐츠 제작
        case .message:     return "message"
        case .email:       return "envelope"
        case .calendar:    return "calendar"
        case .reminders:   return "checkmark.circle"
        case .webContent:  return "globe"
        case .presentation: return "rectangle.on.rectangle"
        // 주변기기 & 웹
        case .webIntegration: return "network"
        case .documentsAndFiles: return "doc.on.doc"
        case .devicesAndSheet: return "desktopcomputer"
        case .createShortcutIcon: return "app.badge"
        // 흐름 제어
        case .runShortcut: return "play.circle"
        case .repeatLoop:    return "repeat"
        case .repeatEach:  return "list.number"
        case .ifElse:      return "arrow.triangle.branch"
        case .endRepeat:   return "stop.circle"
        case .stopShortcut: return "xmark.circle"
        case .chooseFromMenu: return "list.bullet.rectangle"
        case .comment:     return "bubble.left"
        // 변수
        case .setVariable: return "text.badge.plus"
        case .variableDetail: return "info.circle"
        case .clipboardAction: return "doc.on.clipboard"
        case .runScriptInShell: return "terminal"
        case .number:      return "number"
        case .outputToVariable: return "arrow.right.circle"
        // Apple Intelligence
        case .useModel:    return "sparkles"
        case .writingTool: return "pencil.and.outline"
        case .imagePlayground: return "photo.on.rectangle.angled"
        // 앱
        case .appIntent:   return "app.badge.checkmark"
        case .appAction:   return "app.badge"
        case .findApp:     return "magnifyingglass"
        // 자동화
        case .automation:  return "bolt.heart"
        case .findAutomation: return "magnifyingglass.circle"
        case .automationRun: return "play.circle.fill"
        case .trigger:     return "bolt"
        }
    }
}