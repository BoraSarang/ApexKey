import SwiftUI
import AppKit

// MARK: - 시스템 스크립트 편집기 (동작 탭 단계 설정의 .system 케이스)

/// 시스템 항목의 스크립트를 보고·테스트하고·수정·저장하는 인라인 편집기.
/// 동작 탭 `DefaultSettingsView`(TextEditor 180pt + 내부 스크롤) +
/// `StepTestFooter`(테스트 실행 + 결과 창) 조합과 같은 사용감을 제공한다.
struct SystemScriptEditorView: View {
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
        .onDisappear {
            // 미저장 스크립트가 있으면 자동 저장 (닫힘 시 침묵 유실 방지)
            if isDirty { save() }
        }
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