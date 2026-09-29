import AppKit
import SwiftUI

/// 텍스트 액션 11종의 단계 설정 (E-MAC-TEXT-6001)
///
/// 왜 전용 UI가 필요한가: `implementation == .implemented`인 액션은 카탈로그에서 **선택된다.**
/// 전용 UI 없이 `DefaultSettingsView`로 두면 "정규식"을 골라도 패턴을 입력할 곳이 없다 —
/// 선택은 되지만 쓸 수 없는, T-159가 정확히 고친 그 상태를 그대로 재발시킨다.
///
/// 액션마다 필요한 입력이 다르므로 한 화면에 전부 쌓지 않고 **해당 액션의 것만** 보여준다.
struct TextActionSettingsView: View {
    @Environment(\.theme) private var theme
    @Binding var step: ShortcutStep

    /// `actionParameters`를 구조체로 읽고 쓰기 위한 어댑터
    private var config: TextActionConfig { TextActionConfig.decode(from: step.actionParameters) }

    private func updateConfig(_ mutate: (inout TextActionConfig) -> Void) {
        var next = config
        mutate(&next)
        step.actionParameters = try? JSONEncoder().encode(next)
    }
    // MARK: - 액션별 필요 입력 판정

    /// 패턴(찾을 문자열·정규식)이 필요한 액션
    private var needsSearch: Bool {
        [.replaceText, .regex, .matchText].contains(step.type)
    }
    /// 치환 문자열이 필요한 액션
    private var needsReplacement: Bool {
        step.type == .replaceText || (step.type == .regex && config.replacement?.isEmpty == false)
    }
    /// 구분자가 필요한 액션
    private var needsSeparator: Bool {
        step.type == .combineText || step.type == .splitText
    }
    /// 개수 세기 단위가 필요한 액션
    private var needsCountUnit: Bool { step.type == .count }
    /// 숫자 형식이 필요한 액션
    private var needsNumberStyle: Bool { step.type == .formatNumber }

    /// 클립보드에서 읽는 액션은 입력을 직접 고를 필요가 없다
    private var usesClipboard: Bool { step.type == .getClipboard }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(step.type.displayName)
                .font(.headline)

            if usesClipboard {
                Text("ui.text_action.clipboard_read_hint".localized)
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
            } else {
                inputField(
                    label: "ui.text_action.input".localized,
                    hint: "ui.text_action.input_hint".localized,
                    isMultiline: step.type == .setClipboard || step.type == .text,
                    text: Binding(
                        get: { config.text?.isEmpty == false ? config.text! : step.target },
                        set: { newValue in
                            // actionParameters.text가 있으면 그쪽을, 없으면 target을 쓴다.
                            // 둘 다 비어 있으면 target에 남겨 기본 동작을 유지한다.
                            if config.text?.isEmpty == false {
                                updateConfig { cfg in cfg.text = newValue }
                            } else {
                                step.target = newValue
                            }
                        }
                    )
                )
            }

            if needsSearch {
                inputField(
                    label: "ui.text_action.pattern".localized,
                    hint: step.type == .matchText
                        ? "ui.text_action.pattern_match_hint".localized
                        : "ui.text_action.pattern_hint".localized,
                    isMultiline: false,
                    monospaced: step.type == .regex,
                    text: Binding(
                        get: { config.search ?? "" },
                        set: { newValue in updateConfig { cfg in cfg.search = newValue } }
                    )
                )
            }

            if needsReplacement {
                inputField(
                    label: "ui.text_action.replacement".localized,
                    hint: "ui.text_action.replacement_hint".localized,
                    isMultiline: false,
                    text: Binding(
                        get: { config.replacement ?? "" },
                        set: { newValue in updateConfig { cfg in cfg.replacement = newValue } }
                    )
                )
            }

            if step.type == .regex {
                Toggle("ui.text_action.match_all".localized, isOn: Binding(
                    get: { step.title == "all" },
                    set: { step.title = $0 ? "all" : "" }
                ))
            }

            if needsSeparator {
                inputField(
                    label: "ui.text_action.separator".localized,
                    hint: step.type == .splitText
                        ? "ui.text_action.separator_split_hint".localized
                        : "ui.text_action.separator_combine_hint".localized,
                    isMultiline: false,
                    text: Binding(
                        get: { config.separator ?? "" },
                        set: { newValue in updateConfig { cfg in cfg.separator = newValue } }
                    )
                )
            }

            if needsCountUnit {
                Picker("ui.text_action.count_unit".localized, selection: Binding(
                    get: { config.countUnit ?? .characters },
                    set: { newValue in updateConfig { cfg in cfg.countUnit = newValue } }
                )) {
                    ForEach(TextActionConfig.CountUnit.allCases, id: \.self) { unit in
                        Text(unit.displayName).tag(unit)
                    }
                }
            }

            if needsNumberStyle {
                Picker("ui.text_action.number_style".localized, selection: Binding(
                    get: { config.numberStyle ?? .decimal },
                    set: { newValue in updateConfig { cfg in cfg.numberStyle = newValue } }
                )) {
                    ForEach(TextActionConfig.NumberStyle.allCases, id: \.self) { style in
                        Text(style.displayName).tag(style)
                    }
                }

                Stepper(
                    "ui.text_action.decimals".localized,
                    value: Binding(
                        get: { config.decimals ?? 0 },
                        set: { newValue in updateConfig { cfg in cfg.decimals = newValue } }
                    ),
                    in: 0...10
                )

                Toggle("ui.text_action.grouping".localized, isOn: Binding(
                    get: { config.grouping ?? true },
                    set: { newValue in updateConfig { cfg in cfg.grouping = newValue } }
                ))
            }

            Text("ui.text_action.magic_hint".localized)
                .font(.caption2)
                .foregroundColor(theme.secondaryText)
        }
        .sectionCard()
    }

    // MARK: - 공통 입력

    @ViewBuilder
    private func inputField(
        label: String,
        hint: String,
        isMultiline: Bool,
        monospaced: Bool = false,
        text: Binding<String>
    ) -> some View {
        Text(hint)
            .font(.caption)
            .foregroundColor(theme.secondaryText)
        if isMultiline {
            TextEditor(text: text)
                .frame(height: 90)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(theme.secondaryText.opacity(0.3))
                )
                .scrollContentBackground(.hidden)
        } else {
            TextField(label, text: text)
                .font(monospaced ? .system(.body, design: .monospaced) : .body)
                .textFieldStyle(.roundedBorder)
        }
    }
}
