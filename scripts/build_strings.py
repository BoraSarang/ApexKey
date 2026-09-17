#!/usr/bin/env python3
"""Build complete Localizable.strings files for ko and en."""
import re
import hashlib
from pathlib import Path

def gen_ui_key(value):
    clean = re.sub(r'[^\w\s]', '', value)
    words = clean.split()[:4]
    slug = '_'.join(w.lower() for w in words if w)
    if not slug:
        slug = hashlib.md5(value.encode()).hexdigest()[:8]
    return f"ui.{slug}"

# ── Settings (38) ──────────────────────────────────────────────
settings = {
    "settings.title": ("설정", "Settings"),
    "settings.display": ("표시", "Display"),
    "settings.show_in_menubar": ("메뉴바에 표시", "Show in Menu Bar"),
    "settings.show_in_dock": ("Dock에 표시", "Show in Dock"),
    "settings.launch_at_login": ("로그인 시 시작", "Launch at Login"),
    "settings.show_hidden_apps": ("숨김 앱 표시", "Show Hidden Apps"),
    "settings.show_system_apps": ("시스템 앱 표시", "Show System Apps"),
    "settings.panel_hotkey": ("패널 단축키", "Panel Hotkey"),
    "settings.panel_hotkey.current": ("현재", "Current"),
    "settings.panel_hotkey.description": ("메인 패널을 열고 닫는 전역 단축키 (⇧⌥A 기본).", "Global hotkey to open/close main panel (default ⇧⌥A)."),
    "settings.panel_hotkey.change": ("단축키 변경", "Change Hotkey"),
    "settings.panel_hotkey.reset": ("기본값 복원", "Restore Default"),
    "settings.menu_hud": ("메뉴 단축키 HUD", "Menu Shortcut HUD"),
    "settings.menu_hud.current": ("현재", "Current"),
    "settings.menu_hud.description": ("현재 전면 앱의 모든 메뉴 단축키를 표시 (⇧⌥S 기본).", "Show all menu shortcuts of frontmost app (default ⇧⌥S)."),
    "settings.menu_hud.style": ("표시 방식", "Display Style"),
    "settings.menu_hud.style.floating": ("플로팅 창", "Floating Window"),
    "settings.menu_hud.style.fullscreen": ("전체 보기", "Full Screen"),
    "settings.menu_hud.change": ("단축키 변경", "Change Hotkey"),
    "settings.menu_hud.reset": ("기본값 복원", "Restore Default"),
    "settings.permissions": ("권한", "Permissions"),
    "settings.permissions.accessibility": ("손쉬운 사용(Accessibility)", "Accessibility"),
    "settings.permissions.accessibility.granted": ("✅ 허용됨", "✅ Granted"),
    "settings.permissions.accessibility.request": ("권한 요청", "Request Permission"),
    "settings.permissions.accessibility.description": ("메뉴 단축키 열거·실행과 타 앱 제어에 필요합니다.", "Required for menu shortcut enumeration/execution and controlling other apps."),
    "settings.theme": ("테마", "Theme"),
    "settings.language": ("언어", "Language"),
    "settings.language.system": ("시스템 설정 따라가기", "Follow System"),
    "settings.language.korean": ("한국어", "한국어"),
    "settings.language.english": ("English", "English"),
    "settings.language.restart_required": ("언어 변경은 앱 재시작 후 적용됩니다.", "Language change takes effect after app restart."),
    "settings.show_in_menubar.description": ("끄면 메뉴바 아이콘이 사라집니다.", "Menu bar icon will disappear when turned off."),
    "settings.show_in_dock.description": ("켜면 Dock 아이콘으로도 접근할 수 있습니다.", "If Dock is also disabled, you cannot access the app. Enable Show in Dock first."),
    "alert.menubar_cannot_disable.title": ("메뉴바를 끌 수 없습니다", "Cannot Disable Menu Bar"),
    "alert.menubar_cannot_disable.message": ("Dock에 표시도 꺼져 있으면 앱에 접근할 수 없습니다. Dock에 표시를 먼저 켜주세요.", "If both Menu Bar and Dock are disabled, you cannot access the app. Enable Show in Dock first."),
    "toast.hotkey_duplicate": ("이미 사용 중인 단축키입니다.", "This hotkey is already in use."),
    "toast.script_test_success": ("스크립트 테스트 성공", "Script test succeeded"),
    "toast.script_test_failed": ("스크립트 테스트 실패", "Script test failed"),
    "ui.step_settings.test_run": ("테스트 실행", "Run Test"),
    "ui.step_settings.test_output": ("실행 결과", "Output"),
    "ui.step_settings.running": ("실행 중…", "Running…"),
    "ui.step_settings.no_output": ("(출력 없음)", "(no output)"),
    "ui.step_settings.exit_code": ("종료 코드: %lld", "Exit code: %lld"),
}

