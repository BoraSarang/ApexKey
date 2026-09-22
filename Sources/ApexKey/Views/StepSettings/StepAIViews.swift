import AppKit
import SwiftUI

// MARK: - Use Model 설정

struct UseModelSettingsView: View {
    @Binding var step: ShortcutStep
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizedStringKey("action.useModel"))
                .font(.headline)
            
            Picker("ui.model".localized, selection: Binding(
                get: { step.useModel?.modelType ?? .onDevice },
                set: { step.useModel?.modelType = $0 }
            )) {
                ForEach(AIModelType.allCases) { model in
                    Text(model.displayName).tag(model)
                }
            }
            .pickerStyle(.segmented)
            
            TextField("ui.prompt".localized, text: Binding(
                get: { step.useModel?.prompt ?? "" },
                set: { step.useModel?.prompt = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            
            Picker("ui.output_type".localized, selection: Binding(
                get: { step.useModel?.outputType ?? .text },
                set: { step.useModel?.outputType = $0 }
            )) {
                ForEach(AIOutputType.allCases) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.segmented)
            
            Toggle("ui.step_settings.follow_up_chat".localized, isOn: Binding(
                get: { step.useModel?.followUp ?? false },
                set: { step.useModel?.followUp = $0 }
            ))
        }
        .sectionCard()
    }
}

// MARK: - Writing Tool 설정

struct WritingToolSettingsView: View {
    @Binding var step: ShortcutStep
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizedStringKey("action.writingTool"))
                .font(.headline)
            
            Picker("ui.shortcut".localized, selection: Binding(
                get: { step.writingTool?.action ?? .proofread },
                set: { step.writingTool?.action = $0 }
            )) {
                ForEach(WritingToolAction.allCases) { action in
                    Text(action.displayName).tag(action)
                }
            }
            .pickerStyle(.menu)
            
            if step.writingTool?.action == .changeTone {
                Picker("ui.tone".localized, selection: Binding(
                    get: { step.writingTool?.tone ?? .professional },
                    set: { step.writingTool?.tone = $0 }
                )) {
                    ForEach(WritingTone.allCases) { tone in
                        Text(tone.displayName).tag(tone)
                    }
                }
                .pickerStyle(.menu)
            }
            
            TextField("ui.step_settings.input_uuid".localized, text: Binding(
                get: { step.writingTool?.inputVariable.uuidString ?? "" },
                set: { step.writingTool?.inputVariable = UUID(uuidString: $0) ?? UUID() }
            ))
            .textFieldStyle(.roundedBorder)
        }
        .sectionCard()
    }
}

// MARK: - Image Playground 설정

struct ImagePlaygroundSettingsView: View {
    @Binding var step: ShortcutStep
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ui.editor.step_image".localized)
                .font(.headline)
            
            TextField("ui.prompt".localized, text: Binding(
                get: { step.imagePlayground?.prompt ?? "" },
                set: { step.imagePlayground?.prompt = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            
            Picker("ui.style".localized, selection: Binding(
                get: { step.imagePlayground?.style ?? .animation },
                set: { step.imagePlayground?.style = $0 }
            )) {
                ForEach(ImagePlaygroundStyle.allCases) { style in
                    Text(style.displayName).tag(style)
                }
            }
            .pickerStyle(.segmented)
        }
        .sectionCard()
    }
}
