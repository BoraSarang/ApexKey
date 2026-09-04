import SwiftUI

// MARK: - Sidebar Item Data

/// Data model representing a single item in the sidebar navigation.
struct SidebarItemData: Identifiable, Hashable {
    let id: String
    let icon: String
    let label: String
    var badge: Int?
    var badgeHighlight: Bool = false

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: SidebarItemData, rhs: SidebarItemData) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Sidebar Section Data

/// A labeled group of sidebar items. Sections render a small uppercase
/// header when the sidebar is expanded and a thin divider when collapsed.
/// An empty `title` renders the items without a header.
struct SidebarSectionData: Identifiable {
    let id: String
    let title: String
    let items: [SidebarItemData]
    var isCollapsible: Bool = false
}

/// Persistence for collapsible-section expansion.
enum SidebarSectionExpansion {
    static let defaultsKey = "settingsSidebarExpandedSections"
}

// MARK: - Layout Constants

private enum SidebarLayout {
    static let expandedWidth: CGFloat = 240
    static let collapsedWidth: CGFloat = 64
    static let topPadding: CGFloat = 26
    static let bottomPadding: CGFloat = 16
    static let expandedHorizontalPadding: CGFloat = 12
    static let collapsedHorizontalPadding: CGFloat = 8
    static let expandedItemSpacing: CGFloat = 4
    static let collapsedItemSpacing: CGFloat = 6
}

// MARK: - Sidebar Navigation

/// A sidebar navigation container inspired by macOS System Settings:
/// collapsible state, animated selection, hover effects, and search.
struct SidebarNavigation<Content: View, Footer: View>: View {

    @Environment(\.theme) private var theme
    @Binding var selection: String
    @Binding var searchText: String
    let sections: [SidebarSectionData]
    let content: (String) -> Content
    let footer: () -> Footer

    @State private var isCollapsed = false
    @State private var canScrollDown = true
    @Namespace private var sidebarNamespace

    @State private var expandedCollapsibleSections: Set<String> = Set(
        UserDefaults.standard.stringArray(forKey: SidebarSectionExpansion.defaultsKey) ?? []
    )

    private var sidebarWidth: CGFloat {
        isCollapsed ? SidebarLayout.collapsedWidth : SidebarLayout.expandedWidth
    }

    init(
        selection: Binding<String>,
        searchText: Binding<String>,
        sections: [SidebarSectionData],
        @ViewBuilder content: @escaping (String) -> Content,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self._selection = selection
        self._searchText = searchText
        self.sections = sections
        self.content = content
        self.footer = footer
    }

    /// Convenience for a flat, unlabeled item list.
    init(
        selection: Binding<String>,
        searchText: Binding<String>,
        items: [SidebarItemData],
        @ViewBuilder content: @escaping (String) -> Content,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.init(
            selection: selection,
            searchText: searchText,
            sections: [SidebarSectionData(id: "main", title: "", items: items)],
            content: content,
            footer: footer
        )
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            divider
            contentArea
        }
        .ignoresSafeArea(edges: .top)
    }
}

// MARK: - Sidebar Components

private extension SidebarNavigation {

