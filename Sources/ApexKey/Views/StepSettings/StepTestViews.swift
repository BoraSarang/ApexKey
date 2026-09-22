import AppKit
import SwiftUI

// MARK: - 하단 테스트 푸터 (항상 가시 — 전 액션 공통)

/// 단계 설정 창의 하단 고정 테스트 바 (한 줄 고정).
/// 상세 결과는 별도 결과 창(StepTestResultView)으로 표시해
/// 설정 창에서 스크롤할 필요가 없도록 한다.
struct StepTestFooter: View {
    @Environment(\.theme) private var theme
    @Binding var step: ShortcutStep
    @State private var isTesting = false
    @State private var didTest = false
    @State private var testSuccess = false
    @State private var testOutput = ""
    @State private var testError = ""
    @State private var testExitCode: Int32 = 0

    var body: some View {
        HStack(spacing: 8) {
            Button {
                runTest()
            } label: {
                Label("ui.step_settings.test_run".localized, systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(isTesting || !canTest(step))

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

                Spacer()

                Button("ui.step_settings.view_result".localized) {
                    openResultWindow()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.primaryBackground)
    }

    private func canTest(_ step: ShortcutStep) -> Bool {
        switch step.type {
        case .script, .appleScript, .javaScriptForAutomation, .runScriptInShell:
            return !step.target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .keyCombo:
            if let press = step.keyPress, !press.isEmpty { return true }
            return !step.target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        default:
            return true
        }
    }

    private func runTest() {
        let snapshot = step
        guard canTest(snapshot) else { return }
        isTesting = true
        didTest = false
        Logger.info("FEATURE", "[STEP-TEST] 테스트 실행 시작 (\(snapshot.type.rawValue))")
        DispatchQueue.global(qos: .userInitiated).async {
            let success: Bool
            let output: String
            let errorOutput: String
            let exitCode: Int32
            switch snapshot.type {
            case .appleScript:
                let r = ScriptExecutor.runAppleScript(snapshot.target)
                success = r.success; output = r.output; errorOutput = r.errorOutput; exitCode = r.success ? 0 : 1
            case .javaScriptForAutomation:
                let r = ScriptExecutor.runJXA(snapshot.target)
                success = r.success; output = r.output; errorOutput = r.errorOutput; exitCode = r.success ? 0 : 1
            case .script, .runScriptInShell:
                let result = ActionExecutor.shared.runShellScriptResult(snapshot.target)
                success = result.success; output = result.output; errorOutput = result.errorOutput; exitCode = result.exitCode
            case .keyCombo:
                let combo: HotKeyCombo?
                if let press = snapshot.keyPress, !press.isEmpty {
                    combo = press
                } else {
                    combo = ActionExecutor.parseKeyPress(from: snapshot.target)
                }
                if let combo {
                    let ok = ActionExecutor.sendKeyPress(combo)
                    success = ok; output = ok ? "" : "E-MAC-ACT-3007"; errorOutput = ""; exitCode = ok ? 0 : 1
                } else {
                    success = false; output = ""; errorOutput = "keypress.none".localized; exitCode = 1
                }
            default:
                var ctx = UseModelExecutor.ExecutionContext()
                let r = ExecutionEngine.shared.execute(steps: [snapshot], context: &ctx)
                success = r.success
                output = "\(ctx.lastOutput)"
                errorOutput = r.error ?? ""
                exitCode = r.success ? 0 : 1
            }
            DispatchQueue.main.async {
                testSuccess = success
                testOutput = output
                testError = errorOutput
                testExitCode = exitCode
                isTesting = false
                didTest = true
                openResultWindow()
            }
        }
    }

    private func openResultWindow() {
        guard didTest else { return }
        let title = step.title.isEmpty ? step.type.displayName : step.title
        (NSApp.delegate as? AppDelegate)?.showStepTestResult(
            title: title,
            success: testSuccess,
            output: testOutput,
            errorOutput: testError,
            exitCode: testExitCode
        )
    }
}

// MARK: - 테스트 결과 별도 창 (스크롤 불필요한 설정 창 + 넓은 결과 창)

/// 테스트 상세 결과를 보여주는 별도 창의 콘텐츠.
/// 설정 창(480pt)보다 넓은 560pt + 리사이즈 가능 + 내부 스크롤로
/// 긴 출력도 설정 창 스크롤 없이 확인 가능하다.
struct StepTestResultView: View {
    @Environment(\.theme) private var theme
    let stepTitle: String
    let success: Bool
    let output: String
    let errorOutput: String
    let exitCode: Int32

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(success ? theme.successColor : theme.errorColor)
                Text(stepTitle)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text("ui.step_settings.exit_code".localizedFormat(Int(exitCode)))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(exitCode == 0 ? .green : .red)
                Button("ui.copy".localized) {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString(fullText, forType: .string)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                Button("ui.close".localized) {
                    NSApp.keyWindow?.performClose(nil)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            Text("ui.step_settings.test_output".localized)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(theme.secondaryText)

            ScrollView {
                Text(fullText)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(12)
            }
            .background(Color.black.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .frame(minHeight: 280)
            .layoutPriority(1)
        }
        .padding(16)
        .frame(minWidth: 560, minHeight: 420)
        .background(theme.secondaryBackground)
    }

    private var fullText: String {
        var lines: [String] = []
        if !output.isEmpty { lines.append(output) }
        if !errorOutput.isEmpty { lines.append(errorOutput) }
        if output.isEmpty && errorOutput.isEmpty {
            lines.append("ui.step_settings.no_output".localized)
        }
        return lines.joined(separator: "\n")
    }
}
