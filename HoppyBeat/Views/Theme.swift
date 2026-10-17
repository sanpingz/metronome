import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

/// Day pond in light mode, a firefly night pond in dark mode.
struct Palette {
    var isNight: Bool
    var background: Color
    var card: Color
    var ink: Color
    var softInk: Color
    var skyTop: Color
    var skyBottom: Color
    var hillBack: Color
    var hillFront: Color
    var waterTop: Color
    var waterBottom: Color
    var padLight: Color
    var pad: Color
    var padDark: Color
    var glow: Color
    var buttonFill: Color
    var selection: Color

    static let day = Palette(
        isNight: false,
        background: Color(hex: 0xFFF4DA),
        card: .white,
        ink: Color(hex: 0x3B2F2F),
        softInk: Color(hex: 0x8A7B6B),
        skyTop: Color(hex: 0x6FCBFF),
        skyBottom: Color(hex: 0xD6F3FF),
        hillBack: Color(hex: 0xA3E07F),
        hillFront: Color(hex: 0x74C856),
        waterTop: Color(hex: 0x5CCBF5),
        waterBottom: Color(hex: 0x2389DD),
        padLight: Color(hex: 0x8BDB6A),
        pad: Color(hex: 0x5DBB4A),
        padDark: Color(hex: 0x3E8E33),
        glow: Color(hex: 0xFFE14D),
        buttonFill: Color(hex: 0xFFF3D1),
        selection: Color(hex: 0xFFD84A))

    static let night = Palette(
        isNight: true,
        background: Color(hex: 0x14163A),
        card: Color(hex: 0x23275A),
        ink: Color(hex: 0xF4F1FF),
        softInk: Color(hex: 0xA9A6D6),
        skyTop: Color(hex: 0x0B0E2E),
        skyBottom: Color(hex: 0x30347E),
        hillBack: Color(hex: 0x264F6E),
        hillFront: Color(hex: 0x1D6450),
        waterTop: Color(hex: 0x235A9A),
        waterBottom: Color(hex: 0x0D2350),
        padLight: Color(hex: 0x5CC27A),
        pad: Color(hex: 0x3F9E5A),
        padDark: Color(hex: 0x2A6B3D),
        glow: Color(hex: 0xFFF59D),
        buttonFill: Color(hex: 0x2F3473),
        selection: Color(hex: 0xFFC93C))
}

private struct PaletteKey: EnvironmentKey {
    static let defaultValue = Palette.day
}

private struct UIScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1
}

extension EnvironmentValues {
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }

    /// One number that grows every size in the UI from iPhone to iPad.
    var uiScale: CGFloat {
        get { self[UIScaleKey.self] }
        set { self[UIScaleKey.self] = newValue }
    }
}

extension Font {
    static func kid(_ size: CGFloat, _ weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

struct BouncyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.5), value: configuration.isPressed)
    }
}

struct Card<Content: View>: View {
    @Environment(\.palette) private var pal
    @Environment(\.uiScale) private var s
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(.horizontal, 12 * s)
            .padding(.vertical, 10 * s)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 24 * s, style: .continuous)
                    .fill(pal.card)
                    .shadow(color: .black.opacity(pal.isNight ? 0.35 : 0.08), radius: 8 * s, y: 4 * s))
    }
}

/// A curve that dips in the middle — smiles, closed eyes, waves.
struct SmileShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY),
                       control: CGPoint(x: r.midX, y: r.maxY + r.height))
        return p
    }
}

/// Cheap deterministic pseudo-random numbers for scenery and confetti.
func hash01(_ i: Int, _ salt: Int) -> Double {
    let x = sin(Double(i) * 127.1 + Double(salt) * 311.7) * 43_758.5453
    return x - floor(x)
}