    var sidebar: some View {
        VStack(alignment: isCollapsed ? .center : .leading, spacing: 0) {
            collapseToggle
            if !isCollapsed { searchField }
            itemList
            if !isCollapsed {
                footer()
                    .padding(.top, 8)
                    .overlay(alignment: .top) { footerScrollShadow }
            }
        }
        .padding(.top, SidebarLayout.topPadding)
        .padding(.bottom, SidebarLayout.bottomPadding)
        .padding(
            .horizontal,
            isCollapsed ? SidebarLayout.collapsedHorizontalPadding : SidebarLayout.expandedHorizontalPadding
        )
        .frame(width: sidebarWidth)
        .background(theme.sidebarBackground)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isCollapsed)
    }

    var collapseToggle: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isCollapsed.toggle()
            }
        } label: {
            Image(systemName: "sidebar.left")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(theme.secondaryText)
                .frame(width: isCollapsed ? 44 : 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(theme.tertiaryBackground.opacity(0.5))
                )
        }
        .buttonStyle(.plain)
        .help(isCollapsed ? "사이드바 펼치기" : "사이드바 접기")
        .frame(maxWidth: .infinity, alignment: isCollapsed ? .center : .trailing)
        .padding(.bottom, isCollapsed ? 12 : 8)
    }

    var searchField: some View {
        SettingsSidebarSearchField(text: $searchText)
            .padding(.bottom, 8)
    }

    var itemList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(
                    alignment: isCollapsed ? .center : .leading,
                    spacing: isCollapsed ? SidebarLayout.collapsedItemSpacing : SidebarLayout.expandedItemSpacing
                ) {
                    ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                        sectionHeader(for: section, isFirst: index == 0)

                        if showsItems(for: section) {
                            ForEach(section.items) { item in
                                SidebarItemView(
                                    item: item,
                                    isSelected: selection == item.id,
                                    isCollapsed: isCollapsed,
                                    namespace: sidebarNamespace
                                ) {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        selection = item.id
                                    }
                                }
                                .id(item.id)
                            }
                        }
                    }

                    Color.clear
                        .frame(height: 1)
                        .onAppear { canScrollDown = false }
                        .onDisappear { canScrollDown = true }
                }
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
            .onChange(of: selection) { _, newValue in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
            .onAppear {
                proxy.scrollTo(selection, anchor: .center)
            }
        }
    }

    func showsItems(for section: SidebarSectionData) -> Bool {
        guard section.isCollapsible else { return true }
        return expandedCollapsibleSections.contains(section.id)
            || section.items.contains { $0.id == selection }
    }

    func toggleSectionExpansion(_ section: SidebarSectionData) {
        withAnimation(.easeOut(duration: 0.2)) {
            if expandedCollapsibleSections.contains(section.id) {
                expandedCollapsibleSections.remove(section.id)
            } else {
                expandedCollapsibleSections.insert(section.id)
            }
        }
        UserDefaults.standard.set(
            Array(expandedCollapsibleSections).sorted(),
            forKey: SidebarSectionExpansion.defaultsKey
        )
    }

    @ViewBuilder
    func sectionHeader(for section: SidebarSectionData, isFirst: Bool) -> some View {
        if !section.title.isEmpty {
            if isCollapsed {
                if !isFirst {
                    Rectangle()
                        .fill(theme.primaryBorder.opacity(0.6))
                        .frame(width: 24, height: 1)
                        .padding(.vertical, 4)
                }
            } else if section.isCollapsible {
                SidebarCollapsibleSectionHeader(
                    title: section.title,
                    isExpanded: showsItems(for: section),
                    topPadding: isFirst ? 4 : 16
                ) {
                    toggleSectionExpansion(section)
                }
            } else {
                SidebarSectionHeader(title: section.title, topPadding: isFirst ? 4 : 16)
            }
        }
    }

    var footerScrollShadow: some View {
        LinearGradient(
            stops: [
                .init(color: Color.black.opacity(0.18), location: 0),
                .init(color: Color.black.opacity(0.06), location: 0.5),
                .init(color: Color.black.opacity(0), location: 1),
            ],
            startPoint: .bottom,
            endPoint: .top
        )
        .frame(height: 24)
        .offset(y: -24)
        .opacity(canScrollDown ? 1 : 0)
        .animation(.easeOut(duration: 0.2), value: canScrollDown)
        .allowsHitTesting(false)
    }

    var divider: some View {
        Rectangle()
            .fill(theme.primaryBorder)
            .frame(width: 1)
            .ignoresSafeArea(edges: .top)
    }

    var contentArea: some View {
        ZStack {
            content(selection)
                .id(selection)
                .transition(.opacity.animation(.easeOut(duration: 0.2)))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeOut(duration: 0.2), value: selection)
    }
}

// MARK: - Convenience Initializer (No Footer)

extension SidebarNavigation where Footer == EmptyView {
    init(
        selection: Binding<String>,
        searchText: Binding<String>,
        items: [SidebarItemData],
        @ViewBuilder content: @escaping (String) -> Content
    ) {
        self.init(
            selection: selection,
            searchText: searchText,
            items: items,
            content: content,
            footer: { EmptyView() }
        )
    }
}

// MARK: - Sidebar Item View

/// Individual item row in the sidebar with selection and hover states.
private struct SidebarItemView: View {

    @Environment(\.theme) private var theme