# ── Action keys (152) ──────────────────────────────────────────
actions = {
    "action.launchApp": ("앱 실행/토글", "Launch App / Toggle"),
    "action.menuCommand": ("메뉴 명령", "Menu Command"),
    "action.file": ("파일/폴더", "File / Folder"),
    "action.url": ("URL", "URL"),
    "action.script": ("스크립트", "Script"),
    "action.system": ("시스템", "System"),
    "action.paste": ("붙여넣기", "Paste"),
    "action.wait": ("대기", "Wait"),
    "action.coordinateClick": ("좌표 클릭", "Coordinate Click"),
    "action.pauseUntilInput": ("입력 대기", "Pause Until Input"),
    "action.macro": ("매크로 녹화", "Record Macro"),
    "action.dialog": ("대화상자", "Dialog"),
    "action.text": ("텍스트", "Text"),
    "action.clipText": ("클립보드에서 텍스트 지정", "Clipboard Text"),
    "action.moveToFront": ("앱 전면으로 이동", "Move to Front"),
    "action.wakeDisplay": ("화면 깨우기", "Wake Display"),
    "action.clearRecents": ("최근 항목 지우기", "Clear Recents"),
    "action.preventSleep": ("잠자기 방지", "Prevent Sleep"),
    "action.wallpaper": ("배경화면", "Wallpaper"),
    "action.darkMode": ("다크모드", "Dark Mode"),
    "action.focusMode": ("집중모드", "Focus Mode"),
    "action.screenshot": ("스크린샷", "Screenshot"),
    "action.pdf": ("PDF", "PDF"),
    "action.network": ("Wi-Fi", "Wi-Fi"),
    "action.bluetooth": ("블루투스", "Bluetooth"),
    "action.timer": ("타이머", "Timer"),
    "action.stopwatch": ("스톱워치", "Stopwatch"),
    "action.location": ("위치", "Location"),
    "action.airDrop": ("AirDrop", "AirDrop"),
    "action.newQuickNote": ("빠른 메모", "Quick Note"),
    "action.newNote": ("새 메모", "New Note"),
    "action.readTable": ("테이블 읽기", "Read Table"),
    "action.emailData": ("이메일 데이터", "Email Data"),
    "action.date": ("날짜", "Date"),
    "action.appleScript": ("AppleScript", "AppleScript"),
    "action.javaScriptForAutomation": ("JavaScript for Automation", "JavaScript for Automation"),
    "action.quickLook": ("빠르게 보기", "Quick Look"),
    "action.photos": ("포토북", "Photos"),
    "action.musicAndVideo": ("음악 & 비디오", "Music & Video"),
    "action.playMusic": ("음악 재생", "Play Music"),
    "action.playPodcast": ("팟캐스트 재생", "Play Podcast"),
    "action.tuneStation": ("TuneIn 라디오", "TuneIn Radio"),
    "action.radio": ("라디오", "Radio"),
    "action.viewPhotos": ("포토북 보기", "View Photos"),
    "action.album": ("포토북 앨범", "Photo Album"),
    "action.randomPhoto": ("무작위 사진", "Random Photo"),
    "action.slideshow": ("슬라이드쇼", "Slideshow"),
    "action.getLastPhoto": ("최근 사진", "Get Last Photo"),
    "action.camera": ("카메라", "Camera"),
    "action.rotateImage": ("이미지 회전", "Rotate Image"),
    "action.cropImage": ("이미지 자르기", "Crop Image"),
    "action.trimVideo": ("비디오 자르기", "Trim Video"),
    "action.takeScreenshot": ("스크린샷 캡처", "Take Screenshot"),
    "action.saveOutput": ("출력 저장", "Save Output"),
    "action.setVolumeMedia": ("미디어 볼륨", "Media Volume"),
    "action.moveMedia": ("미디어 파일 이동", "Move Media"),
    "action.bookmark": ("즐겨찾기", "Bookmark"),
    "action.podcasts": ("팟캐스트", "Podcasts"),
    "action.news": ("뉴스", "News"),
    "action.stocks": ("주식", "Stocks"),
    "action.videoDownloader": ("비디오 다운로더", "Video Downloader"),
    "action.editDocument": ("문서 편집", "Edit Document"),
    "action.translate": ("번역", "Translate"),
    "action.textEditShortcut": ("텍스트 편집기 단축어", "Text Editor Shortcut"),
    "action.noteActions": ("메모 동작", "Note Actions"),
    "action.createNote": ("메모 만들기", "Create Note"),
    "action.setParagraphStyle": ("단락 스타일", "Set Paragraph Style"),
    "action.newDocument": ("새 문서", "New Document"),
    "action.viewDocument": ("문서 보기", "View Document"),
    "action.mail": ("메일", "Mail"),
    "action.setMailBody": ("메일 본문 설정", "Set Mail Body"),
    "action.setMailRecipients": ("메일 수신자 설정", "Set Mail Recipients"),
    "action.drive": ("OneDrive", "OneDrive"),
    "action.oneDrive": ("OneDrive", "OneDrive"),
    "action.box": ("Box", "Box"),
    "action.getFiles": ("파일 가져오기", "Get Files"),
    "action.moveFiles": ("파일 이동", "Move Files"),
    "action.renameFiles": ("파일 이름 바꾸기", "Rename Files"),
    "action.extractArchive": ("압축 풀기", "Extract Archive"),
    "action.externalStorage": ("외부 저장소", "External Storage"),
    "action.fileActions": ("파일 동작", "File Actions"),
    "action.getConfirmation": ("확인 가져오기", "Get Confirmation"),
    "action.getAttachment": ("첨부 파일 가져오기", "Get Attachment"),
    "action.getDictionary": ("딕셔너리 가져오기", "Get Dictionary"),
    "action.dateFormatter": ("날짜 형식", "Date Formatter"),
    "action.listActions": ("리스트 동작", "List Actions"),
    "action.adjustDate": ("날짜 조정", "Adjust Date"),
    "action.formatNumber": ("숫자 형식", "Format Number"),
    "action.math": ("수학", "Math"),
    "action.hash": ("해시", "Hash"),
    "action.uuid": ("UUID", "UUID"),
    "action.outputDifference": ("출력 차이", "Output Difference"),
    "action.typeNumber": ("숫자 입력", "Type Number"),
    "action.typeText": ("텍스트 입력", "Type Text"),
    "action.getClipboard": ("클립보드 가져오기", "Get Clipboard"),
    "action.setClipboard": ("클립보드 설정", "Set Clipboard"),
    "action.regex": ("정규 표현식", "Regular Expression"),
    "action.typeDateTime": ("날짜/시간 입력", "Type Date/Time"),
    "action.sort": ("정렬", "Sort"),
    "action.changeCase": ("대소문자 변경", "Change Case"),
    "action.replaceText": ("텍스트 교체", "Replace Text"),
    "action.combineText": ("텍스트 결합", "Combine Text"),
    "action.matchText": ("텍스트 일치", "Match Text"),
    "action.splitText": ("텍스트 분리", "Split Text"),
    "action.trimWhitespace": ("공백 정리", "Trim Whitespace"),
    "action.surroundText": ("텍스트 감싸기", "Surround Text"),
    "action.count": ("개수 세기", "Count"),
    "action.wordCount": ("단어 세기", "Word Count"),
    "action.calculate": ("계산", "Calculate"),
    "action.base64Encode": ("Base64", "Base64 Encode/Decode"),
    "action.htmlToMarkdown": ("HTML→Markdown", "HTML to Markdown"),
    "action.measurement": ("측정", "Measurement"),
    "action.scanQRCode": ("QR 코드 스캔", "Scan QR Code"),
    "action.recognizeText": ("텍스트 인식", "Recognize Text"),
    "action.recognizeAnimal": ("동물 인식", "Recognize Animal"),
    "action.detectLanguage": ("언어 감지", "Detect Language"),
    "action.map": ("지도", "Map"),
    "action.transportation": ("대중교통", "Transportation"),
    "action.message": ("메시지", "Message"),
    "action.email": ("이메일", "Email"),
    "action.calendar": ("캘린더", "Calendar"),
    "action.reminders": ("할일", "Reminders"),
    "action.webContent": ("웹 콘텐츠", "Web Content"),
    "action.presentation": ("프레젠테이션", "Presentation"),
    "action.webIntegration": ("웹 연동", "Web Integration"),
    "action.documentsAndFiles": ("문서 & 파일", "Documents & Files"),
    "action.devicesAndSheet": ("주변기기 & 시트", "Devices & Sheet"),
    "action.createShortcutIcon": ("단축어 아이콘", "Create Shortcut Icon"),
    "action.runShortcut": ("단축어 실행", "Run Shortcut"),
    "action.repeatLoop": ("반복", "Repeat"),
    "action.repeatEach": ("각 항목마다 반복", "Repeat Each"),
    "action.ifElse": ("If/Otherwise", "If/Otherwise"),
    "action.endRepeat": ("반복 종료", "End Repeat"),
    "action.stopShortcut": ("단축어 중지", "Stop Shortcut"),
    "action.chooseFromMenu": ("메뉴에서 선택", "Choose from Menu"),
    "action.comment": ("코멘트", "Comment"),
    "action.setVariable": ("변수 설정", "Set Variable"),
    "action.variableDetail": ("변수 상세", "Variable Detail"),
    "action.clipboardAction": ("클립보드 액션", "Clipboard Action"),
    "action.runScriptInShell": ("쉘에서 스크립트 실행", "Run Script in Shell"),
    "action.number": ("숫자", "Number"),
    "action.outputToVariable": ("출력을 변수로", "Output to Variable"),
    "action.useModel": ("모델 사용", "Use Model"),
    "action.writingTool": ("라이팅 툴", "Writing Tool"),
    "action.imagePlayground": ("이미지 플레이그라운드", "Image Playground"),
    "action.appIntent": ("앱 (Intent)", "App (Intent)"),
    "action.appAction": ("앱 동작", "App Action"),
    "action.findApp": ("앱 검색", "Find App"),
    "action.automation": ("개인 자동화", "Personal Automation"),
    "action.findAutomation": ("자동화 검색", "Find Automation"),
    "action.automationRun": ("자동화에서 실행", "Automation Run"),
    "action.trigger": ("트리거", "Trigger"),
}

