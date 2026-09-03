import SwiftUI

/// 별도 정보(About) 창
struct AboutView: View {
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
                Text("애펙스키")
                    .foregroundColor(.secondary)
            }

            Text("버전 \(version)")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()
                .frame(width: 200)

            Text("최상위(정점)에 오른 글로벌 단축키 매니저")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("© 2026 BoRaSaRang")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(width: 360, height: 320)
        .padding()
    }
}
