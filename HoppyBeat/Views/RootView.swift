import SwiftUI

struct RootView: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let pal = scheme == .dark ? Palette.night : Palette.day
        GeometryReader { geo in
            let size = geo.size
            let wide = size.width > size.height * 1.05
            let s = Self.scale(for: size, wide: wide)
            Group {
                if wide {
                    HStack(spacing: 14 * s) {
                        PondStage()
                        // Only scroll the settings when they don't fit. The play row always stays
                        // outside the scroll view: scroll views delay touch-down, which would make
                        // every on-beat clap score as late.
                        ViewThatFits(in: .vertical) {
                            ControlsPanel()
                            VStack(spacing: 10 * s) {
                                ScrollView(.vertical) {
                                    SettingsCards()
                                }
                                .scrollIndicators(.hidden)
                                PlayRow()
                            }
                        }
                        .frame(width: min(size.width * 0.44, 470 * s))
                    }
                } else {
                    VStack(spacing: 12 * s) {
                        PondStage()
                        ControlsPanel()
                            .frame(maxWidth: 680 * s)
                    }
                }
            }
            .padding(12 * s)
            .frame(width: size.width, height: size.height)
            .overlay { CelebrationOverlay() }
            .environment(\.uiScale, s)
        }
        .background(pal.background.ignoresSafeArea())
        .environment(\.palette, pal)
        .statusBarHidden()
    }

    /// Everything is designed at iPhone size and scaled up for iPad.
    static func scale(for size: CGSize, wide: Bool) -> CGFloat {
        if wide {
            return min(size.height / 440, size.width / 900).clamped(to: 0.72...1.5)
        }
        return min(size.width / 400, size.height / 820).clamped(to: 0.78...1.6)
    }
}
