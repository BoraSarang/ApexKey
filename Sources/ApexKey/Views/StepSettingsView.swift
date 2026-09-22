import AppKit
import SwiftUI

/// 단계 상세 설정 시트 — 흐름 제어 / AI / 변수 단계의 설정을 편집
struct StepSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @Binding var step: ShortcutStep
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 헤더 (고정)
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(accentColor.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: step.type.systemImage)
                        .font(.system(size: 14))
                        .foregroundColor(accentColor)
                }
                
                Text(step.type.displayName)
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("ui.done".localized) { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            .padding(16)
            
            Divider()
            
            // 본문 (스크롤 — 입력 필드는 각자 내부 스크롤)
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

            Divider()

            // 하단 테스트 푸터 (항상 가시 — 스크롤 안 됨)
            StepTestFooter(step: $step)
        }
        // 소형 창에서도 밀리지 않게 최소 크기 유지 — 상단은 헤더, 하단은 푸터 고정
        .frame(minWidth: 480, minHeight: 480)
        .frame(idealWidth: 480, idealHeight: 680)
        .background(theme.secondaryBackground)
    }
    
    // MARK: - 공통 설정
    
    private var commonSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ui.step_settings.general".localized)
                .font(.headline)
            
            Toggle("ui.step_settings.skip".localized, isOn: $step.isSkipped)
            
            TextField("ui.step_settings.note".localized, text: Binding(
                get: { step.note ?? "" },
                set: { step.note = $0.isEmpty ? nil : $0 }
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
        switch step.type {
        case .launchApp:
            LaunchAppSettingsView(step: $step)
        case .keyCombo:
            KeyPressSettingsView(step: $step)
        case .ifElse:
            IfSettingsView(step: $step)
        case .repeatLoop, .repeatEach:
            RepeatSettingsView(step: $step)
        case .chooseFromMenu:
            MenuSettingsView(step: $step)
        case .useModel:
            UseModelSettingsView(step: $step)
        case .writingTool:
            WritingToolSettingsView(step: $step)
        case .imagePlayground:
            ImagePlaygroundSettingsView(step: $step)
        case .setVariable, .outputToVariable:
            VariableStepSettingsView(step: $step)
        case .comment:
            CommentSettingsView(step: $step)
        case .system:
            if let type = SystemActionType(rawValue: step.target) {
                // 시스템 프리셋 — 스크립트 보기/테스트/수정/저장 (기존 시스템 탭 이관)
                SystemScriptEditorView(type: type)
            } else {
                DefaultSettingsView(step: $step)
            }
        default:
            // 기본 단계: 대상/제목 편집
            DefaultSettingsView(step: $step)
        }
    }
    
    private var accentColor: Color {
        switch step.type.category {
        case .flowControl: return .indigo
        case .ai: return .mint
        case .variables: return .cyan
        default: return .blue
        }
    }
}
