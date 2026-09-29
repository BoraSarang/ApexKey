import AppKit
import SwiftUI

// MARK: - 변수 단계 설정

struct VariableStepSettingsView: View {
    @Environment(\.theme) private var theme
    @Binding var step: ShortcutStep
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizedStringKey("action.setVariable"))
                .font(.headline)
            
            TextField("ui.step_settings.variable_value".localized, text: $step.target)
                .textFieldStyle(.roundedBorder)
            
            Text("ui.step_settings.variable_hint".localized)
                .font(.caption2)
                .foregroundColor(theme.secondaryText)
        }
        .sectionCard()
    }
}

// MARK: - 코멘트 설정

struct CommentSettingsView: View {
    @Environment(\.theme) private var theme
    @Binding var step: ShortcutStep
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizedStringKey("action.comment"))
                .font(.headline)
            
            TextEditor(text: Binding(
                get: { step.note ?? "" },
                set: { step.note = $0 }
            ))
            .frame(height: 120)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(theme.secondaryText.opacity(0.3))
            )
        }
        .sectionCard()
    }
}

// MARK: - 기본 설정

struct DefaultSettingsView: View {
    @Environment(\.theme) private var theme
    @Binding var step: ShortcutStep

    private var isScript: Bool {
        step.type == .script || step.type == .appleScript
            || step.type == .javaScriptForAutomation || step.type == .runScriptInShell
    }

    private var scriptPromptKey: String {
        switch step.type {
        case .appleScript: return "ui.app_detail.applescript_prompt"
        case .javaScriptForAutomation: return "ui.app_detail.jxa_prompt"
        default: return "ui.app_detail.shell_prompt"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(step.type.displayName)
                .font(.headline)

            Text("ui.title".localized)
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            TextField("ui.title".localized, text: $step.title)
                .textFieldStyle(.roundedBorder)

            if isScript {
                Text(scriptPromptKey.localized)
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
                // 고정 높이 + 내부 스크롤 (창 전체 스크롤 아님).
                // TextEditor 자체가 내부 스크롤을 제공하므로 높이를 고정한다.
                TextEditor(text: $step.target)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 180)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(theme.secondaryText.opacity(0.3))
                    )
                    .scrollContentBackground(.hidden)
                // 테스트 실행은 하단 고정 푸터(StepTestFooter)에서 수행
            } else {
                Text("ui.step_settings.target_value".localized)
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
                TextField("ui.step_settings.target_value".localized, text: $step.target)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .sectionCard()
    }
}

// MARK: - 확장

struct SectionCardModifier: ViewModifier {
    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.inputBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

extension View {
    func sectionCard() -> some View {
        modifier(SectionCardModifier())
    }
}
