import SwiftUI
import AppKit

/// 시스템 동작 탭 — 화면 잠금/음소거/다크모드에 글로벌 단축키 할당
struct SystemActionsView: View {
    @EnvironmentObject var store: ConfigStore
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("ui.system.intro".localized)
                        .font(.caption)
                        .foregroundColor(theme.secondaryText)
                    VStack(spacing: 8) {
                        ForEach(SystemActionType.allCases) { type in
                            row(for: type)
                        }
                    }
                    Spacer()
                }
                .padding(16)
            }
        }
        .frame(minWidth: 440, minHeight: 480)
        .background(theme.primaryBackground)
        .sheet(item: $recordingType) { type in
            HotKeyRecorderView(
                title: "ui.system.hotkey_title".localizedFormat(type.displayName),
                excludedCombo: store.systemBindings(for: type).first?.combo,
                onTest: { _ in SystemActionExecutor.execute(type) }
            ) { combo in
                onRecord(combo: combo, type: type)
            }
            .environmentObject(store)
        }
    }

    @State private var recordingType: SystemActionType?
    /// 스크립트 편집기가 펼쳐진 항목 (동작 탭의 단계 설정처럼 행별 확장)
    @State private var expandedTypes: Set<String> = []

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "gearshape.2")
                .frame(width: 36, height: 36)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text("ui.system.title".localized)
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("ui.system.assign_hotkey".localized)
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func row(for type: SystemActionType) -> some View {
        let bindings = store.systemBindings(for: type)
        let comboText = bindings.first?.combo.displayString ?? ""
        let expanded = expandedTypes.contains(type.rawValue)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: type.systemImage)
                    .frame(width: 22)
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(type.displayName)
                        .font(.body)
                    if !comboText.isEmpty {
                        Text(comboText)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.accentColor)
                    }
                }
                Spacer()
                // 스크립트 보기/닫기 — 동작 탭의 단계 설정 진입과 같은 역할
                Button {
                    toggleExpanded(type)
                } label: {
                    Label(
                        expanded
                            ? "ui.system.script_hide".localized
                            : "ui.system.script_show".localized,
                        systemImage: expanded ? "chevron.up" : "chevron.left.forwardslash.chevron.right"
                    )
                }
                .buttonStyle(.borderless)
                .help("ui.system.script_show".localized)
                Button {
                // 스크립트형 액션(미러 등)은 수십 초 걸릴 수 있어 메인 스레드 차단 금지.
                // 백그라운드 실행 + 토스트로 결과 통지.
                let name = type.displayName
                let executor = store.actionExecutor
                DispatchQueue.global(qos: .userInitiated).async {
                    let detail = executor.executeWithDetail(HotKeyBinding(
                        combo: .empty,
                        actionType: .system,
                        target: type.rawValue,
                        title: name
                    ))
                    DispatchQueue.main.async {
                        (NSApp.delegate as? AppDelegate)?.showToast(
                            title: name,
                            message: detail.message,
                            success: detail.success
                        )
                    }
                }
            } label: {
                Label("ui.run".localized, systemImage: "play")
            }
            .buttonStyle(.borderless)
            .help("ui.system.run_now".localized)
            Button {
                recordingType = type
            } label: {
                Image(systemName: "plus.circle")
            }
            .buttonStyle(.borderless)
            .help("ui.appdetail.record_hotkey".localized)
            if !bindings.isEmpty {
                Button {
                    store.removeBinding(bindings.first!)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(theme.secondaryText)
                }
                .buttonStyle(.borderless)
                .help("ui.system.delete_hotkey".localized)
            }
            }

            // 스크립트 편집기 — 동작 탭의 단계 상세(DefaultSettingsView + StepTestFooter)와 동등:
            // 보기(TextEditor) + 테스트 실행(결과 창) + 수정/저장
            if expanded {
                Divider()
                    .padding(.top, 8)
                SystemScriptEditorView(type: type)
                    .padding(.top, 8)
            }
        }
        .padding(10)
        .background(theme.inputBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func toggleExpanded(_ type: SystemActionType) {
        if expandedTypes.contains(type.rawValue) {
            expandedTypes.remove(type.rawValue)
        } else {
            expandedTypes.insert(type.rawValue)
        }
    }

    private func onRecord(combo: HotKeyCombo, type: SystemActionType) {
        guard !combo.isEmpty else { return }
        store.setSystemBinding(for: type, combo: combo)
    }
}

// MARK: - 시스템 스크립트 편집기 (동작 탭 단계 설정과 동등)

/// 시스템 항목의 스크립트를 보고·테스트하고·수정·저장하는 인라인 편집기.
/// 동작 탭 `DefaultSettingsView`(TextEditor 180pt + 내부 스크롤) +
/// `StepTestFooter`(테스트 실행 + 결과 창) 조합과 같은 사용감을 제공한다.
private struct SystemScriptEditorView: View {
    @Environment(\.theme) private var theme
    let type: SystemActionType

