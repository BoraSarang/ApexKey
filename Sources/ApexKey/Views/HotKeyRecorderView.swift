import SwiftUI
import AppKit

/// 키 입력을 받아 글로벌 단축키를 매핑하는 시트 (앱 메뉴 / 시스템 동작 / 스크립트 공용)
///
/// 저장 시 중복/사용 가능 여부를 확인한 뒤
/// - 사용 가능: "적용되었습니다" 표시 후 3초 뒤 자동 닫힘
/// - 중복/사용 불가: 사유 안내 후 재입력 가능 (닫히지 않음)
/// - "ui.test".localized 버튼으로 실제 등록 뒤 누르면 onTest로 실제 액션을 실행해 확인
struct HotKeyRecorderView: View {
    @EnvironmentObject var store: ConfigStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    let title: String
    /// 앱 단축키일 때의 보조 설명 (앱 이름). nil이면 "ui.appdetail.run_globally".localized 표시.
    var subtitle: String?
    /// 교체 대상 기능이 현재 사용 중인 조합 (같은 조합 재지정 시 중복 판정 제외)
    var excludedCombo: HotKeyCombo?
    var onRecord: (HotKeyCombo) -> Void
    /// 테스트 버튼이 키를 감지했을 때 실제 액션을 실행하는 프리뷰 (실행 여부 반환)
    var onTest: ((HotKeyCombo) -> Bool)?

    init(title: String, subtitle: String? = nil, excludedCombo: HotKeyCombo? = nil,
         onTest: ((HotKeyCombo) -> Bool)? = nil,
         onRecord: @escaping (HotKeyCombo) -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.excludedCombo = excludedCombo
        self.onTest = onTest
        self.onRecord = onRecord
    }

    /// 상태 안내 메시지
    enum Message: Equatable {
        case applying     // 적용 완료 — 곧 자동 닫힘
        case duplicate    // 중복
        case unavailable  // 사용 불가
        case testing      // 테스트 대기
        case testPassed   // 테스트 성공
        case testFailed   // 테스트 감지됨, 액션 실행 실패
    }

    private enum Availability {
        case ok
        case duplicate
        case unavailable
    }

    @State private var currentCombo: HotKeyCombo = .empty
    @State private var testCombo: HotKeyCombo = .empty
    @State private var monitor: Any?
    @State private var message: Message?
    @State private var testID: UUID?
    @State private var testTimer: DispatchWorkItem?

    private let hotKeyService = HotKeyService.shared

