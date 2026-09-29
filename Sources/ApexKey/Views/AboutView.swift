import SwiftUI

/// 별도 정보(About) 창
struct AboutView: View {
    @EnvironmentObject var store: ConfigStore
    @Environment(\.theme) private var theme

    private var version: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(colors: [Color(red: 48/255, green: 197/255, blue: 160/255),
                                                Color(red: 108/255, green: 92/255, blue: 231/255)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 84, height: 84)
                Image(systemName: "command")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundColor(Color(red: 0.96, green: 0.82, blue: 0.26))
            }

            VStack(spacing: 4) {
                Text("ApexKey")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("ui.about.app_name".localized)
                    .foregroundColor(theme.secondaryText)
            }

            Text("ui.about.version".localizedFormat(version))
                .font(.caption)
                .foregroundColor(theme.secondaryText)

            HStack(spacing: 8) {
                if case .checking = store.updateState {
                    ProgressView()
                        .controlSize(.small)
                    Text("update.checking".localized)
                        .font(.caption)
                        .foregroundColor(theme.secondaryText)
                } else {
                    Button("update.check".localized) {
                        Task {
                            // 새 버전이면 AppDelegate 공용 안내 창으로 자동 팝업
                            let hasUpdate = await store.checkForUpdate()
                            if hasUpdate {
                                NotificationCenter.default.post(name: .showUpdateSheet, object: nil)
                            }
                        }
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                    switch store.updateState {
                    case let .updateAvailable(tag, _, _):
                        Text("update.available".localizedFormat(tag))
                            .font(.caption)
                            .foregroundColor(.orange)
                    case .upToDate:
                        Text("update.up_to_date".localized)
                            .font(.caption)
                            .foregroundColor(theme.secondaryText)
                    case let .unavailable(key):
                        Text(key.localized)
                            .font(.caption)
                            .foregroundColor(.red)
                    case .idle, .checking:
                        EmptyView()
                    }
                }
            }

            Divider()
                .frame(width: 200)

            Text("ui.about.tagline".localized)
                .font(.caption)
                .foregroundColor(theme.secondaryText)

            Text("© \(Calendar.current.component(.year, from: Date())) BoRaSaRang")
                .font(.caption2)
                .foregroundStyle(theme.tertiaryText)
        }
        .frame(width: 360, height: 360)
        .padding()
        .background(theme.primaryBackground)
    }
}