    @State private var scriptText = ""
    @State private var savedText = ""
    @State private var didLoad = false
    @State private var isTesting = false
    @State private var didTest = false
    @State private var testSuccess = false
    @State private var testOutput = ""
    @State private var testError = ""
    @State private var testExitCode: Int32 = 0
    @State private var saveMessage: String?

    private var isDirty: Bool { scriptText != savedText }
    private var isFileBacked: Bool { SystemActionExecutor.isFileBacked(type) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 언어 + 상태 행
            HStack(spacing: 8) {
                Text(SystemActionExecutor.scriptLanguage(type))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.secondaryText)
                if isFileBacked {
                    Text("ui.system.script_file".localizedFormat(SystemActionExecutor.androidMirrorScriptPath))
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(theme.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else if SystemActionExecutor.hasCustomScript(for: type) {
                    Text("ui.system.script_modified".localized)
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
                Spacer()
                if !didLoad {
                    ProgressView()
                        .controlSize(.small)
                } else if isDirty {
                    Text("ui.system.script_modified".localized)
                        .font(.caption2)
                        .foregroundColor(.orange)
                } else if saveMessage != nil {
                    Text(saveMessage ?? "")
                        .font(.caption2)
                        .foregroundColor(theme.successColor)
                }
            }

            // 스크립트 본문 — 동작 탭과 같은 고정 높이 + 내부 스크롤
            TextEditor(text: $scriptText)
                .font(.system(.body, design: .monospaced))
                .frame(height: 180)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(theme.secondaryText.opacity(0.3))
                )
                .scrollContentBackground(.hidden)
                .disabled(isTesting)

            // 하단 바 — 테스트(좌) + 저장/되돌리기(우)
            HStack(spacing: 8) {
                Button {
                    runTest()
                } label: {
                    Label("ui.step_settings.test_run".localized, systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isTesting || scriptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if isTesting {
                    ProgressView()
                        .controlSize(.small)
                    Text("ui.step_settings.running".localized)
                        .font(.caption)
                        .foregroundColor(theme.secondaryText)
                } else if didTest {
                    Label(
                        testSuccess ? "toast.script_test_success".localized : "toast.script_test_failed".localized,
                        systemImage: testSuccess ? "checkmark.circle.fill" : "xmark.circle.fill"
                    )
                    .font(.caption)
                    .foregroundColor(testSuccess ? theme.successColor : theme.errorColor)
                    .lineLimit(1)
                    Button("ui.step_settings.view_result".localized) {
                        openResultWindow()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Spacer()

                if isFileBacked {
                    Button {
                        reloadFromDisk()
                    } label: {
                        Label("ui.system.script_reload".localized, systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(isTesting)
                } else {
                    Button("ui.system.script_reset".localized) {
                        resetToDefault()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(isTesting || (!isDirty && !SystemActionExecutor.hasCustomScript(for: type)))
                }

                Button("ui.save".localized) {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isTesting || !isDirty)
            }
        }
        .onAppear(perform: load)
    }

    // MARK: - 로드/저장

    private func load() {
        guard !didLoad else { return }
        let source = SystemActionExecutor.scriptSource(for: type)
        scriptText = source
        savedText = source
        didLoad = true
    }

    private func reloadFromDisk() {
        let source = SystemActionExecutor.scriptSource(for: type)
        scriptText = source
        savedText = source
        saveMessage = nil
        didTest = false
    }

    private func resetToDefault() {
        SystemActionExecutor.resetScript(for: type)
        reloadFromDisk()
    }

    private func save() {
        let ok = SystemActionExecutor.saveScript(scriptText, for: type)
        if ok {
            savedText = scriptText
            saveMessage = "ui.system.script_saved".localized
            (NSApp.delegate as? AppDelegate)?.showToast(
                title: type.displayName,
                message: "ui.system.script_saved".localized,
                success: true
            )
        } else {
            (NSApp.delegate as? AppDelegate)?.showToast(
                title: type.displayName,
                message: "toast.script_test_failed".localized,
                success: false
            )
        }
    }

    // MARK: - 테스트 (동작 탭 StepTestFooter와 같은 백그라운드 실행 + 결과 창)

    private func runTest() {
        let snapshot = scriptText
        guard !snapshot.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isTesting = true
        didTest = false
        saveMessage = nil
        Logger.info("FEATURE", "[SYSTEM-TEST] 테스트 실행 시작 (\(type.rawValue))")
        DispatchQueue.global(qos: .userInitiated).async {
            let r = SystemActionExecutor.runTestDetailed(type, source: snapshot)
            DispatchQueue.main.async {
                testSuccess = r.success
                testOutput = r.output
                testError = r.errorOutput
                testExitCode = r.exitCode
                isTesting = false
                didTest = true
                openResultWindow()
            }
        }
    }

    private func openResultWindow() {
        guard didTest else { return }
        (NSApp.delegate as? AppDelegate)?.showStepTestResult(
            title: type.displayName,
            success: testSuccess,
            output: testOutput,
            errorOutput: testError,
            exitCode: testExitCode
        )
    }
}
