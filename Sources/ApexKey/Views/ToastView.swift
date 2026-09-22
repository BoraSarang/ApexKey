import SwiftUI

/// 실행 결과 토스트 페이로드 — OS 알림센터 없이 앱 내 플로팅으로 표시.
struct ToastPayload {
    /// 실행된 항목 이름 (바인딩 제목/동작 이름)
    var title: String
    /// 실패 사유 (성공 시 nil)
    var message: String?
    var success: Bool
}

/// 글로벌 단축키 실행 결과 토스트.
/// 성공: 체크 + 제목만 짧게. 실패: 사유 표시 + 클릭 시 디버그 로그로 이동.
struct ToastView: View {
    @Environment(\.theme) private var theme
    let payload: ToastPayload
    var onTap: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: payload.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(payload.success ? theme.successColor : theme.errorColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(payload.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.primaryText)
                    .lineLimit(1)
                if let message = payload.message, !message.isEmpty {
                    Text(message)
                        .font(.system(size: 12))
                        .foregroundColor(theme.secondaryText)
                        .lineLimit(3)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        // 한글 장문 메시지 넘침 방지 — 최소 340, 최대 440까지 확장, 높이는 내용 기준
        .frame(minWidth: 340, maxWidth: 440, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .background(theme.primaryBackground.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    (payload.success ? theme.successColor : theme.errorColor).opacity(0.35),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            // 실패 토스트만 탭 동작 (디버그 로그로 이동)
            if !payload.success {
                onTap?()
            }
        }
    }
}
