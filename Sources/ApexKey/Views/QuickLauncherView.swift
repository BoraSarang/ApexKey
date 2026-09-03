import SwiftUI

/// Quick Launcher 오버레이 — ⌥⌘Space로 실행, 매크로 이름으로 검색·실행
struct QuickLauncherView: View {
    @EnvironmentObject var store: ConfigStore
    @FocusState private var isSearchFocused: Bool
    @State private var searchText = ""
    @State private var selectedIndex = 0

    var results: [HotKeyBinding] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return []
        }
        return store.binding(matching: searchText)
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            if !results.isEmpty {
                Divider()
                resultList
            } else if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                emptyState
            }
        }
        .frame(width: 480)
        .frame(maxHeight: 360)
        .background(Color(.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 20)
        .onAppear {
            isSearchFocused = true
        }
        .onChange(of: searchText) { _, _ in
            selectedIndex = 0
        }
        .onKeyPress(.escape) {
            store.showQuickLauncher = false
            return .handled
        }
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("매크로 이름으로 검색...", text: $searchText)
                .textFieldStyle(.plain)
                .focused($isSearchFocused)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(14)
    }

    private var resultList: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(Array(results.enumerated()), id: \.element.id) { index, binding in
                    resultRow(binding: binding, index: index, isSelected: index == selectedIndex)
                }
            }
            .padding(4)
        }
        .frame(maxHeight: 280)
    }

    private func resultRow(binding: HotKeyBinding, index: Int, isSelected: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: binding.actionType.systemImage)
                .foregroundColor(.accentColor)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(binding.title)
                    .font(.body)
                    .lineLimit(1)
                Text(binding.actionType.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if !binding.combo.displayString.isEmpty {
                Text(binding.combo.displayString)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture {
            store.executeBinding(binding)
        }
        .onKeyPress(.return) {
            store.executeBinding(binding)
            return .handled
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "xmark.circle")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text("일치하는 매크로를 찾을 수 없습니다")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}