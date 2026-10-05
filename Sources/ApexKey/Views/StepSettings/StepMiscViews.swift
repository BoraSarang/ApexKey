import AppKit
import SwiftUI

// MARK: - 변수 단계 설정

struct VariableStepSettingsView: View {
    @Environment(\.theme) private var theme
    @Binding var step: ShortcutStep

    /// 출력 변수 이름 — 실행은 outputVariables[0]을 쓰는데 UI에 편집이 없어
    /// "새 변수"로 고정됐다. 이름 지정을 노출한다.
    private var outputName: Binding<String> {
        Binding(
            get: { step.outputVariables?.first?.name ?? "" },
            set: {
                var s = step
                if s.outputVariables?.isEmpty ?? true {
                    s.outputVariables = [Variable(name: $0, type: .manual, valueType: .text)]
                } else {
                    s.outputVariables?[0].name = $0
                }
                step = s
            }
        )
    }

    private var isSetVariable: Bool { step.type == .setVariable }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizedStringKey(isSetVariable ? "action.setVariable" : "action.outputToVariable"))
                .font(.headline)

            Text("ui.step_settings.variable_name".localized)
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            TextField("ui.step_settings.variable_name".localized, text: outputName)
                .textFieldStyle(.roundedBorder)

            if isSetVariable {
                Text("ui.step_settings.variable_value".localized)
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
                TextField("ui.step_settings.variable_value".localized, text: $step.target)
                    .textFieldStyle(.roundedBorder)
            }

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
            
            GrowingTextEditor(
                text: Binding(
                    get: { step.note ?? "" },
                    set: { step.note = $0 }
                ),
                font: .body,
                minHeight: 100,
                maxHeight: 220
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
                // 남은 공간을 채우고 상한 없이 입력칸만 스크롤 (창 전체 스크롤 없음)
                GrowingTextEditor(text: $step.target, maxHeight: 320, fillAvailable: true)
                // 테스트 실행은 하단 고정 푸터(StepTestFooter)에서 수행
            } else if step.type == .file {
                Text("ui.step_settings.target_value".localized)
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
                HStack {
                    TextField("ui.path".localized, text: $step.target)
                        .textFieldStyle(.roundedBorder)
                    Button("ui.browse".localized) {
                        let panel = NSOpenPanel()
                        panel.allowsMultipleSelection = false
                        panel.canChooseDirectories = true
                        panel.canChooseFiles = true
                        if panel.runModal() == .OK, let url = panel.url {
                            step.target = url.path
                            if step.title.isEmpty { step.title = url.lastPathComponent }
                        }
                    }
                }
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
