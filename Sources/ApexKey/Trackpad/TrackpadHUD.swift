import AppKit

/// 볼륨 HUD — 화면 하단 중앙에 잠깐 떠오르는 작은 패널.
///
/// 포커스를 뺏지 않도록 `nonactivatingPanel` + `ignoresMouseEvents`로 띄우고,
/// 0.8초 뒤 스스로 사라진다(기존 토스트와 동일한 결).
@MainActor
final class TrackpadHUD {
    private var panel: NSPanel?
    private var bar: HUDVolumeBar?
    private var iconView: NSImageView?
    private var directionView: NSImageView?
    private var valueLabel: NSTextField?
    private var hideTimer: Timer?
    private var lastValue: Float?

    private static let size = NSSize(width: 214, height: 54)

    func showVolume(_ value: Float) {
        let clamped = min(max(value, 0), 1)
        ensurePanel()
        bar?.value = clamped
        valueLabel?.stringValue = "\(Int((clamped * 100).rounded()))%"
        iconView?.image = NSImage(
            systemSymbolName: Self.iconName(for: clamped),
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
        positionPanel()
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

    private func ensurePanel() {
        guard panel == nil else { return }
        let win = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.size),
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

        let effect = NSVisualEffectView(frame: NSRect(origin: .zero, size: Self.size))
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 14
        effect.layer?.masksToBounds = true

        let icon = NSImageView(frame: NSRect(x: 16, y: 17, width: 20, height: 20))
        icon.contentTintColor = .labelColor
        icon.imageScaling = .scaleProportionallyUpOrDown
        effect.addSubview(icon)

        let bar = HUDVolumeBar(frame: NSRect(x: 46, y: 24, width: 104, height: 6))
        effect.addSubview(bar)

        let direction = NSImageView(frame: NSRect(x: 152, y: 17, width: 14, height: 20))
        direction.contentTintColor = .secondaryLabelColor
        direction.imageScaling = .scaleProportionallyDown
        direction.isHidden = true
        effect.addSubview(direction)

        let label = NSTextField(labelWithString: "0%")
        label.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        label.textColor = .secondaryLabelColor
        label.alignment = .right
        label.frame = NSRect(x: 168, y: 17, width: 34, height: 20)
        effect.addSubview(label)

        win.contentView = effect
        panel = win
        self.bar = bar
        self.iconView = icon
        self.directionView = direction
        self.valueLabel = label
    }

    private func positionPanel() {
        guard let panel else { return }
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let visible = screen?.visibleFrame else { return }
        let x = visible.midX - Self.size.width / 2
        let y = visible.minY + 96
        panel.setFrameOrigin(NSPoint(x: x.rounded(), y: y.rounded()))
    }

    private static func iconName(for value: Float) -> String {
        switch value {
        case 0: return "speaker.slash.fill"
        case ..<0.34: return "speaker.wave.1.fill"
        case ..<0.67: return "speaker.wave.2.fill"
        default: return "speaker.wave.3.fill"
        }
    }
}

/// HUD 안의 가로 막대 — 값에 따라 채워진다.
private final class HUDVolumeBar: NSView {
    var value: Float = 0 {
        didSet { needsDisplay = true }
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let radius = bounds.height / 2
        NSColor.labelColor.withAlphaComponent(0.22).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius).fill()

        let width = max(bounds.height, bounds.width * CGFloat(min(max(value, 0), 1)))
        let filled = NSRect(x: 0, y: 0, width: width, height: bounds.height)
        NSColor.labelColor.setFill()
        NSBezierPath(roundedRect: filled, xRadius: radius, yRadius: radius).fill()
    }
}