    var body: some View {
        VStack(spacing: 20) {
            Text(title)
                .font(.headline)

            // 키 표시 영역
            Text(currentCombo.displayString.isEmpty ? "ui.recorder.press_keys".localized : currentCombo.displayString)
                .font(.system(size: 40, weight: .bold, design: .monospaced))
                // 긴 단축키 조합도 잘리지 않게 최소 300 유지, 길면 확장
                .frame(minWidth: 300, minHeight: 80)
                .frame(idealWidth: 300, idealHeight: 80)
                .background(keyBackground)
                .cornerRadius(10)
                .foregroundColor(keyForeground)
                .animation(.easeInOut(duration: 0.15), value: currentCombo)
                .animation(.easeInOut(duration: 0.15), value: message)

            messageView

            HStack(spacing: 12) {
                Button("ui.cancel".localized) { dismiss() }
                Button("ui.test".localized) { startTest() }
                    .disabled(currentCombo.isEmpty || isApplying || message == .testing)
                Button("ui.save".localized) { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(currentCombo.isEmpty || isApplying)
            }
        }
        .padding(24)
        .onAppear {
            installMonitor()
        }
        .onDisappear {
            removeMonitor()
            hotKeyService.endTest()
            testTimer?.cancel()
        }
        .onReceive(hotKeyService.hotKeyPressed) { id in
            // 테스트 중 누른 단축키가 실제로 등록 반응하면 성공 처리
            guard let testID, id == testID else { return }
            hotKeyService.endTest()
            let combo = testCombo
            self.testID = nil
            testTimer?.cancel()
            // 실제 액션 실행까지 성공해야 테스트 성공 (onTest 없으면 감지만으로 성공)
            let executed = onTest?(combo) ?? true
            message = executed ? .testPassed : .testFailed
        }
    }

    // MARK: - 표시

    private var isApplying: Bool { message == .applying }

    private var keyForeground: Color {
        switch message {
        case .duplicate, .unavailable, .testFailed: return theme.errorColor
        case .testPassed: return theme.successColor
        case .applying: return theme.successColor
        default: return theme.primaryText
        }
    }

    private var keyBackground: Color {
        switch message {
        case .duplicate, .unavailable, .testFailed: return theme.errorColor.opacity(0.15)
        case .testPassed, .applying: return theme.successColor.opacity(0.12)
        default: return theme.tertiaryBackground.opacity(0.5)
        }
    }

    @ViewBuilder
    private var messageView: some View {
        switch message {
        case .applying:
            Label("ui.recorder.saved".localized, systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundColor(theme.successColor)
                .transition(.opacity)
        case .duplicate:
            Label("ui.recorder.duplicate".localized, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundColor(theme.warningColor)
                .transition(.opacity)
        case .unavailable:
            Label("ui.recorder.unavailable".localized, systemImage: "xmark.octagon.fill")
                .font(.caption)
                .foregroundColor(theme.errorColor)
                .transition(.opacity)
        case .testing:
            Label("ui.recorder.testing".localized, systemImage: "dot.radiowaves.left.and.right")
                .font(.caption)
                .foregroundColor(theme.accentColor)
                .transition(.opacity)
        case .testPassed:
            Label("ui.recorder.test_success".localized, systemImage: "checkmark.seal.fill")
                .font(.caption)
                .foregroundColor(theme.successColor)
                .transition(.opacity)
        case .testFailed:
            Label("ui.recorder.test_failed".localized, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundColor(theme.warningColor)
                .transition(.opacity)
        case nil:
            Text(subtitle ?? "ui.appdetail.run_globally".localized)
                .font(.caption)
                .foregroundColor(theme.secondaryText)
        }
    }

    // MARK: - 로직

    private func installMonitor() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Esc면 취소
            if event.keyCode == 53 {
                dismiss()
                return nil
            }
            // 순수 수식키만 누른 경우 여기선 무시
            if event.modifierFlags.intersection([.command, .shift, .option, .control]).isEmpty {
                return nil
            }
            let combo = KeyboardUtil.combo(from: event)
            guard KeyboardUtil.hasModifier(combo) && !combo.isEmpty else { return nil }

            // 새 조합 입력 시 기존 상태 초기화 (테스트 중이면 중단)
            if message == .testing {
                hotKeyService.endTest()
                testID = nil
                testTimer?.cancel()
            }
            message = nil
            currentCombo = combo
            return nil
        }
    }

    private func removeMonitor() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }

    /// 저장 처리: 사용 가능 여부 확인 후 적용 또는 사유 안내
    private func save() {
        guard !currentCombo.isEmpty else { return }
        switch availability(of: currentCombo) {
        case .ok:
            hotKeyService.endTest()
            onRecord(currentCombo)
            message = .applying
            removeMonitor()
            // 3초 후 자동 닫힘
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                dismiss()
            }
        case .duplicate:
            feedback(.duplicate)
        case .unavailable:
            feedback(.unavailable)
        }
    }

    /// 테스트: 실제 등록 후 사용자가 그 조합을 누르면 성공 처리
    private func startTest() {
        guard !currentCombo.isEmpty else { return }
        switch availability(of: currentCombo) {
        case .ok:
            guard let id = hotKeyService.beginTest(currentCombo) else {
                feedback(.unavailable)
                return
            }
            testID = id
            testCombo = currentCombo
            testTimer?.cancel()
            let workItem = DispatchWorkItem {
                hotKeyService.endTest()
                self.testID = nil
                self.message = nil
            }
            testTimer = workItem
            message = .testing
            DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: workItem)
        case .duplicate:
            feedback(.duplicate)
        case .unavailable:
            feedback(.unavailable)
        }
    }

    /// 조합 사용 가능 여부 판별
    private func availability(of combo: HotKeyCombo) -> Availability {
        guard !combo.isEmpty else { return .unavailable }
        // 교체 대상과 동일한 조합이면 그대로 허용 (재지정)
        if let excludedCombo, excludedCombo.matches(combo) {
            return .ok
        }
        // ApexKey 내부 다른 등록과 충돌 → 중복
        let hasOwnConflict = hotKeyService.registeredCombos(excluding: UUID())
            .contains { $0.matches(combo) }
        if hasOwnConflict {
            return .duplicate
        }
        // 시스템/다른 앱이 점유 중이면 사용 불가
        return hotKeyService.isComboAvailable(combo) ? .ok : .unavailable
    }

    /// 실패 안내 후 재입력 대기 상태로
    private func feedback(_ msg: Message) {
        hotKeyService.endTest()
        message = msg
        testID = nil
        testCombo = .empty
        testTimer?.cancel()
        currentCombo = .empty
    }
}