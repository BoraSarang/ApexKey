import AppKit

/// 볼륨 HUD — 값이 바뀌는 **에지 옆**에 잠깐 떠오르는 작은 패널.
///
/// 포커스를 뺏지 않도록 `nonactivatingPanel` + `ignoresMouseEvents`로 띄우고,
/// 0.8초 뒤 스스로 사라진다(기존 토스트와 동일한 결).
///
/// 세로 에지(좌/우)에서는 **세로 막대**로, 가로 에지(위/아래)에서는 가로 막대로
/// 표시한다 — 손이 가 있는 곳과 표시가 같은 방향이어야 "슬라이더"로 읽힌다.
@MainActor
final class TrackpadHUD {
    private var panel: NSPanel?
    private var bar: HUDBar?
    private var iconView: NSImageView?
    private var directionView: NSImageView?
    private var valueLabel: NSTextField?
    private var hideTimer: Timer?
    private var lastValue: Float?
    private var lastTarget: SliderTarget?
    private var layout: Layout?

    private enum Layout: Equatable {
        case horizontal
        case vertical
    }

    private static let longSide: CGFloat = 214
    private static let shortSide: CGFloat = 54
    private static let edgeInset: CGFloat = 24

    /// - Parameter edge: 슬라이더가 붙은 에지. nil이면 화면 하단 중앙(테스트 버튼).
    func show(_ value: Float, target: SliderTarget, edge: TrackpadEdge? = nil) {
        let clamped = min(max(value, 0), 1)
        let vertical = edge?.isVertical ?? false
        ensurePanel(vertical: vertical)

        // 대상이 바뀌면 방향 화살표를 이전 값과 비교하지 않는다
        if lastTarget != target {
            lastValue = nil
            lastTarget = target
        }

        bar?.value = clamped
        valueLabel?.stringValue = "\(Int((clamped * 100).rounded()))%"
        iconView?.image = NSImage(
            systemSymbolName: Self.iconName(for: clamped, target: target),
            accessibilityDescription: nil
        )
        // 방향 표시 — 위/아래 어느 쪽으로 움직였는지 즉시 보이게 한다.
        let direction: Int
        if let lastValue, abs(clamped - lastValue) > 0.001 {
            direction = clamped > lastValue ? 1 : -1
        } else {
            direction = 0
        }
        self.lastValue = clamped
        directionView?.image = direction == 0 ? nil : NSImage(
            systemSymbolName: direction > 0 ? "chevron.up" : "chevron.down",
            accessibilityDescription: nil
        )
        directionView?.isHidden = direction == 0
        positionPanel(edge: edge, vertical: vertical)
        panel?.alphaValue = 1
        panel?.orderFront(nil)

        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.fadeOut()
            }
        }
    }

    func hide() {
        hideTimer?.invalidate()
        hideTimer = nil
        lastValue = nil
        lastTarget = nil
        panel?.orderOut(nil)
    }

    // MARK: - 내부

    private func fadeOut() {
        guard let panel else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            panel.animator().alphaValue = 0
        } completionHandler: {
            MainActor.assumeIsolated {
                panel.orderOut(nil)
                panel.alphaValue = 1
            }
        }
    }

    private func ensurePanel(vertical: Bool) {
        let wanted: Layout = vertical ? .vertical : .horizontal
        if panel != nil, layout == wanted { return }
        panel?.orderOut(nil)
        panel = nil

        let size = vertical
            ? NSSize(width: Self.shortSide, height: Self.longSide)
            : NSSize(width: Self.longSide, height: Self.shortSide)
        let win = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        win.isFloatingPanel = true
        win.level = .statusBar
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = true
        win.ignoresMouseEvents = true
        win.hidesOnDeactivate = false
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]

        let effect = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 14
        effect.layer?.masksToBounds = true

        let icon = NSImageView()
        icon.contentTintColor = .labelColor
        icon.imageScaling = .scaleProportionallyUpOrDown

        let bar = HUDBar(vertical: vertical)
        let direction = NSImageView()
        direction.contentTintColor = .secondaryLabelColor
        direction.imageScaling = .scaleProportionallyDown
        direction.isHidden = true

        let label = NSTextField(labelWithString: "0%")
        label.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        label.textColor = .secondaryLabelColor
        label.alignment = .center

        if vertical {
            icon.frame = NSRect(x: 17, y: size.height - 38, width: 20, height: 20)
            bar.frame = NSRect(x: 24, y: 54, width: 6, height: 104)
            direction.frame = NSRect(x: 20, y: 34, width: 14, height: 16)
            label.frame = NSRect(x: 8, y: 14, width: size.width - 16, height: 18)
        } else {
            icon.frame = NSRect(x: 16, y: 17, width: 20, height: 20)
            bar.frame = NSRect(x: 46, y: 24, width: 104, height: 6)
            direction.frame = NSRect(x: 152, y: 17, width: 14, height: 20)
            label.frame = NSRect(x: 168, y: 17, width: 34, height: 20)
            label.alignment = .right
        }

        effect.addSubview(icon)
        effect.addSubview(bar)
        effect.addSubview(direction)
        effect.addSubview(label)

        win.contentView = effect
        panel = win
        self.bar = bar
        self.iconView = icon
        self.directionView = direction
        self.valueLabel = label
        self.layout = wanted
    }

    private func positionPanel(edge: TrackpadEdge?, vertical: Bool) {
        guard let panel else { return }
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let visible = screen?.visibleFrame else { return }
        let size = panel.frame.size
        let origin: NSPoint

        switch edge {
        case .right:
            origin = NSPoint(
                x: visible.maxX - size.width - Self.edgeInset,
                y: visible.midY - size.height / 2
            )
        case .left:
            origin = NSPoint(
                x: visible.minX + Self.edgeInset,
                y: visible.midY - size.height / 2
            )
        case .top:
            origin = NSPoint(
                x: visible.midX - size.width / 2,
                y: visible.maxY - size.height - Self.edgeInset
            )
        case .bottom, .none:
            origin = NSPoint(
                x: visible.midX - size.width / 2,
                y: visible.minY + 96
            )
        }
        panel.setFrameOrigin(NSPoint(x: origin.x.rounded(), y: origin.y.rounded()))
    }

    private static func iconName(for value: Float, target: SliderTarget) -> String {
        switch target {
        case .brightness:
            return value < 0.34 ? "sun.min.fill" : "sun.max.fill"
        case .volume, .shortcut:
            switch value {
            case 0: return "speaker.slash.fill"
            case ..<0.34: return "speaker.wave.1.fill"
            case ..<0.67: return "speaker.wave.2.fill"
            default: return "speaker.wave.3.fill"
            }
        }
    }
}

/// HUD 안의 막대 — 값에 따라 채워진다. 세로/가로 모두 지원한다.
private final class HUDBar: NSView {
    private let vertical: Bool

    var value: Float = 0 {
        didSet { needsDisplay = true }
    }

    init(vertical: Bool) {
        self.vertical = vertical
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ dirtyRect: NSRect) {
        let radius = (vertical ? bounds.width : bounds.height) / 2
        NSColor.labelColor.withAlphaComponent(0.22).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius).fill()

        let clamped = CGFloat(min(max(value, 0), 1))
        let filled: NSRect
        if vertical {
            let height = max(bounds.width, bounds.height * clamped)
            filled = NSRect(x: 0, y: 0, width: bounds.width, height: height)
        } else {
            let width = max(bounds.height, bounds.width * clamped)
            filled = NSRect(x: 0, y: 0, width: width, height: bounds.height)
        }
        NSColor.labelColor.setFill()
        NSBezierPath(roundedRect: filled, xRadius: radius, yRadius: radius).fill()
    }
}