    let item: SidebarItemData
    let isSelected: Bool
    let isCollapsed: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            if isCollapsed {
                collapsedContent
            } else {
                expandedContent
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }

    // MARK: Collapsed State

    private var collapsedContent: some View {
        ZStack {
            Image(systemName: item.icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(isSelected ? theme.accentColor : theme.secondaryText)
                .symbolRenderingMode(.hierarchical)

            if item.badge != nil {
                Circle()
                    .fill(item.badgeHighlight ? theme.accentColor : theme.tertiaryBackground)
                    .overlay(
                        Circle().stroke(
                            item.badgeHighlight ? theme.accentColor.opacity(0.5) : theme.primaryBorder.opacity(0.5),
                            lineWidth: 0.5
                        )
                    )
                    .frame(width: 8, height: 8)
                    .offset(x: 12, y: -12)
            }
        }
        .frame(width: 44, height: 40)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    isSelected
                        ? theme.sidebarSelectedBackground
                        : (isHovering ? theme.tertiaryBackground.opacity(0.6) : Color.clear)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? theme.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .help(item.label)
    }

    // MARK: Expanded State

    private var expandedContent: some View {
        HStack(spacing: 10) {
            Image(systemName: item.icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isSelected ? theme.accentColor : theme.secondaryText)
                .frame(width: 24)

            Text(item.label)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular, design: .rounded))
                .foregroundColor(isSelected ? theme.primaryText : theme.secondaryText)

            Spacer()

            if let badge = item.badge, badge > 0 {
                Text("\(badge)")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(item.badgeHighlight ? .white : theme.secondaryText)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(item.badgeHighlight ? theme.accentColor : theme.tertiaryBackground))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            Group {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(theme.sidebarSelectedBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(theme.accentColor.opacity(0.3), lineWidth: 1)
                        )
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isHovering ? theme.tertiaryBackground.opacity(0.6) : Color.clear)
                }
            }
        )
        .contentShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Sidebar Section Header

private struct SidebarSectionHeader: View {
    @Environment(\.theme) private var theme
    let title: String
    var topPadding: CGFloat = 16

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundColor(theme.tertiaryText)
            .padding(.horizontal, 12)
            .padding(.top, topPadding)
            .padding(.bottom, 4)
    }
}

/// Section header with a literal switch for collapsible groups.
private struct SidebarCollapsibleSectionHeader: View {
    @Environment(\.theme) private var theme
    let title: String
    let isExpanded: Bool
    var topPadding: CGFloat = 16
    let action: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(theme.tertiaryText)
            Spacer(minLength: 0)
            Toggle(
                "",
                isOn: Binding(
                    get: { isExpanded },
                    set: { _ in action() }
                )
            )
            .toggleStyle(.switch)
            .controlSize(.mini)
            .labelsHidden()
        }
        .padding(.horizontal, 12)
        .padding(.top, topPadding)
        .padding(.bottom, 4)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Sidebar Search Field

/// Search field component for the sidebar.
struct SettingsSidebarSearchField: View {
    @Environment(\.theme) private var theme
    @Binding var text: String
    @FocusState private var isFocused: Bool
    @State private var isClearHovering = false

    var body: some View {
        HStack(spacing: 8) {
            searchIcon
            textField
            if !text.isEmpty { clearButton }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(fieldBackground)
        .animation(.easeOut(duration: 0.15), value: isFocused)
    }

    private var searchIcon: some View {
        Image(systemName: "magnifyingglass")
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(isFocused ? theme.accentColor : theme.tertiaryText)
    }

    private var textField: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty {
                Text("검색")
                    .font(.system(size: 12))
                    .foregroundColor(theme.secondaryText)
                    .allowsHitTesting(false)
            }
            TextField("", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundColor(theme.primaryText)
                .focused($isFocused)
        }
    }

    private var clearButton: some View {
        Button {
            text = ""
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 11))
                .foregroundColor(isClearHovering ? theme.secondaryText : theme.tertiaryText)
        }
        .buttonStyle(.plain)
        .onHover { isClearHovering = $0 }
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(theme.tertiaryBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isFocused ? theme.accentColor.opacity(0.6) : theme.primaryBorder.opacity(0.5),
                        lineWidth: 1
                    )
            )
    }
}
