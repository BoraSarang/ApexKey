import SwiftUI

/// 트랙패드 스테이션 — 에지 슬라이더 + 제스처 규칙 관리.
///
/// 설계 원칙
/// - 마스터 토글이 꺼져 있으면 엔진을 올리지 않는다(기본 꺼짐, 모듈 격리).
/// - 규칙 저장은 UserDefaults JSON(`ConfigStore+Trackpad`) — SwiftData 스키마 무변경.
/// - 화면은 목업 v4(`docs/plans/trackpad-gestures-mockup.html`)의 구조를 그대로 따른다.
struct TrackpadView: View {
    @EnvironmentObject var store: ConfigStore
    @Environment(\.theme) private var theme
    @ObservedObject private var engine = TrackpadEngine.shared

    @State private var activeSheet: TrackpadEditorSheet?
    @State private var advancedExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if !store.trackpadEnabled {
                        offBanner
                    }
                    engineStatusCard
                    HStack(alignment: .top, spacing: 14) {
                        previewCard
                        permissionCard
                    }
                    sliderSection
                    gestureSection
                    advancedSection
                    Text("trackpad.foot_note".localized)
                        .font(.caption2)
                        .foregroundColor(theme.tertiaryText)
                        .padding(.top, 2)
                }
                .padding(16)
            }
        }
        .frame(minWidth: 560, minHeight: 520)
        .background(theme.primaryBackground)
        .sheet(item: $activeSheet) { sheet in
            sheetContent(sheet)
                .environmentObject(store)
        }
    }

    // MARK: - 헤더

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "rectangle.and.hand.point.up.left")
                .frame(width: 36, height: 36)
                .font(.title3)
                .foregroundColor(theme.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("trackpad.title".localized)
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("trackpad.rule_count".localizedFormat(store.trackpadSliders.count + store.trackpadGestures.count))
                        .font(.caption2)
                        .foregroundColor(theme.secondaryText)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(theme.tertiaryBackground)
                        .clipShape(Capsule())
                }
                Text("trackpad.subtitle".localized)
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { store.trackpadEnabled },
                set: { store.setTrackpadEnabled($0) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .help("trackpad.enabled".localized)
            Button {
                activeSheet = .chooser
            } label: {
                Label("trackpad.add".localized, systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var offBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
            Text("trackpad.off_banner".localized)
                .font(.caption)
            Spacer()
        }
        .foregroundColor(theme.secondaryText)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(theme.tertiaryBackground.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var engineStatusCard: some View {
        switch engine.status {
        case .unavailable(let reason):
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(theme.warningColor)
                VStack(alignment: .leading, spacing: 3) {
                    Text("trackpad.status.unavailable".localized)
                        .font(.caption)
                        .fontWeight(.medium)
                    Text("trackpad.unavailable.desc".localized)
                        .font(.caption2)
                        .foregroundColor(theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(reason)
                        .font(.caption2)
                        .foregroundColor(theme.tertiaryText)
                }
                Spacer()
                Button("trackpad.retry".localized) {
                    engine.apply(enabled: true, store: store)
                }
                .controlSize(.small)
            }
            .padding(12)
            .background(theme.warningColor.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        default:
            if store.trackpadEnabled, !engine.suppressionReady {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                    Text("trackpad.status.suppression_off".localized)
                        .font(.caption2)
                    Spacer()
                    Button("trackpad.permission.need".localized) {
                        PermissionHelper.requestAccessibility()
                    }
                    .controlSize(.small)
                }
                .foregroundColor(theme.warningColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(theme.warningColor.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    // MARK: - 미리보기 + 권한

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("trackpad.preview.title".localized)
                    .font(.headline)
                Text(previewDescription)
                    .font(.caption2)
                    .foregroundColor(theme.secondaryText)
            }

            GeometryReader { geo in
                trackpadPreview(size: geo.size)
                    .frame(width: geo.size.width, height: geo.size.height)
            }
            .frame(height: 190)

            if let hint = previewDirectionHint {
                Text(hint)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(theme.accentColor)
            }

            HStack(spacing: 6) {
                Circle()
                    .fill(store.trackpadEnabled && engine.status == .running
                          ? theme.successColor : theme.tertiaryText)
                    .frame(width: 6, height: 6)
                Text(store.trackpadEnabled ? "trackpad.status.running".localized : "trackpad.status.off".localized)
                    .font(.caption2)
                    .foregroundColor(theme.secondaryText)
                Spacer()
                if let volume = engine.preview.volume {
                    Text("trackpad.volume".localized + " " + "\(Int((volume * 100).rounded()))%")
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundColor(theme.secondaryText)
                }
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(theme.cardBorder, lineWidth: 1)
        )
    }

    private var previewDescription: String {
        guard let rule = store.trackpadSliders.first(where: { $0.enabled }) ?? store.trackpadSliders.first else {
            return "trackpad.preview.desc".localized
        }
        let hint = rule.edge.isVertical
            ? "trackpad.preview.hint".localized
            : "trackpad.preview.hint.horizontal".localized
        return "\(rule.edge.displayName) · \(hint)"
    }

    /// 지금 방향이 어느 쪽인지 한 줄로 못 박아 준다 — 실기에서 "방향을 모르겠다"는 피드백.
    private var previewDirectionHint: String? {
        guard let rule = store.trackpadSliders.first(where: { $0.enabled }) ?? store.trackpadSliders.first,
              rule.target == .volume else { return nil }
        if rule.edge.isVertical {
            return (rule.inverted
                    ? "trackpad.preview.dir.volume.down"
                    : "trackpad.preview.dir.volume.up").localized
        }
        return (rule.inverted
                ? "trackpad.preview.dir.volume.left"
                : "trackpad.preview.dir.volume.right").localized
    }

    private func trackpadPreview(size: CGSize) -> some View {
        let activeEdge = store.trackpadSliders.first(where: { $0.enabled })?.edge
        let edgeWidth = store.trackpadSliders.first(where: { $0.enabled })?.edgeWidth ?? 0.12
        let live = store.trackpadEnabled && engine.status == .running
        return ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.tertiaryBackground.opacity(0.55))
            RoundedRectangle(cornerRadius: 12)
                .stroke(theme.primaryBorder, lineWidth: 1)

            // 격자
            Path { path in
                for fraction in stride(from: 0.25, to: 1.0, by: 0.25) {
                    let x = size.width * fraction
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    let y = size.height * fraction
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }
            }
            .stroke(theme.primaryBorder.opacity(0.5), lineWidth: 0.5)

            // 활성 에지 띠
            if let edge = activeEdge {
                edgeBand(edge: edge, edgeWidth: edgeWidth, size: size)
            }

            // 손가락 접점
            if live {
                ForEach(Array(engine.preview.touches.enumerated()), id: \.offset) { _, touch in
                    Circle()
                        .fill(theme.accentColor)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Color.white.opacity(0.8), lineWidth: 1))
                        .position(
                            // 원시 y는 위로 갈수록 커진다 — 화면 좌표(위가 0)로 뒤집는다.
                            x: CGFloat(touch.x) * size.width,
                            y: (1 - CGFloat(touch.y)) * size.height
                        )
                }
            }

            // 안내 문구
            if !live {
                Text("trackpad.preview.off".localized)
                    .font(.caption2)
                    .foregroundColor(theme.tertiaryText)
            }

            // 볼륨 HUD 목업
            if let volume = engine.preview.volume, live {
                VStack {
                    Spacer()
                    HStack(spacing: 7) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.caption2)
                        Capsule()
                            .fill(theme.tertiaryBackground)
                            .overlay(alignment: .leading) {
                                GeometryReader { bar in
                                    Capsule()
                                        .fill(theme.accentColor)
                                        .frame(width: max(4, bar.size.width * CGFloat(volume)))
                                }
                            }
                            .frame(width: 96, height: 5)
                        Text("\(Int((volume * 100).rounded()))%")
                            .font(.caption2)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.regularMaterial)
                    .clipShape(Capsule())
                    .padding(.bottom, 10)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func edgeBand(edge: TrackpadEdge, edgeWidth: Double, size: CGSize) -> some View {
        // 인식은 "손가락 평균 위치" 기준이라 두 손가락이 조금 벌어져도 된다.
        // 진한 띠 = 기준 폭, 옅은 띠 = 손가락이 벗어나도 허용되는 폭.
        let core = max(10, (edge.isVertical ? size.width : size.height) * edgeWidth)
        let halo = max(core + 6, (edge.isVertical ? size.width : size.height)
                       * (edgeWidth + EdgeSliderRecognizer.fingerSpread))
        return Group {
            switch edge {
            case .right:
                Rectangle().fill(theme.accentColor.opacity(0.07))
                    .frame(width: halo)
                    .position(x: size.width - halo / 2, y: size.height / 2)
                Rectangle().fill(theme.accentColor.opacity(0.16))
                    .frame(width: core)
                    .position(x: size.width - core / 2, y: size.height / 2)
            case .left:
                Rectangle().fill(theme.accentColor.opacity(0.07))
                    .frame(width: halo)
                    .position(x: halo / 2, y: size.height / 2)
                Rectangle().fill(theme.accentColor.opacity(0.16))
                    .frame(width: core)
                    .position(x: core / 2, y: size.height / 2)
            case .top:
                Rectangle().fill(theme.accentColor.opacity(0.07))
                    .frame(height: halo)
                    .position(x: size.width / 2, y: halo / 2)
                Rectangle().fill(theme.accentColor.opacity(0.16))
                    .frame(height: core)
                    .position(x: size.width / 2, y: core / 2)
            case .bottom:
                Rectangle().fill(theme.accentColor.opacity(0.07))
                    .frame(height: halo)
                    .position(x: size.width / 2, y: size.height - halo / 2)
                Rectangle().fill(theme.accentColor.opacity(0.16))
                    .frame(height: core)
                    .position(x: size.width / 2, y: size.height - core / 2)
            }
        }
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("trackpad.permission.title".localized)
                    .font(.headline)
                Text("trackpad.permission.none_extra".localized)
                    .font(.caption2)
                    .foregroundColor(theme.secondaryText)
            }

            HStack(spacing: 9) {
                Image(systemName: PermissionHelper.isAccessibilityTrusted ? "checkmark" : "exclamationmark")
                    .font(.caption)
                    .foregroundColor(PermissionHelper.isAccessibilityTrusted ? theme.successColor : theme.errorColor)
                VStack(alignment: .leading, spacing: 1) {
                    Text("trackpad.permission.ax".localized)
                        .font(.caption)
                    Text(PermissionHelper.isAccessibilityTrusted
                         ? "trackpad.permission.ax.granted".localized
                         : "trackpad.permission.ax.needed".localized)
                        .font(.caption2)
                        .foregroundColor(theme.secondaryText)
                }
                Spacer()
                if PermissionHelper.isAccessibilityTrusted {
                    Text("trackpad.permission.allowed".localized)
                        .font(.caption2)
                        .foregroundColor(theme.successColor)
                } else {
                    Button("trackpad.permission.need".localized) {
                        PermissionHelper.requestAccessibility()
                    }
                    .controlSize(.mini)
                }
            }

            HStack(spacing: 9) {
                Image(systemName: "minus")
                    .font(.caption)
                    .foregroundColor(theme.tertiaryText)
                VStack(alignment: .leading, spacing: 1) {
                    Text("trackpad.permission.input".localized)
                        .font(.caption)
                    Text("trackpad.permission.input.desc".localized)
                        .font(.caption2)
                        .foregroundColor(theme.secondaryText)
                }
                Spacer()
                Text("trackpad.permission.unnecessary".localized)
                    .font(.caption2)
                    .foregroundColor(theme.tertiaryText)
            }
            .opacity(0.6)

            Text("trackpad.permission.note".localized)
                .font(.caption2)
                .foregroundColor(theme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(theme.cardBorder, lineWidth: 1)
        )
    }

    // MARK: - 에지 슬라이더

    private var sliderSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                title: "trackpad.sliders.title".localized,
                description: "trackpad.sliders.desc".localized
            ) {
                Button("trackpad.sliders.add".localized) {
                    activeSheet = .slider(EdgeSliderRule(), isEditing: false)
                }
                .controlSize(.small)
            }

            if store.trackpadSliders.isEmpty {
                emptyRow(text: "trackpad.sliders.empty".localized) {
                    Button("trackpad.sliders.create_default".localized) {
                        store.createDefaultTrackpadSlider()
                    }
                    .controlSize(.small)
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(store.trackpadSliders) { rule in
                        sliderRow(rule)
                        if rule.id != store.trackpadSliders.last?.id {
                            Divider().padding(.leading, 34)
                        }
                    }
                }
            }
        }
        .padding(13)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(theme.cardBorder, lineWidth: 1)
        )
    }

    private func sliderRow(_ rule: EdgeSliderRule) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "slider.vertical.3")
                .foregroundColor(rule.enabled ? theme.accentColor : theme.tertiaryText)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(rule.gestureSummary)
                    .font(.body)
                    .foregroundColor(rule.enabled ? theme.primaryText : theme.secondaryText)
                Text(rule.targetSummary)
                    .font(.caption2)
                    .foregroundColor(theme.secondaryText)
            }
            Spacer()
            Button("trackpad.edit".localized) {
                activeSheet = .slider(rule, isEditing: true)
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundColor(theme.secondaryText)
            Toggle("", isOn: Binding(
                get: { store.trackpadSliders.first(where: { $0.id == rule.id })?.enabled ?? rule.enabled },
                set: { enabled in
                    guard var latest = store.trackpadSliders.first(where: { $0.id == rule.id }) else { return }
                    latest.enabled = enabled
                    store.upsertTrackpadSlider(latest)
                    TrackpadEngine.shared.refreshRules()
                }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.mini)
        }
        .padding(.vertical, 7)
    }

    // MARK: - 제스처

    private var gestureSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                title: "trackpad.gestures.title".localized,
                description: "trackpad.gestures.desc".localized
            ) {
                Button("trackpad.gestures.add".localized) {
                    activeSheet = .gesture(GestureRule(), isEditing: false)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            if store.trackpadGestures.isEmpty {
                Text("trackpad.gestures.empty".localized)
                    .font(.caption)
                    .foregroundColor(theme.secondaryText)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 0) {
                    ForEach(store.trackpadGestures) { rule in
                        gestureRow(rule)
                        if rule.id != store.trackpadGestures.last?.id {
                            Divider().padding(.leading, 34)
                        }
                    }
                }
            }
        }
        .padding(13)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(theme.cardBorder, lineWidth: 1)
        )
    }

    private func gestureRow(_ rule: GestureRule) -> some View {
        HStack(spacing: 10) {
            Image(systemName: rule.kind == .tap ? "hand.tap" : "hand.draw")
                .foregroundColor(rule.enabled ? theme.accentColor : theme.tertiaryText)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(rule.gestureSummary)
                    .font(.body)
                    .foregroundColor(rule.enabled ? theme.primaryText : theme.secondaryText)
                Text(rule.actionSummary { store.trackpadActionName($0) })
                    .font(.caption2)
                    .foregroundColor(theme.secondaryText)
                    .lineLimit(1)
            }
            Spacer()
            Text(rule.scopeSummary)
                .font(.caption2)
                .foregroundColor(theme.secondaryText)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(theme.tertiaryBackground)
                .clipShape(Capsule())
            Button("trackpad.edit".localized) {
                activeSheet = .gesture(rule, isEditing: true)
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundColor(theme.secondaryText)
            Toggle("", isOn: Binding(
                get: { store.trackpadGestures.first(where: { $0.id == rule.id })?.enabled ?? rule.enabled },
                set: { enabled in
                    guard var latest = store.trackpadGestures.first(where: { $0.id == rule.id }) else { return }
                    latest.enabled = enabled
                    store.upsertTrackpadGesture(latest)
                }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.mini)
        }
        .padding(.vertical, 7)
    }

    // MARK: - 고급

    private var advancedSection: some View {
        let reference = store.trackpadSliders.first ?? EdgeSliderRule()
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("trackpad.advanced.title".localized)
                        .font(.headline)
                    Text("trackpad.advanced.desc".localized)
                        .font(.caption2)
                        .foregroundColor(theme.secondaryText)
                }
                Spacer()
                if advancedExpanded {
                    Button("trackpad.advanced.reset".localized) {
                        resetAdvanced()
                    }
                    .controlSize(.small)
                }
                Button(advancedExpanded
                       ? "trackpad.advanced.collapse".localized
                       : "trackpad.advanced.expand".localized) {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        advancedExpanded.toggle()
                    }
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
            }

            if advancedExpanded {
                VStack(spacing: 0) {
                    advancedRow(
                        title: "trackpad.advanced.edge_width".localized,
                        detail: "trackpad.advanced.edge_width.desc".localizedFormat(TrackpadFormatting.percent(reference.edgeWidth)),
                        value: TrackpadFormatting.percent(reference.edgeWidth)
                    )
                    Divider()
                    advancedRow(
                        title: "trackpad.advanced.threshold".localized,
                        detail: "trackpad.advanced.threshold.desc".localizedFormat(TrackpadFormatting.percent(reference.startThreshold)),
                        value: TrackpadFormatting.percent(reference.startThreshold)
                    )
                    Divider()
                    advancedRow(
                        title: "trackpad.advanced.cooldown".localized,
                        detail: "trackpad.advanced.cooldown.desc".localized,
                        value: TrackpadFormatting.milliseconds(reference.cooldown)
                    )
                    Divider()
                    advancedRow(
                        title: "trackpad.advanced.thumb".localized,
                        detail: "trackpad.advanced.thumb.desc".localized,
                        value: reference.ignoreThumb
                            ? "trackpad.advanced.on".localized
                            : "trackpad.advanced.off".localized
                    )
                }
            }
        }
        .padding(13)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(theme.cardBorder, lineWidth: 1)
        )
    }

    private func advancedRow(title: String, detail: String, value: String) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.caption)
                Text(detail)
                    .font(.caption2)
                    .foregroundColor(theme.secondaryText)
            }
            Spacer()
            Text(value)
                .font(.caption2)
                .monospacedDigit()
                .foregroundColor(theme.secondaryText)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(theme.tertiaryBackground)
                .clipShape(Capsule())
        }
        .padding(.vertical, 7)
    }

    private func resetAdvanced() {
        let defaults = EdgeSliderRule()
        for rule in store.trackpadSliders {
            var updated = rule
            updated.edgeWidth = defaults.edgeWidth
            updated.startThreshold = defaults.startThreshold
            updated.cooldown = defaults.cooldown
            updated.ignoreThumb = true
            updated.suppressScroll = true
            store.upsertTrackpadSlider(updated)
        }
        TrackpadEngine.shared.refreshRules()
    }

    // MARK: - 공통 조각

    private func sectionHeader<Accessory: View>(
        title: String,
        description: String,
        @ViewBuilder accessory: () -> Accessory
    ) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(description)
                    .font(.caption2)
                    .foregroundColor(theme.secondaryText)
            }
            Spacer()
            accessory()
        }
    }

    private func emptyRow<Accessory: View>(
        text: String,
        @ViewBuilder action: () -> Accessory
    ) -> some View {
        HStack(spacing: 8) {
            Text(text)
                .font(.caption)
                .foregroundColor(theme.secondaryText)
            Spacer()
            action()
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func sheetContent(_ sheet: TrackpadEditorSheet) -> some View {
        switch sheet {
        case .chooser:
            TrackpadChooserSheet { choice in
                activeSheet = nil
                // 시트 전환 애니메이션이 끝난 뒤 다음 시트를 올린다.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                    switch choice {
                    case .slider:
                        activeSheet = .slider(EdgeSliderRule(), isEditing: false)
                    case .gesture:
                        activeSheet = .gesture(GestureRule(), isEditing: false)
                    }
                }
            }
        case .slider(let rule, let isEditing):
            TrackpadSliderSheet(rule: rule, isEditing: isEditing)
        case .gesture(let rule, let isEditing):
            TrackpadGestureSheet(rule: rule, isEditing: isEditing)
        }
    }
}

// MARK: - 시트 종류

enum TrackpadEditorSheet: Identifiable {
    case chooser
    case slider(EdgeSliderRule, isEditing: Bool)
    case gesture(GestureRule, isEditing: Bool)

    var id: String {
        switch self {
        case .chooser: return "chooser"
        case .slider(let rule, _): return "slider-\(rule.id.uuidString)"
        case .gesture(let rule, _): return "gesture-\(rule.id.uuidString)"
        }
    }
}