# ── UI strings (62) ────────────────────────────────────────────
ui_strings = {
    "ESC 또는 ⇧⌥S로 닫기 · Enter로 실행": "ESC or ⇧⌥S to close · Enter to execute",
    "ESC로 닫기": "Close with ESC",
    "If 조건": "If Condition",
    "URL을 입력하세요": "Enter URL",
    "x,y 좌표를 입력하세요 (예: 500,400)": "Enter x,y coordinates (e.g., 500,400)",
    "⌘ CMD  ·  ⌃ Ctrl  ·  ⇧ Shift  ·  ⌥ Option  ·  🌐 지구본": "⌘ CMD  ·  ⌃ Ctrl  ·  ⇧ Shift  ·  ⌥ Option  ·  🌐 Globe",
    "⌘⇧↩를 누를 때까지 대기합니다": "Wait until ⌘⇧↩ is pressed",
    "검색": "Search",
    "검색 결과 없음": "No search results",
    "검색 결과가 없습니다.": "No search results.",
    "그 외(Otherwise) 분기는 단계를 If 아래에 삽입해 관리합니다.": "Otherwise branch is managed by inserting steps under If.",
    "기본값 (선택사항)": "Default Value (Optional)",
    "단계 없음": "No Steps",
    "단계를 드래그하여 순서를 변경할 수 있습니다": "Drag steps to reorder",
    "단축키가 있는 메뉴 항목을 찾지 못했습니다": "No menu items with shortcuts found",
    "대기 시간을 초 단위로 입력하세요": "Enter wait time in seconds",
    "대상을 입력하세요": "Enter target",
    "동작": "Shortcut",
    "등록된 동작이 없습니다. '새 동작'으로 시작하세요.": "No registered shortcuts. Start with 'New Shortcut'.",
    "등록된 자동화가 없습니다. 아래에서 트리거를 추가하세요.": "No registered automations. Add triggers below.",
    "메뉴 명령은 액션 카탈로그에서 직접 선택합니다": "Menu commands are selected directly from the action catalog",
    "메뉴 선택": "Choose from Menu",
    "변수": "Variables",
    "붙여넣을 텍스트를 입력하세요 (비우면 클립보드)": "Enter text to paste (leave empty for clipboard)",
    "새 동작": "New Shortcut",
    "새 사용자 변수": "New User Variable",
    "새 트리거 추가": "Add New Trigger",
    "선택 사항": "Optional",
    "설정된 단축키가 없습니다. 아래 메뉴 단축키에서 선택해 추가하세요.": "No shortcut assigned. Select from menu shortcuts below to add.",
    "셸 명령을 입력하세요": "Enter shell command",
    "손쉬운 사용 권한 필요 — 활성화": "Accessibility Permission Required — Enable",
    "스킵": "Skip",
    "시스템 동작": "System Actions",
    "시스템 동작에 글로벌 단축키를 할당": "Assign Global Hotkeys to System Actions",
    "시스템 동작을 선택하세요": "Select System Action",
    "실행할 앱을 선택하세요": "Select App to Run",
    "아이콘을 클릭해 시스템 동작에 글로벌 단축키를 할당하거나 직접 실행할 수 있습니다.": "Click icon to assign global hotkey to system action or run directly.",
    "앱 열기, 키 입력, 스크립트, 붙여넣기 등을 단계로 쌓아 하나의 동작으로 만듭니다. 실행 버튼으로 테스트하고 단축키를 지정할 수 있습니다.": "Build a shortcut by stacking steps like open app, key input, script, paste. Test with Run button and assign hotkey.",
    "앱이 없습니다": "No App",
    "없음 — 실행/포커스/토글 단축키를 설정하세요.": "None — Set Run/Focus/Toggle Hotkey",
    "여러 단계를 하나로 묶어 실행·단축키 지정": "Combine multiple steps into one shortcut with hotkey",
    "오른쪽 값": "Right Value",
    "옵션": "Options",
    "왼쪽 값": "Left Value",
    "왼쪽 액션 카탈로그에서 액션을 추가하세요": "Add actions from the action catalog on the left",
    "이 단계는 실행 중 이 값을 변수로 설정합니다. 매직 변수 연결은 변수 패널에서 구성합니다.": "This step sets this value to a variable during execution. Magic variable connections are configured in the variable panel.",
    "이 액션은 추가 설정이 필요하지 않습니다": "This action requires no additional settings",
    "이름": "Name",
}

