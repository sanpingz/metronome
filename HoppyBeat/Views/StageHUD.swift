import SwiftUI

/// Star counter and hat wardrobe floating over the pond.
struct StageHUD: View {
    @Environment(BeatModel.self) private var model
    @Environment(\.palette) private var pal
    @Environment(\.uiScale) private var s

    var body: some View {
        HStack(alignment: .top) {
            starBadge
            Spacer()
            hatButton
        }
    }

    private var starBadge: some View {
        HStack(spacing: 6 * s) {
            Text("⭐️")
                .font(.system(size: 20 * s))
            Text("\(model.stars)")
                .font(.kid(20 * s))
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(model.stars)))
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: model.stars)
            if model.streak >= 3 {
                Text("🔥\(model.streak)")
                    .font(.kid(16 * s))
                    .foregroundStyle(Color(hex: 0xFF6B1A))
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .foregroundStyle(pal.ink)
        .padding(.horizontal, 12 * s)
        .padding(.vertical, 6 * s)
        .background(Capsule().fill(pal.card.opacity(0.88)))
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: model.streak >= 3)
        .keyframeAnimator(initialValue: 1.0, trigger: model.stars) { content, scale in
            content.scaleEffect(scale)
        } keyframes: { _ in
            SpringKeyframe(1.25, duration: 0.1)
            SpringKeyframe(1.0, duration: 0.35)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(model.stars) stars")
    }

    private var hatButton: some View {
        let unlocked = Hat.unlocked(stars: model.stars)
        let next = Hat.next(after: model.stars)
        return Button(action: model.cycleHat) {
            HStack(spacing: 4 * s) {
                if unlocked.count > 1 {
                    Text(model.hat.emoji ?? "🐸")
                        .font(.system(size: 22 * s))
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 12 * s, weight: .bold))
                        .foregroundStyle(pal.softInk)
                }
                if let next, let emoji = next.emoji {
                    HStack(spacing: 2 * s) {
                        Text(emoji)
                            .font(.system(size: 16 * s))
                            .grayscale(1)
                            .opacity(0.55)
                        Text("\(next.starsNeeded)⭐️")
                            .font(.kid(12 * s, .bold))
                            .foregroundStyle(pal.softInk)
                            .fixedSize()
                    }
                    .padding(.leading, unlocked.count > 1 ? 4 * s : 0)
                }
            }
            .padding(.horizontal, 12 * s)
            .padding(.vertical, 6 * s)
            .frame(minHeight: 36 * s)
            .background(Capsule().fill(pal.card.opacity(0.88)))
        }
        .buttonStyle(BouncyButtonStyle())
        .accessibilityLabel(unlocked.count > 1 ? "Change hat" : "Earn stars to unlock hats")
    }
}
