#!/usr/bin/env python3
"""ApexKey macOS 전체 현지화 스크립트 (v3)
- 기존 strings 파일 병합 유지 (settings.*/action.*/alert.*/toast.*)
- 뷰 + 모델의 한국어 문자열을 ASCII 키로 치환 (-> "key".localized)
- interpolated 문자열 -> .localizedFormat(...)
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "Sources" / "ApexKey"

FILES = sorted(SRC.glob("Views/*.swift")) + [
    SRC / "AppDelegate.swift",
    SRC / "Models" / "ActionType.swift",
    SRC / "Models" / "AutomationModels.swift",
    SRC / "Models" / "AIModels.swift",
]

# ── 데이터 구조 ────────────────────────────────────────────────
ENTRIES = {}      # key -> (ko_format, en_format)
SRC_SIMPLE = {}   # 소스 리터럴(따옴표 제외) -> key
SRC_INTERP = {}   # 소스 리터럴(따옴표 제외) -> (key, [expr])

def expr_of(src):
    """\(...) 표현식 추출"""
    return re.findall(r"\\\(([^()]*)\)", src)

def add(key, ko, en):
    ENTRIES[key] = (ko, en)
    SRC_SIMPLE[ko] = key

def add_interp(key, ko_fmt, en_fmt, src, exprs=None):
    ENTRIES[key] = (ko_fmt, en_fmt)
    SRC_INTERP[src] = (key, exprs if exprs is not None else expr_of(src))

# ══════════════════════════════════════════════════════════════
# 공통
# ══════════════════════════════════════════════════════════════
add("ui.done", "완료", "Done")
add("ui.cancel", "취소", "Cancel")
add("ui.add", "추가", "Add")
add("ui.delete", "삭제", "Delete")
add("ui.run", "실행", "Run")
add("ui.save", "저장", "Save")
add("ui.copy", "복사", "Copy")
add("ui.clear", "지우기", "Clear")
add("ui.name", "이름", "Name")
add("ui.search", "검색", "Search")
add("ui.path", "경로", "Path")
add("ui.browse", "찾기", "Browse")
add("ui.target", "대상", "Target")
add("ui.text", "텍스트", "Text")
add("ui.hotkey", "단축키", "Hotkey")
add("ui.test", "테스트", "Test")
add("ui.shortcut", "동작", "Shortcut")
add("ui.variables", "변수", "Variables")
add("ui.options", "옵션", "Options")
add("ui.skip", "스킵", "Skip")
add("ui.rename", "이름 변경", "Rename")
add("ui.edit", "편집", "Edit")
add("ui.info", "정보", "Info")
add("ui.open", "열기", "Open")
add("ui.quit", "종료", "Quit")
add("ui.repeat", "반복", "Repeat")
add("ui.prompt", "프롬프트", "Prompt")
add("ui.model", "모델", "Model")
add("ui.style", "스타일", "Style")
add("ui.tone", "톤", "Tone")
add("ui.title", "제목", "Title")
add("ui.category", "카테고리", "Category")
add("ui.command", "명령", "Command")
add("ui.output", "출력", "Output")
add("ui.description", "설명", "Description")
add("ui.select_option", "옵션을 선택하세요", "Select an option…")
add("ui.default_optional", "기본값 (선택사항)", "Default Value (Optional)")
add("ui.label_optional", "라벨 (선택)", "Label (Optional)")
add("ui.output_type", "출력 타입", "Output Type")
add("ui.system_label", "시스템", "System")
add("ui.automation_label", "자동화", "Automation")
add("ui.app_label", "앱", "Apps")

# ══════════════════════════════════════════════════════════════
# Views
# ══════════════════════════════════════════════════════════════
# AboutView
add("ui.about.app_name", "애펙스키", "ApexKey")
add("ui.about.tagline", "최상위(정점)에 오른 글로벌 단축키 매니저", "The global hotkey manager at the top")
add_interp("ui.about.version", "버전 %@", "Version %@", r"버전 \(version)")

# ActionCatalogView / ActionDetailView
add("ui.catalog.add_action", "액션 추가", "Add Action")
add("ui.catalog.no_results", "검색 결과 없음", "No search results")
add("ui.app_detail.run_app_prompt", "실행할 앱을 선택하세요", "Select an app to run")
add("ui.app_detail.bundle_id", "번들 ID", "Bundle ID")
add("ui.app_detail.shell_prompt", "셸 명령을 입력하세요", "Enter shell command")
add("ui.app_detail.url_prompt", "URL을 입력하세요", "Enter URL")
add("ui.app_detail.file_prompt", "파일/폴더 경로를 입력하세요", "Enter file/folder path")
add("ui.app_detail.select_system", "시스템 동작을 선택하세요", "Select System Action")
add("ui.app_detail.clipboard_prompt", "붙여넣을 텍스트를 입력하세요 (비우면 클립보드)", "Enter text to paste (leave empty for clipboard)")
add("ui.app_detail.wait_prompt", "대기 시간을 초 단위로 입력하세요", "Enter wait time in seconds")
add("ui.app_detail.menu_note", "메뉴 명령은 액션 카탈로그에서 직접 선택합니다", "Menu commands are selected directly from the action catalog")
add("ui.app_detail.coordinate_prompt", "x,y 좌표를 입력하세요 (예: 500,400)", "Enter x,y coordinates (e.g., 500,400)")
add("ui.app_detail.keycode_prompt", "키코드를 쉼표로 구분하여 입력하세요", "Enter keycodes separated by commas")
add("ui.app_detail.wait_until", "⌘⇧↩를 누를 때까지 대기합니다", "Wait until ⌘⇧↩ is pressed")
add("ui.app_detail.no_settings", "이 액션은 추가 설정이 필요하지 않습니다", "This action requires no additional settings")
add("ui.app_detail.target_prompt", "대상을 입력하세요", "Enter target")

# AppDetailView
add("ui.appdetail.run_globally", "전역에서 실행", "Run Globally")
add("ui.appdetail.open_url", "URL 열기", "Open URL")
add("ui.appdetail.back_to_list", "목록으로", "Back to List")
add("ui.appdetail.change_category", "카테고리 변경", "Change Category")
add("ui.appdetail.add_hotkey", "단축키 추가", "Add Hotkey")
add("ui.appdetail.change_hotkey", "단축키 변경", "Change Hotkey")
add("ui.appdetail.no_hotkey", "없음 — 실행/포커스/토글 단축키를 설정하세요.", "None — Set Run/Focus/Toggle Hotkey")
add("ui.appdetail.configured_hotkeys", "설정된 글로벌 단축키", "Configured Global Hotkeys")
add("ui.appdetail.no_hotkey_assigned", "설정된 단축키가 없습니다. 아래 메뉴 단축키에서 선택해 추가하세요.", "No shortcut assigned. Select from menu shortcuts below to add.")
add("ui.appdetail.refresh", "새로고침", "Refresh")
add("ui.appdetail.search_menu_commands", "메뉴 명령 검색", "Search menu commands")
add("ui.appdetail.no_menu_items", "메뉴 단축키를 찾을 수 없습니다. 앱을 실행해두세요.", "No menu items with shortcuts found. Launch the app first.")
add("ui.appdetail.no_search_results", "검색 결과가 없습니다.", "No search results.")
add("ui.appdetail.record_hotkey", "단축키 녹음", "Record Hotkey")
add("ui.appdetail.urlscheme_unavailable", "앱 경로가 확인되지 않아 URL scheme을 읽을 수 없습니다.", "App path could not be verified to read URL schemes.")
add("ui.appdetail.no_urlscheme", "이 앱은 URL scheme을 지원하지 않습니다.", "This app does not support URL schemes.")
add("ui.appdetail.hotkey_for_scheme", "이 scheme을 여는 단축키 설정", "Set hotkey to open this scheme")
add("ui.appdetail.submenu", "(하위 메뉴)", "Submenu")
add_interp("ui.appdetail.execute_then_menu", "%@ 실행 후 메뉴 명령 수행", "Execute %@, then perform menu command", r"\(app.name) 실행 후 메뉴 명령 수행")
add_interp("ui.appdetail.run_toggle", "%@ 실행/토글", "Run/Toggle %@", r"\(app.name) 실행/토글")
add_interp("ui.appdetail.front", "%@ 전면으로", "Bring %@ to Front", r"\(app.name) 전면으로")
add_interp("ui.appdetail.run_app", "%@ 실행", "Run %@", r"\(app.name) 실행")
add_interp("ui.appdetail.menu_hotkeys", "%@의 메뉴 단축키", "%@ Menu Shortcuts", r"\(app.name)의 메뉴 단축키")
add_interp("ui.appdetail.try_urlscheme", "%@:// 열어보기", "Open %@://", r"\(scheme):// 열어보기")
add_interp("ui.appdetail.scheme_count", "%lld개", "%lld", r"\(urlSchemes.count)개")

# AppsContentView
add("ui.apps.all_apps", "전체 앱", "All Apps")
add("ui.apps.add_app", "앱 추가", "Add App")
add("ui.apps.no_apps", "앱이 없습니다", "No Apps")
add("ui.apps.unhide", "숨기기 해제", "Unhide")
add("ui.apps.hide", "숨기기", "Hide")
add_interp("ui.apps.count", "%lld개", "%lld apps", r"\(filteredApps.count)개")

# AutomationSettingsView
add("ui.automation.personal", "개인 자동화", "Personal Automation")
add("ui.automation.no_triggers", "등록된 자동화가 없습니다. 아래에서 트리거를 추가하세요.", "No registered automations. Add triggers below.")
add("ui.automation.add_trigger", "새 트리거 추가", "Add New Trigger")
add("ui.automation.time", "시간 (시간/일정)", "Time (Schedule)")
add("ui.automation.folder", "폴더 감시", "Folder Watch")
add("ui.automation.file", "파일 감시", "File Watch")
add("ui.automation.battery", "배터리", "Battery")
add("ui.automation.charger", "충전기", "Charger")
add_interp("ui.automation.macos_only", "%@ 트리거는 macOS 26 이상에서 지원됩니다.", "%@ triggers require macOS 26 or later.", r"\(newTriggerType.displayName) 트리거는 macOS 26 이상에서 지원됩니다.")

# DebugLogView
add("ui.log.filter_placeholder", "필터 (E-MAC-… / tag / 단어)", "Filter (E-MAC-… / tag / word)")
add("ui.log.auto_scroll", "자동 스크롤", "Auto Scroll")
add("ui.log.no_logs", "로그 없음", "No Logs")

# HotKeyRecorderView
add("ui.recorder.press_keys", "키를 누르세요...", "Press keys…")
add("ui.recorder.saved", "적용되었습니다. 잠시 후 닫힙니다.", "Applied. Closing shortly.")
add("ui.recorder.duplicate", "중복된 단축키입니다. 다른 조합을 눌러주세요.", "Duplicate hotkey. Try another combination.")
add("ui.recorder.unavailable", "사용할 수 없는 단축키입니다. 다른 조합을 눌러주세요.", "Unavailable hotkey. Try another combination.")
add("ui.recorder.testing", "테스트 중 — 이제 단축키를 눌러보세요", "Testing — press the hotkey now")
add("ui.recorder.test_success", "테스트 성공! 실제 동작이 실행되었습니다. 저장을 눌러 적용하세요.", "Test succeeded! The action actually ran. Press Save to apply.")
add("ui.recorder.test_failed", "단축키는 감지됐지만 실행에 실패했습니다. 대상 앱 실행·권한을 확인하세요.", "Hotkey detected but execution failed. Check target app launch & permissions.")

# MainWindowView
add("ui.main.reclassify", "카테고리 재분류", "Reclassify Categories")
add("ui.main.reclassify_help", "앱 카테고리 자동 재분류 (수동으로 바꾼 앱은 유지)", "Automatically reclassify app categories (manually changed apps are kept)")
add("ui.main.always_on_top_off", "항상 위에 해제", "Disable Always on Top")
add("ui.main.always_on_top", "항상 위에", "Always on Top")
add("ui.main.always_on_top_help", "항상 위에 유지", "Keep Window Always on Top")
add("ui.main.settings", "설정…", "Settings…")
add("ui.main.settings_help", "설정 (⌘,)", "Settings (⌘,)")
add("ui.main.search_apps", "앱 검색", "Search Apps")

# MenuCheatSheetView / MenuHUDOverlayView
add("ui.menu_cheat.search_hint", "단축키 / 명령 검색 (Enter 실행)", "Search shortcuts / commands (Enter to run)")
add("ui.menu_cheat.no_match", "일치하는 항목이 없습니다", "No matching items")
add("ui.menu_cheat.no_items", "단축키가 있는 메뉴 항목을 찾지 못했습니다", "No menu items with shortcuts found")
add("ui.menu_cheat.footer_hint", "ESC 또는 ⇧⌥S로 닫기 · Enter로 실행", "ESC or ⇧⌥S to close · Enter to execute")
add_interp("ui.menu_cheat.sort_results", "검색 결과 %lld개", "Search Results %lld", r"검색 결과 \(searchResults.count)개")
add_interp("ui.menu_cheat.menu_count", "메뉴 단축키 %lld개", "Menu Shortcuts %lld", r"메뉴 단축키 \(totalCount)개")
add("ui.hud.show_no_shortcut", "단축키 없는 메뉴 표시", "Show items without shortcuts")
add("ui.hud.close_hint", "ESC로 닫기", "Close with ESC")

# QuickLauncherView
add("ui.launcher.search_macros", "매크로 이름으로 검색...", "Search macros by name…")
add("ui.launcher.no_match", "일치하는 매크로를 찾을 수 없습니다", "No matching macros found")

# SettingsView
add("ui.settings.ok", "확인", "OK")

# ShortcutEditorView
add("ui.editor.automation_help", "개인 자동화 트리거 설정", "Personal Automation Triggers")
add("ui.editor.edit_mode", "편집 모드", "Edit Mode")
add("ui.editor.drag_hint", "단계를 드래그하여 순서를 변경할 수 있습니다", "Drag steps to reorder")
add("ui.editor.select_all", "전체 선택", "Select All")
add("ui.editor.toggle_all_skips", "스킵 모두 토글", "Toggle All Skips")
add("ui.editor.delete_all", "전체 삭제", "Delete All")
add("ui.editor.step_launch_app", "앱 선택", "Select App")
add("ui.editor.step_lock", "잠금", "Lock")
add("ui.editor.step_script", "스크립트", "Script")
add("ui.editor.step_file", "파일", "File")
add("ui.editor.step_clipboard", "클립보드", "Clipboard")
add("ui.editor.step_wait", "대기 1초", "Wait 1 sec")
add("ui.editor.step_click", "클릭", "Click")
add("ui.editor.step_type", "키 입력", "Type Keys")
add("ui.editor.step_pause", "입력 대기", "Pause Until Input")
add("ui.editor.step_menu", "메뉴 명령", "Menu Command")
add("ui.editor.step_repeat", "반복", "Repeat")
add("ui.editor.step_repeat_each", "각 항목 반복", "Repeat Each")
add("ui.editor.step_choose_menu", "메뉴에서 선택", "Choose from Menu")
add("ui.editor.step_use_model", "모델 사용", "Use Model")
add("ui.editor.step_writing_tool", "라이팅 툴", "Writing Tool")
add("ui.editor.step_image", "이미지 생성", "Create Image")
add("ui.editor.step_set_var", "변수 설정", "Set Variable")
add("ui.editor.step_output_var", "출력을 변수로", "Output to Variable")
add("ui.editor.step_comment", "코멘트", "Comment")
add_interp("ui.editor.steps_count", "%lld단계", "%lld steps", r"\(steps.count)단계")

# ShortcutStationView
add("ui.station.intro", "앱 열기, 키 입력, 스크립트, 붙여넣기 등을 단계로 쌓아 하나의 동작으로 만듭니다. 실행 버튼으로 테스트하고 단축키를 지정할 수 있습니다.", "Build a shortcut by stacking steps like open app, key input, script, paste. Test with Run button and assign hotkey.")
add("ui.station.new_shortcut", "새 동작", "New Shortcut")
add("ui.station.empty", "등록된 동작이 없습니다. '새 동작'으로 시작하세요.", "No registered shortcuts. Start with 'New Shortcut'.")
add("ui.station.name_placeholder", "이름 (예: 작업 시작)", "Name (e.g., Start Work)")
add("ui.station.no_steps", "단계 없음", "No Steps")
add("ui.station.run_all", "전체 단계를 순서대로 실행 (테스트)", "Run all steps in order (test)")
add("ui.station.assign_hotkey", "단축키 지정", "Assign Hotkey")
add("ui.station.assign_hotkey_help", "글로벌 실행 단축키 지정", "Assign Global Run Hotkey")
add("ui.station.edit_steps", "단계 편집", "Edit Steps")
add("ui.station.edit_steps_help", "단계 추가·정렬·삭제", "Add, reorder, delete steps")
add("ui.station.separator", "(분리자)", "Separator")
add_interp("ui.station.hotkey_title", "%@ 실행 단축키", "%@ Run Hotkey", r"\(shortcut.name) 실행 단축키")
add_interp("ui.station.hotkey_subtitle", "이 단축키를 누르면 전체 %lld단계가 순서대로 실행됩니다", "Pressing this hotkey runs all %lld steps in order", r"이 단축키를 누르면 전체 \(shortcut.steps.count)단계가 순서대로 실행됩니다")
add_interp("ui.station.delete_alert_title", "‘%@’ 동작을 삭제할까요?", "Delete '%@' shortcut?", r"‘\(shortcut.name)’ 동작을 삭제할까요?")
add_interp("ui.station.delete_alert_message", "%lld개 단계와 설정된 단축키가 함께 삭제됩니다. 되돌릴 수 없습니다.", "%lld steps and the configured hotkey will be deleted together. This cannot be undone.", r"\(shortcut.steps.count)개 단계와 설정된 단축키가 함께 삭제됩니다. 되돌릴 수 없습니다.")

# SidebarView
add("ui.sidebar.app_shortcuts", "앱 단축키", "App Shortcuts")
add("ui.sidebar.all_apps", "전체 앱", "All Apps")
add("ui.sidebar.tools", "도구", "Tools")
add("ui.sidebar.ax_required_help", "손쉬운 사용 권한이 필요합니다. 클릭하여 활성화하세요.", "Accessibility permission required. Click to enable.")
add("ui.sidebar.ax_required", "손쉬운 사용 권한 필요 — 활성화", "Accessibility Permission Required — Enable")
add("ui.sidebar.essential", "필수", "Essential")
add_interp("ui.sidebar.binding_counts", "단축키 %lld개 · 동작 %lld개", "%lld shortcuts · %lld actions", r"단축키 \(bindingCount)개 · 동작 \(store.shortcuts.count)개")

# StepRowView
add("ui.step.move_up", "위로 이동", "Move Up")
add("ui.step.move_down", "아래로 이동", "Move Down")
add("ui.step.duplicate", "복제", "Duplicate")
add("ui.step.unskip", "스킵 해제", "Unskip")
add("ui.step.empty_hint", "왼쪽 액션 카탈로그에서 액션을 추가하세요", "Add actions from the action catalog on the left")

# StepSettingsView
add("ui.step_settings.general", "일반", "General")
add("ui.step_settings.skip", "이 단계 스킵", "Skip this step")
add("ui.step_settings.note", "메모 (선택)", "Note (Optional)")
add("ui.step_settings.if_condition", "If 조건", "If Condition")
add("ui.step_settings.otherwise_hint", "그 외(Otherwise) 분기는 단계를 If 아래에 삽입해 관리합니다.", "Otherwise branch is managed by inserting steps under If.")
add("ui.step_settings.operator", "연산자", "Operator")
add("ui.step_settings.repeat_each", "반복 (각 항목)", "Repeat (Each Item)")
add("ui.step_settings.repeat_count", "반복 (횟수)", "Repeat (Count)")
add("ui.step_settings.collection_uuid", "컬렉션 변수 (UUID)", "Collection Variable (UUID)")
add("ui.step_settings.collection_hint", "컬렉션(리스트)을 소유한 변수의 ID를 입력합니다.", "Enter the ID of the variable that owns the collection (list).")
add("ui.step_settings.new_option", "새 옵션", "New Option")
add("ui.step_settings.allow_multiple", "여러 개 선택 허용", "Allow Multiple Selection")
add("ui.step_settings.show_cancel", "취소 버튼 표시", "Show Cancel Button")
add("ui.step_settings.follow_up_chat", "Follow Up (채팅)", "Follow Up (Chat)")
add("ui.step_settings.input_uuid", "입력 변수 (UUID)", "Input Variable (UUID)")
add("ui.step_settings.variable_value", "변수 값", "Variable Value")
add("ui.step_settings.variable_hint", "이 단계는 실행 중 이 값을 변수로 설정합니다. 매직 변수 연결은 변수 패널에서 구성합니다.", "This step sets this value to a variable during execution. Magic variable connections are configured in the variable panel.")
add("ui.step_settings.target_value", "대상 (값)", "Target (Value)")
add_interp("ui.step_settings.repeat_count_value", "반복 횟수: %lld", "Repetitions: %lld", r"반복 횟수: \(step.repeatLoop?.count ?? 1)")

# SystemActionsView
add("ui.system.intro", "아이콘을 클릭해 시스템 동작에 글로벌 단축키를 할당하거나 직접 실행할 수 있습니다.", "Click icon to assign global hotkey to system action or run directly.")
add("ui.system.title", "시스템 동작", "System Actions")
add("ui.system.assign_hotkey", "시스템 동작에 글로벌 단축키를 할당", "Assign Global Hotkeys to System Actions")
add("ui.system.run_now", "지금 실행", "Run Now")
add("ui.system.delete_hotkey", "단축키 삭제", "Delete Hotkey")
add_interp("ui.system.hotkey_title", "%@ 단축키", "%@ Hotkey", r"\(type.displayName) 단축키")

# VariablePanelView
add("ui.var.new_variable", "새 사용자 변수", "New User Variable")
add("ui.var.create_help", "새 사용자 변수 만들기", "Create New User Variable")
add("ui.var.magic_empty", "마법 변수 없음", "No Magic Variables")
add("ui.var.magic_hint", "단계를 실행하면 자동으로 생성됩니다", "Created automatically when steps run")
add("ui.var.manual_empty", "사용자 변수 없음", "No User Variables")
add("ui.var.manual_hint", "오른쪽 위 + 버튼으로 만들기", "Create with the + button in the top right")
add("ui.var.name_label", "변수 이름", "Variable Name")
add("ui.var.type", "타입", "Type")
add("ui.var.default_placeholder", "기본값", "Default")

# AppDelegate 메뉴
add("ui.menu.debug_log", "디버그 로그", "Debug Log")
add_interp("ui.menu.about", "%@ 정보", "%@ Info", r"\(appName) 정보")
add_interp("ui.menu.quit", "%@ 종료", "Quit %@", r"\(appName) 종료")
add("ui.menu.undo", "실행 취소", "Undo")
add("ui.menu.redo", "다시 실행", "Redo")
add("ui.menu.cut", "잘라내기", "Cut")
add("ui.menu.paste", "붙여넣기", "Paste")
add("ui.menu.select_all", "모두 선택", "Select All")

# ══════════════════════════════════════════════════════════════
# Models
# ══════════════════════════════════════════════════════════════
# ActionCategory (ActionType.swift)
add("category.essential", "필수", "Essential")
add("category.scripting", "코딩/스크립팅", "Coding/Scripting")
add("category.media", "미디어", "Media")
add("category.documents", "문서", "Documents")
add("category.location", "위치 & 교통", "Location & Transit")
add("category.content", "콘텐츠 제작", "Content Creation")
add("category.accessories", "주변기기 & 웹", "Devices & Web")
add("category.flowControl", "흐름 제어", "Flow Control")
add("category.appIntents", "앱", "Apps")
add("category.automation", "자동화", "Automation")

# Automation trigger category + repeat (AutomationModels.swift)
add("trigger.time", "시간", "Time")
add("trigger.filesystem", "파일 시스템", "File System")
add("trigger.hardware", "하드웨어", "Hardware")
add("trigger.network", "네트워크", "Network")
add("trigger.power", "전원", "Power")
add("trigger.system", "시스템", "System")
add("repeat.none", "한 번만", "Once")
add("repeat.daily", "매일", "Daily")
add("repeat.weekdays", "평일", "Weekdays")
add("repeat.weekends", "주말", "Weekends")
add("repeat.weekly", "매주", "Weekly")
add("repeat.monthly", "매월", "Monthly")
add("repeat.custom", "사용자 지정", "Custom")

# AIModels (AI 단계 표시용 라벨)
add("ai.provider.on_device", "온디바이스", "On-Device")
add("ai.provider.ask_each", "매번 선택", "Ask Each Time")
add("ai.output.dictionary", "딕셔너리", "Dictionary")
add("ai.output.list", "리스트", "List")
add("ai.output.boolean", "참/거짓", "Boolean")
add("ai.output.app_entity", "앱 엔티티", "App Entity")
add("ai.writing.proofread", "교정", "Proofread")
add("ai.writing.rewrite", "다시 쓰기", "Rewrite")
add("ai.writing.summarize", "요약", "Summarize")
add("ai.writing.make_list", "목록 만들기", "Make List")
add("ai.writing.make_table", "표 만들기", "Make Table")
add("ai.writing.change_tone", "톤 변경", "Change Tone")
add("ai.writing.key_points", "핵심 포인트", "Key Points")
add("ai.tone.professional", "전문적", "Professional")
add("ai.tone.friendly", "친근함", "Friendly")
add("ai.tone.concise", "간결함", "Concise")
add("ai.tone.casual", "캐주얼", "Casual")
add("ai.tone.formal", "격식", "Formal")
add("ai.tone.educational", "교육적", "Educational")
add("ai.image.animation", "애니메이션", "Animation")
add("ai.image.illustration", "일러스트", "Illustration")
add("ai.image.sketch", "스케치", "Sketch")


# ══════════════════════════════════════════════════════════════
# Views 잔여
# ══════════════════════════════════════════════════════════════
add("ui.catalog.all", "전체", "All")
add("ui.appdetail.run_toggle_label", "앱 실행/토글", "Run/Toggle App")
add("ui.appdetail.accessibility_required", "Accessibility 권한이 필요합니다.", "Accessibility permission is required.")
add("ui.editor.option_default", "옵션 1", "Option 1")
add("ui.editor.new_variable", "새 변수", "New Variable")
add("ui.station.create", "만들기", "Create")
add("ui.station.intro2", "여러 단계를 하나로 묶어 실행·단축키 지정", "Group multiple steps into one shortcut to run and assign a hotkey")
add("ui.step.if_end", "If 끝", "End If")
add("ui.step.repeat_end", "반복 끝", "End Repeat")
add("ui.step.menu_end", "메뉴 끝", "End Menu")
add("ui.step_settings.optional_mark", "선택 사항", "Optional")
add("ui.step_settings.left_value", "왼쪽 값", "Left Value")
add("ui.step_settings.right_value", "오른쪽 값", "Right Value")
add("ui.step_settings.menu_select", "메뉴 선택", "Select Menu")
add("ui.var.category_magic", "마법", "Magic")
add("ui.var.category_special", "특수", "Special")
add("ui.var.category_user", "사용자", "User")
add("ui.menu.edit_shortcut", "동작 편집", "Edit Shortcut")
add("ui.menu.step_settings", "단계 설정", "Step Settings")
add("ui.hud.key_legend", "⌘ CMD  ·  ⌃ Ctrl  ·  ⇧ Shift  ·  ⌥ Option  ·  🌐 지구본", "⌘ CMD  ·  ⌃ Ctrl  ·  ⇧ Shift  ·  ⌥ Option  ·  🌐 Globe")
add_interp("ui.editor.steps_count", "%lld단계", "%lld steps", r"\(shortcut.steps.count)단계")

# ══════════════════════════════════════════════════════════════
# AutomationModels 트리거
# ══════════════════════════════════════════════════════════════
add("ui.trigger.subfolder_suffix", " (하위 포함)", " (including subfolders)")
add_interp("ui.trigger.folder_fmt", "폴더: %@ [%@]%@", "Folder: %@ [%@]%@", r"폴더: \(folderName) [\(events)]\(subfolder)")
add_interp("ui.trigger.file_fmt", "파일: %@", "File: %@", r"파일: \(fileURL.lastPathComponent)")
add("ui.trigger.all_drives", "모든 드라이브", "All Drives")
add_interp("ui.trigger.drive_fmt", "외장 드라이브: %@ [%@]", "External Drive: %@ [%@]", r"외장 드라이브: \(drive) [\(events)]")
add_interp("ui.trigger.display_fmt", "디스플레이 [%@]", "Display [%@]", r"디스플레이 [\(events)]")
add("ui.trigger.all_networks", "모든 네트워크", "All Networks")
add_interp("ui.trigger.wifi_fmt", "Wi-Fi: %@ [%@]", "Wi-Fi: %@ [%@]", r"Wi-Fi: \(network) [\(events)]")
add("ui.trigger.all_devices", "모든 기기", "All Devices")
add_interp("ui.trigger.bluetooth_fmt", "블루투스: %@ [%@]", "Bluetooth: %@ [%@]", r"블루투스: \(device) [\(events)]")
add_interp("ui.trigger.battery_fmt", "배터리 %@ %lld%%", "Battery %@ %lld%%", r"배터리 \(condition.displayName) \(Int(threshold * 100))%", exprs=["condition.displayName", "Int(threshold * 100)"])
add_interp("ui.trigger.charger_fmt", "충전기 [%@]", "Charger [%@]", r"충전기 [\(events)]")
add_interp("ui.trigger.app_fmt", "앱: %@ [%@]", "App: %@ [%@]", r"앱: \(bundleID) [\(events)]")
add("ui.trigger.all_focus", "모든 집중 모드", "Any Focus")
add_interp("ui.trigger.focus_fmt", "집중 모드: %@ [%@]", "Focus: %@ [%@]", r"집중 모드: \(focus) [\(events)]")
add("ui.trigger.connected", "연결", "Connected")
add("ui.trigger.disconnected", "분리", "Disconnected")
add("ui.trigger.wifi_disconnected", "끊김", "Disconnected")
add("ui.trigger.activated", "활성화", "Activated")
add("ui.trigger.deactivated", "비활성화", "Deactivated")
add("ui.trigger.turned_on", "켜짐", "On")
add("ui.trigger.turned_off", "꺼짐", "Off")
add("ui.trigger.modified", "수정", "Modified")
add("ui.trigger.renamed", "이름변경", "Renamed")
add("ui.trigger.rises_above", "초과", "Above")
add("ui.trigger.falls_below", "미만", "Below")
add("ui.trigger.reaches", "도달", "Reaches")

# ══════════════════════════════════════════════════════════════
# AIModels 설명/상태/오류
# ══════════════════════════════════════════════════════════════
add("ai.provider_desc_ond", "인터넷 없이 기기에서 실행, 간단한 작업에 적합", "Runs on device without internet. Suited to simple tasks")
add("ai.provider_desc_pcloud", "애플 서버에서 처리, 복잡한 작업에 적합, 프라이버시 보호", "Processed on Apple servers. Suited to complex tasks, privacy-preserving")
add("ai.provider_desc_chatgpt", "ChatGPT 활용, 광범위한 지식, 외부 서비스 연동", "Uses ChatGPT. Broad knowledge, external service integration")
add("ai.provider_desc_ask_each", "실행할 때마다 모델을 직접 선택", "Choose the model each time it runs")
add("ai.output_desc_text", "자연어 응답, 후속 텍스트 처리에 적합", "Natural-language response, suited to follow-up text")
add("ai.output_desc_dict", "키-값 쌍 구조, JSON 파싱 가능", "Key-value pairs, JSON-parseable")
add("ai.output_desc_list", "항목 나열, Repeat with Each와 연동", "List items, works with Repeat with Each")
add("ai.output_desc_bool", "예/아니오 판단, If 조건에 직접 사용", "Yes/No judgment, usable directly in If")
add("ai.output_desc_app_entity", "앱 데이터 엔티티, Find 액션 결과 등", "App data entity, e.g., Find action results")
add("ai.writing_desc_proofread", "맞춤법, 문법, 구두점을 교정합니다", "Fixes spelling, grammar, and punctuation")
add("ai.writing_desc_rewrite", "텍스트를 다른 스타일로 다시 씁니다", "Rewrites text in another style")
add("ai.writing_desc_summarize", "긴 텍스트를 요약합니다", "Summarizes long text")
add("ai.writing_desc_make_list", "텍스트에서 목록을 추출합니다", "Extracts lists from text")
add("ai.writing_desc_make_table", "텍스트에서 표를 생성합니다", "Generates a table from text")
add("ai.writing_desc_change_tone", "텍스트의 어조를 변경합니다 (전문적, 친근, 간결 등)", "Changes the tone (professional, friendly, concise, etc.)")
add("ai.writing_desc_key_points", "텍스트의 핵심 내용을 추출합니다", "Extracts key points from text")
add_interp("ai.display_model_use", "모델 사용 (%@ → %@)", "Use Model (%@ → %@)", r"모델 사용 (\(modelType.displayName) → \(outputType.displayName))")
add_interp("ai.display_image_style", "이미지 생성 (%@)", "Create Image (%@)", r"이미지 생성 (\(style.displayName))")
add("ai.state_available", "사용 가능", "Available")
add_interp("ai.state_unsupported_os", "macOS %@ 이상 필요", "Requires macOS %@ or later", r"macOS \(version) 이상 필요")
add("ai.state_ai_disabled", "Apple Intelligence가 비활성화됨 (시스템 설정에서 활성화)", "Apple Intelligence disabled (enable in System Settings)")
add_interp("ai.state_model_unavailable", "모델 사용 불가: %@", "Model unavailable: %@", r"모델 사용 불가: \(reason)")
add("ai.state_checking", "상태 확인 중...", "Checking…")
add("ai.error_unsupported_os", "이 기능은 macOS 26 (Tahoe) 이상에서만 사용 가능합니다", "This feature requires macOS 26 (Tahoe) or later")
add("ai.error_ai_disabled", "Apple Intelligence가 활성화되지 않았습니다. 시스템 설정 > Apple Intelligence에서 켜주세요", "Apple Intelligence is not enabled. Turn it on in System Settings > Apple Intelligence")
add_interp("ai.error_model_not_available", "%@ 모델을 사용할 수 없습니다", "%@ model is unavailable", r"\(type.displayName) 모델을 사용할 수 없습니다")
add("ai.error_prompt_empty", "프롬프트가 비어있습니다", "Prompt is empty")
add_interp("ai.error_output_conversion", "응답을 %@ 타입으로 변환할 수 없습니다", "Cannot convert the response to %@ type", r"응답을 \(type.displayName) 타입으로 변환할 수 없습니다")
add("ai.error_follow_up", "Follow Up 모드는 현재 지원되지 않습니다", "Follow Up mode is not supported yet")
add("ai.error_chatgpt_ext", "ChatGPT Extension이 설치되지 않았습니다", "ChatGPT Extension is not installed")
add_interp("ai.error_network", "네트워크 오류: %@", "Network error: %@", r"네트워크 오류: \(e.localizedDescription)")
add("ai.error_timeout", "응답 시간이 초과되었습니다", "Response timed out")
add("ai.error_cancelled", "사용자에 의해 취소되었습니다", "Cancelled by the user")
add("ai.error_invalid_response", "유효하지 않은 응답입니다", "Invalid response")
add("ai.error_token_limit", "토큰 한도를 초과했습니다", "Token limit exceeded")
add("ai.error_content_filtered", "콘텐츠 필터에 의해 차단되었습니다", "Blocked by the content filter")
add("ai.tool_coding", "코딩", "Coding")
add("ai.tool_writing", "글쓰기", "Writing")
add("ai.tool_analysis", "분석", "Analysis")
add("ai.tool_translation", "번역", "Translation")
add("ai.tool_creative", "창작", "Creative")
add("ai.tool_custom", "사용자 정의", "Custom")

# ══════════════════════════════════════════════════════════════
# 유틸

# ══════════════════════════════════════════════════════════════
def load_strings(path):
    if not path.exists():
        return {}
    content = path.read_text(encoding="utf-16")
    result = {}
    for m in re.finditer(r'"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)"', content):
        result[m.group(1)] = m.group(2)
    return result

def unescape_plist(s):
    return re.sub(r'\\(.)', lambda m: m.group(1), s)

def write_strings(path, data):
    lines = []
    for k, v in sorted(data.items()):
        k_esc = k.replace('\\', '\\\\').replace('"', '\\"')
        v_esc = v.replace('\\', '\\\\').replace('"', '\\"')
        lines.append(f'"{k_esc}" = "{v_esc}";')
    path.write_text("\n".join(lines) + "\n", encoding="utf-16")

def main():
    ko_path = SRC / "ko.lproj" / "Localizable.strings"
    en_path = SRC / "en.lproj" / "Localizable.strings"
    ko = load_strings(ko_path)
    en = load_strings(en_path)

    # 버그 있는 한글 키 ui.* 제거
    for k in list(ko.keys()):
        if k.startswith("ui.") and any('\uac00' <= ch <= '\ud7a3' for ch in k):
            del ko[k]
            en.pop(k, None)

    # 신규 엔트리 반영 (기존값도 갱신: settings/action 유지)
    for key, (ko_val, en_val) in ENTRIES.items():
        ko[key] = ko_val
        en[key] = en_val

    write_strings(ko_path, ko)
    write_strings(en_path, en)
    print(f"strings 작성 완료: ko={len(ko)} en={len(en)}")

    # 소스 치환 (interp 먼저)
    for path in FILES:
        orig = path.read_text(encoding="utf-8")
        content = orig

        for src in sorted(SRC_INTERP, key=len, reverse=True):
            key, exprs = SRC_INTERP[src]
            quoted = '"' + src + '"'
            if quoted in content:
                args = ", ".join(exprs)
                content = content.replace(quoted, '"' + key + '".localizedFormat(' + args + ")")

        for src in sorted(SRC_SIMPLE, key=len, reverse=True):
            key = SRC_SIMPLE[src]
            quoted = '"' + src + '"'
            if quoted in content:
                content = content.replace(quoted, '"' + key + '".localized')

        if content != orig:
            path.write_text(encoding="utf-8", data=content)
            print(f"{path.name}: 치환 완료")

    # 미처리 확인
    print("\n=== 남은 한글 리터럴 (Views/Models, 로그 제외) ===")
    count = 0
    for path in FILES:
        content = path.read_text(encoding="utf-8").split("\n")
        for i, line in enumerate(content, 1):
            if line.strip().startswith("//"):
                continue
            if "Logger" in line:
                continue
            for m in re.finditer(r'"([^"]*[가-힣][^"]*)"', line):
                s = m.group(1)
                if len(s) >= 2:
                    print(f"  {path.name}:{i}: {s[:70]}")
                    count += 1
    print(f"남은 개수: {count}")

if __name__ == "__main__":
    main()