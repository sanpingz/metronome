import SwiftUI

/// Hoppy, drawn entirely from shapes so it scales crisply to any screen.
/// The view is `size × size`; the feet sit near the bottom edge.
struct FrogView: View {
    var size: CGFloat
    var eyesClosed = false
    var mouthOpen: Double = 0
    var look: CGFloat = 0
    var hat: String?

    static let skin = Color(hex: 0x6CD04A)
    static let skinLight = Color(hex: 0xA6EC7A)
    static let skinDark = Color(hex: 0x46A635)
    static let belly = Color(hex: 0xE4FBB4)
    static let blush = Color(hex: 0xFF8FB1)
    static let line = Color(hex: 0x24521B)

    var body: some View {
        let s = size
        ZStack {
            Ellipse().fill(Self.skinDark)
                .frame(width: s * 0.38, height: s * 0.26)
                .offset(x: -s * 0.33, y: s * 0.3)
            Ellipse().fill(Self.skinDark)
                .frame(width: s * 0.38, height: s * 0.26)
                .offset(x: s * 0.33, y: s * 0.3)

            Ellipse()
                .fill(LinearGradient(colors: [Self.skinLight, Self.skin], startPoint: .top, endPoint: .bottom))
                .frame(width: s * 0.9, height: s * 0.64)
                .offset(y: s * 0.12)
            Ellipse().fill(Self.belly)
                .frame(width: s * 0.5, height: s * 0.32)
                .offset(y: s * 0.25)

            HStack(spacing: s * 0.12) {
                foot
                foot
            }
            .offset(y: s * 0.43)

            eye.offset(x: -s * 0.22, y: -s * 0.19)
            eye.offset(x: s * 0.22, y: -s * 0.19)

            Circle().fill(Self.blush.opacity(0.65))
                .frame(width: s * 0.13)
                .offset(x: -s * 0.3, y: s * 0.1)
            Circle().fill(Self.blush.opacity(0.65))
                .frame(width: s * 0.13)
                .offset(x: s * 0.3, y: s * 0.1)

            mouth.offset(y: s * 0.09)

            if let hat {
                Text(hat)
                    .font(.system(size: s * 0.3))
                    .offset(y: -s * 0.33)
            }
        }
        .frame(width: s, height: s)
    }

    private var foot: some View {
        Capsule().fill(Self.skinDark)
            .frame(width: size * 0.2, height: size * 0.1)
    }

    private var eye: some View {
        let s = size
        return ZStack {
            Circle().fill(Self.skin)
                .frame(width: s * 0.36)
            if eyesClosed {
                SmileShape()
                    .stroke(Self.line, style: StrokeStyle(lineWidth: s * 0.035, lineCap: .round))
                    .frame(width: s * 0.18, height: s * 0.05)
            } else {
                Circle().fill(.white)
                    .frame(width: s * 0.27)
                Circle().fill(Color(hex: 0x1D1D1D))
                    .frame(width: s * 0.14)
                    .offset(x: look * s * 0.05, y: s * 0.015)
                Circle().fill(.white)
                    .frame(width: s * 0.05)
                    .offset(x: look * s * 0.05 - s * 0.025, y: -s * 0.02)
            }
        }
    }

    @ViewBuilder private var mouth: some View {
        let s = size
        if mouthOpen > 0.05 {
            Ellipse().fill(Color(hex: 0xB0304A))
                .frame(width: s * 0.3, height: s * (0.05 + 0.16 * mouthOpen))
                .overlay(alignment: .bottom) {
                    Ellipse().fill(Color(hex: 0xFF7A93))
                        .frame(width: s * 0.16, height: s * 0.07 * mouthOpen)
                }
        } else {
            SmileShape()
                .stroke(Self.line, style: StrokeStyle(lineWidth: s * 0.035, lineCap: .round))
                .frame(width: s * 0.36, height: s * 0.07)
        }
    }
}
