import SwiftUI
import QuartzCore

/// Confetti burst plus a big banner for milestones (new hats, every 10 stars, long streaks).
struct CelebrationOverlay: View {
    @Environment(BeatModel.self) private var model
    @Environment(\.uiScale) private var s

    private static let duration = 2.8
    private static let colors: [Color] = [
        Color(hex: 0xFF6B6B), Color(hex: 0xFFC93C), Color(hex: 0x5CC94A),
        Color(hex: 0x3BB8F0), Color(hex: 0x8E7CFF), Color(hex: 0xFF8FC7),
    ]

    var body: some View {
        if let c = model.celebration, CACurrentMediaTime() - c.time < Self.duration {
            TimelineView(.animation) { _ in
                let e = CACurrentMediaTime() - c.time
                if e < Self.duration {
                    ZStack {
                        Canvas { ctx, size in
                            drawConfetti(ctx, size: size, elapsed: e, seed: c.seed)
                        }
                        banner(c, elapsed: e)
                    }
                }
            }
            .allowsHitTesting(false)
            .ignoresSafeArea()
            .id(c.time)
        }
    }

    private func banner(_ c: Celebration, elapsed e: Double) -> some View {
        let appear = min(1, e / 0.35)
        let overshoot = 1 + 0.25 * sin(appear * .pi)
        let fade = e > Self.duration - 0.4 ? (Self.duration - e) / 0.4 : 1
        return VStack(spacing: 4 * s) {
            Text(c.emoji)
                .font(.system(size: 70 * s))
                .rotationEffect(.degrees(sin(e * 6) * 8))
            Text(c.title)
                .font(.kid(34 * s))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 30 * s)
        .padding(.vertical, 18 * s)
        .background(
            RoundedRectangle(cornerRadius: 32 * s, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0xFF9F1C), Color(hex: 0xFF5A8A)], startPoint: .top, endPoint: .bottom))
                .shadow(color: .black.opacity(0.25), radius: 12 * s, y: 6 * s))
        .scaleEffect(appear * overshoot)
        .opacity(fade)
    }

    private func drawConfetti(_ ctx: GraphicsContext, size: CGSize, elapsed e: Double, seed: Int) {
        let gravity = Double(size.height) * 1.5
        for i in 0..<110 {
            let k = i + seed
            let startX = Double(size.width) * (0.2 + 0.6 * hash01(k, 1))
            let vx = (hash01(k, 2) - 0.5) * Double(size.width) * 1.1
            let vy = -(0.9 + 0.8 * hash01(k, 3)) * Double(size.height)
            let delay = hash01(k, 4) * 0.25
            let t = e - delay
            guard t > 0 else { continue }
            let x = startX + vx * t
            let y = Double(size.height) + vy * t + 0.5 * gravity * t * t
            let spin = (hash01(k, 5) - 0.5) * 18 * t
            let w = (7 + 6 * hash01(k, 6)) * Double(s)
            var piece = ctx
            piece.translateBy(x: x, y: y)
            piece.rotate(by: .radians(spin))
            piece.scaleBy(x: cos(t * (4 + 6 * hash01(k, 7))), y: 1)
            let rect = CGRect(x: -w / 2, y: -w * 0.3, width: w, height: w * 0.6)
            let color = Self.colors[k % Self.colors.count]
            piece.fill(i % 3 == 0 ? Path(ellipseIn: rect) : Path(rect), with: .color(color))
        }
    }
}
