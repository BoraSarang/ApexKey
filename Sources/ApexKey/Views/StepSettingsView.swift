import AppKit
import SwiftUI

/// 단계 상세 설정 시트 — 흐름 제어 / AI / 변수 단계의 설정을 편집
struct StepSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    /// 원본 (편집기 steps 요소로의 write-through 전용 — 직접 읽지 않는다)
    @Binding private var source: ShortcutStep
    /// 로컬 드래프트 — 입력·푸터가 읽는 유일한 진실.
    /// 설정 창은 별도 NSWindow 그래프라 편집기 @State로의 바인딩이 stale이 될 수 있어
    /// (새 단계 첫 오픈 시 푸터가 타이핑 갱신을 못 받아 테스트 버튼이 안 켜짐).
    /// 입력은 로컬에 먼저 반영하고 onChange로 원본에 밀어넣는다.
    @State private var draft: ShortcutStep
    /// 편집 중인 동작의 ID — Run Shortcut 피커가 자기 자신을 제외하는 데 쓴다
    var currentShortcutID: UUID?

    init(step: Binding<ShortcutStep>, currentShortcutID: UUID? = nil) {
        _source = step
        _draft = State(initialValue: step.wrappedValue)
        self.currentShortcutID = currentShortcutID
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerContent

            Divider()

            if fillsEditor {
                // 고정 크기 창 — 에디터가 남은 공간을 채우고 입력칸만 스크롤.
                // 외곽 스크롤이 없으므로 이중 스크롤이 생기지 않는다 (M-SCRIPT-01).
                VStack(alignment: .leading, spacing: 16) {
                    // 공통: 스킵/메모
                    commonSection

                    // 타입별 설정 (내부 에디터가 남은 높이를 흡수)
                    typeSpecificSection
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else {
                // 짧은 폼 — 기존 스크롤 유지
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // 공통: 스킵/메모
                        commonSection

                        // 타입별 설정
                        typeSpecificSection
                    }
                    .padding(16)
                }
                .layoutPriority(1)
            }

            Divider()

            // 하단 테스트 푸터 (항상 가시 — 스크롤 안 됨, 로컬 드래프트를 읽어 항상 최신)
            StepTestFooter(step: $draft)
        }
        // 드래프트 변경은 원본(편집기 steps)에 write-through — 단계 삭제 등으로
        // id가 없으면 set이 무시되므로 크래시 없음
        .onChange(of: draft) { _, newValue in
            source = newValue
        }
        // 소형 창에서도 밀리지 않게 최소 크기 유지 — 상단은 헤더, 하단은 푸터 고정
        .frame(minWidth: 480, minHeight: 480)
        .frame(idealWidth: 480, idealHeight: 680)
        .background(theme.secondaryBackground)
    }
    
    // MARK: - 레이아웃 판정

    /// 에디터가 창 남은 공간을 채우는 타입 — 스크립트 4종.
    /// 외곽 ScrollView를 없애 이중 스크롤을 원천 제거한다.
    /// 시스템은 피커(고정 높이)라 스크롤 분기에 둔다.
    private var fillsEditor: Bool {
        switch draft.type {
        case .script, .appleScript, .javaScriptForAutomation, .runScriptInShell:
            return true
        default:
            return false
        }
    }

    // MARK: - 헤더 (고정)

    private var headerContent: some View {
        HStack {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(accentColor.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: draft.type.systemImage)
                    .font(.system(size: 14))
                    .foregroundColor(accentColor)
            }

            Text(draft.type.displayName)
                .font(.title3)
                .fontWeight(.semibold)

            Spacer()

            Button("ui.done".localized) { dismiss() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(16)
    }

    // MARK: - 공통 설정
    
    private var commonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ui.step_settings.general".localized)
                .font(.headline)
            
            Toggle("ui.step_settings.skip".localized, isOn: $draft.isSkipped)
            
            TextField("ui.step_settings.note".localized, text: Binding(
                get: { draft.note ?? "" },
                set: { draft.note = $0.isEmpty ? nil : $0 }
            ))
            .textFieldStyle(.roundedBorder)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.inputBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - 타입별 설정
    
    @ViewBuilder
    private var typeSpecificSection: some View {
        switch draft.type {
        case .launchApp:
            LaunchAppSettingsView(step: $draft)
        case .keyCombo:
            KeyPressSettingsView(step: $draft)
        case .ifElse:
            IfSettingsView(step: $draft)
        case .repeatLoop, .repeatEach:
            RepeatSettingsView(step: $draft)
        case .chooseFromMenu:
            MenuSettingsView(step: $draft)
        case .useModel:
            UseModelSettingsView(step: $draft)
        case .writingTool:
            WritingToolSettingsView(step: $draft)
        case .imagePlayground:
            ImagePlaygroundSettingsView(step: $draft)
        case .setVariable, .outputToVariable:
            VariableStepSettingsView(step: $draft)

        case .runShortcut:
            RunShortcutSettingsView(step: $draft, currentShortcutID: currentShortcutID)
        // 텍스트 액션 11종 — 전용 UI 없이는 "선택은 되지만 쓸 수 없다"가 된다 (E-MAC-TEXT-6001)
        case .text, .combineText, .splitText, .trimWhitespace, .replaceText,
             .regex, .matchText, .count, .formatNumber, .getClipboard, .setClipboard,
             // 수치·날짜·목록 보조 12종 (E-MAC-TEXT-6002)
             .changeCase, .sort, .surroundText, .wordCount, .calculate, .math,
             .number, .outputDifference, .base64Encode, .hash, .uuid, .dateFormatter,
             .htmlToMarkdown:
            TextActionSettingsView(step: $draft)
        case .comment:
            CommentSettingsView(step: $draft)
        case .system:
            // 프리셋 선택지 — 스크립트 표시·수정 없음 (선택=프리셋 ID)
            SystemPresetPickerView(step: $draft)
        default:
            // 기본 단계: 대상/제목 편집
            DefaultSettingsView(step: $draft)
        }
    }
    
    private var accentColor: Color {
        switch draft.type.category {
        case .flowControl: return .indigo
        case .ai: return .mint
        case .variables: return .cyan
        default: return .blue
        }
    }
}