def save_strings(path, ko_map, en_map):
    """Write .strings file in UTF-16 encoding."""
    lines = []
    all_keys = sorted(set(list(ko_map.keys()) + list(en_map.keys())))
    for key in all_keys:
        val_ko = ko_map.get(key, key)
        val_en = en_map.get(key, key)
        # Escape for .strings format
        val_ko = val_ko.replace('\\', '\\\\').replace('"', '\\"')
        val_en = val_en.replace('\\', '\\\\').replace('"', '\\"')
        key_esc = key.replace('\\', '\\\\').replace('"', '\\"')
        lines.append(f'"{key_esc}" = "{val_en}";')
    content = '\n'.join(lines) + '\n'
    path.write_text(content, encoding='utf-16')

def main():
    ko_map = {}
    en_map = {}

    # Settings
    for key, (ko, en) in settings.items():
        ko_map[key] = ko
        en_map[key] = en

    # Actions
    for key, (ko, en) in actions.items():
        ko_map[key] = ko
        en_map[key] = en

    # UI strings
    for ko_val, en_val in ui_strings.items():
        key = gen_ui_key(ko_val)
        ko_map[key] = ko_val
        en_map[key] = en_val

    # Save
    ko_path = Path('Sources/ApexKey/ko.lproj/Localizable.strings')
    en_path = Path('Sources/ApexKey/en.lproj/Localizable.strings')
    save_strings(ko_path, ko_map, en_map)

    print(f"ko: {len(ko_map)} entries")
    print(f"en: {len(en_map)} entries")
    print(f"ko saved: {ko_path}")
    print(f"en saved: {en_path}")

if __name__ == '__main__':
    main()
