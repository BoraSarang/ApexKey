import SwiftUI

/// Shared background layer that renders solid, gradient, or image backgrounds
/// from the active theme config. Mirrors the osaurus ThemedBackgroundLayer.
struct ThemedBackgroundLayer: View {
    let showSidebar: Bool
    var isFullScreen: Bool = false

    @Environment(\.theme) private var theme

    var body: some View {
        backgroundLayer
            .clipShape(backgroundShape)
    }

    private var backgroundShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: (showSidebar || isFullScreen) ? 0 : 24,
            bottomLeadingRadius: (showSidebar || isFullScreen) ? 0 : 24,
            bottomTrailingRadius: isFullScreen ? 0 : 24,
            topTrailingRadius: isFullScreen ? 0 : 24,
            style: .continuous
        )
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        if let customTheme = theme.customThemeConfig {
            switch customTheme.background.type {
            case .solid:
                Color(themeHex: customTheme.background.solidColor ?? customTheme.colors.primaryBackground)

            case .gradient:
                let colors = (customTheme.background.gradientColors ?? ["#000000", "#333333"])
                    .map { Color(themeHex: $0) }
                LinearGradient(
                    colors: colors,
                    startPoint: .top,
                    endPoint: .bottom
                )

            case .image:
                if let image = customTheme.background.decodedImage() {
                    ZStack {
                        imageView(
                            image: image,
                            fit: customTheme.background.imageFit ?? .fill,
                            opacity: customTheme.background.imageOpacity ?? 1.0
                        )

                        if let overlayHex = customTheme.background.overlayColor {
                            Color(themeHex: overlayHex)
                                .opacity(customTheme.background.overlayOpacity ?? 0.5)
                        }
                    }
                } else {
                    Color(themeHex: customTheme.colors.primaryBackground)
                }
            }
        } else {
            theme.primaryBackground
        }
    }

    @ViewBuilder
    private func imageView(image: NSImage, fit: ThemeBackground.ImageFit, opacity: Double) -> some View {
        GeometryReader { geo in
            switch fit {
            case .fill:
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .opacity(opacity)
            case .fit:
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .opacity(opacity)
            case .stretch:
                Image(nsImage: image)
                    .resizable()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .opacity(opacity)
            case .tile:
                TiledImageView(image: image)
                    .opacity(opacity)
            }
        }
    }

    private struct TiledImageView: NSViewRepresentable {
        let image: NSImage

        func makeNSView(context: Context) -> NSView {
            let view = NSView()
            view.wantsLayer = true
            return view
        }

        func updateNSView(_ nsView: NSView, context: Context) {
            nsView.layer?.backgroundColor = NSColor(patternImage: image).cgColor
        }
    }
}
