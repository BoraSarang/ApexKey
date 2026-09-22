import SwiftUI

/// 새 버전 안내 시트 — 설정의 `.sheet`와 AppDelegate 소유 `NSWindow`에서 공유한다.
/// `onClose`가 nil이면 기존 `dismiss()` (설정 경로 불변),
/// 윈도우 경로에서는 `close()`를 전달해 윈도우를 직접 닫는다.
struct UpdateAvailableSheet: View {
    let release: GitHubRelease
    let currentVersion: String
    var onClose: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.theme) private var theme

    private func close() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("update.available_title".localizedFormat(release.tagName))
                        .font(.headline)
                    Text("update.current_version".localizedFormat(currentVersion))
                        .font(.caption)
                        .foregroundColor(theme.secondaryText)
                }
            }

            Divider()

            ScrollView {
                if let notes = release.body, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ReleaseNotesView(markdown: notes)
                } else {
                    Text("update.no_notes".localized)
                        .font(.callout)
                        .foregroundColor(theme.secondaryText)
                }
            }
            .frame(minHeight: 120, maxHeight: 280)

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("update.howto_title".localized)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("update.howto_body".localized)
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
            }

            HStack {
                Spacer()
                Button("update.close".localized) { close() }
                    .keyboardShortcut(.cancelAction)
                Button("update.download".localized) {
                    // 에셋 직접 링크가 아니라 릴리스 페이지로 보낸다
                    // (공증 없음 안내 노출 목적). 브라우저를 열고 창은 닫는다.
                    if let url = URL(string: release.htmlURL) {
                        openURL(url)
                    }
                    close()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 480, height: 520)
        .background(theme.primaryBackground)
    }
}
