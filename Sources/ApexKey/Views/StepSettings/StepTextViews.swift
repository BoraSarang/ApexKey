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
    /// 입력을 쓰지 않고 설정만으로 동작하는 액션 (uuid)
    private var needsNoInput: Bool { step.type == .uuid }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(step.type.displayName)
                .font(.headline)

            if usesClipboard {
                Text("ui.text_action.clipboard_read_hint".localized)
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
            } else if needsNoInput {
                Text("ui.text_action.no_input_hint".localized)
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

            dataActionControls

            Text("ui.text_action.magic_hint".localized)
                .font(.caption2)
                .foregroundColor(theme.secondaryText)
        }
        .sectionCard()
    }

    // MARK: - 수치·날짜·목록 액션 설정 (E-MAC-TEXT-6002)

    @ViewBuilder
    private var dataActionControls: some View {
        switch step.type {
        case .changeCase:
            Picker("ui.text_action.case_style".localized, selection: Binding(
                get: { config.caseStyle ?? .uppercase },
                set: { newValue in updateConfig { cfg in cfg.caseStyle = newValue } }
            )) {
                ForEach(DataActions.CaseStyle.allCases, id: \.self) { s in
                    Text(s.displayName).tag(s)
                }
            }

        case .sort:
            Picker("ui.text_action.sort_mode".localized, selection: Binding(
                get: { config.sortMode ?? .text },
                set: { newValue in updateConfig { cfg in cfg.sortMode = newValue } }
            )) {
                ForEach(DataActions.SortMode.allCases, id: \.self) { m in
                    Text(m.displayName).tag(m)
                }
            }
            Picker("ui.text_action.sort_order".localized, selection: Binding(
                get: { config.sortOrder ?? .ascending },
                set: { newValue in updateConfig { cfg in cfg.sortOrder = newValue } }
            )) {
                Text("ui.text_action.order_ascending".localized).tag(DataActions.SortOrder.ascending)
                Text("ui.text_action.order_descending".localized).tag(DataActions.SortOrder.descending)
            }
            dataSeparatorField

        case .surroundText:
            dataTextField("ui.text_action.prefix".localized, key: \.prefix)
            dataTextField("ui.text_action.suffix".localized, key: \.suffix)

        case .math:
            Picker("ui.text_action.math_operation".localized, selection: Binding(
                get: { config.mathOperation ?? .add },
                set: { newValue in updateConfig { cfg in cfg.mathOperation = newValue } }
            )) {
                ForEach(DataActions.MathOperation.allCases, id: \.self) { op in
                    Text("\(op.displayName)  (\(op.symbol))").tag(op)
                }
            }
            dataSeparatorField

        case .base64Encode:
            Picker("ui.text_action.base64_direction".localized, selection: Binding(
                get: { config.decode ?? false },
                set: { newValue in updateConfig { cfg in cfg.decode = newValue } }
            )) {
                Text("ui.text_action.base64_encode".localized).tag(false)
                Text("ui.text_action.base64_decode".localized).tag(true)
            }

        case .hash:
            Picker("ui.text_action.hash_algorithm".localized, selection: Binding(
                get: { config.hashAlgorithm ?? .sha256 },
                set: { newValue in updateConfig { cfg in cfg.hashAlgorithm = newValue } }
            )) {
                ForEach(DataActions.HashAlgorithm.allCases, id: \.self) { a in
                    Text(a.displayName).tag(a)
                }
            }

        case .uuid:
            Stepper(
                "ui.text_action.uuid_count".localized,
                value: Binding(
                    get: { config.count ?? 1 },
                    set: { newValue in updateConfig { cfg in cfg.count = newValue } }
                ),
                in: 1...100
            )

        case .dateFormatter:
            inputField(
                label: "ui.text_action.date_format".localized,
                hint: "ui.text_action.date_format_hint".localized,
                isMultiline: false,
                monospaced: true,
                text: Binding(
                    get: { config.dateFormat ?? "yyyy-MM-dd" },
                    set: { newValue in updateConfig { cfg in cfg.dateFormat = newValue } }
                )
            )

        case .number:
            Stepper(
                "ui.text_action.decimals".localized,
                value: Binding(
                    get: { config.decimals ?? 0 },
                    set: { newValue in updateConfig { cfg in cfg.decimals = newValue } }
                ),
                in: 0...10
            )

        case .outputDifference:
            dataSeparatorField

        default:
            EmptyView()
        }
    }

    /// `TextActionConfig`의 문자열 필드 하나를 바인딩
    private func dataTextField(_ label: String, key: WritableKeyPath<TextActionConfig, String?>) -> some View {
        inputField(
            label: label,
            hint: label,
            isMultiline: false,
            text: Binding(
                get: { config[keyPath: key] ?? "" },
                set: { newValue in updateConfig { cfg in cfg[keyPath: key] = newValue } }
            )
        )
    }

    /// 이항 연산의 피연산자 구분자 (여러 값 입력용)
    private var dataSeparatorField: some View {
        inputField(
            label: "ui.text_action.separator".localized,
            hint: "ui.text_action.separator_math_hint".localized,
            isMultiline: false,
            text: Binding(
                get: { config.separator ?? "" },
                set: { newValue in updateConfig { cfg in cfg.separator = newValue } }
            )
        )
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
            GrowingTextEditor(text: text, font: monospaced ? .system(.body, design: .monospaced) : .body, minHeight: 90, maxHeight: 200)
        } else {
            TextField(label, text: text)
                .font(monospaced ? .system(.body, design: .monospaced) : .body)
                .textFieldStyle(.roundedBorder)
        }
    }
}
