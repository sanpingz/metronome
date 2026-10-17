import SwiftUI
import QuartzCore

struct ControlsPanel: View {
    @Environment(\.uiScale) private var s

    var body: some View {
        VStack(spacing: 10 * s) {
            SettingsCards()
            PlayRow()
                .padding(.top, 2 * s)
        }
    }
}

struct SettingsCards: View {
    @Environment(\.uiScale) private var s

    var body: some View {
        VStack(spacing: 10 * s) {
            SpeedCard()
            HopsCard()
            SoundCard()
        }
    }
}

// MARK: - Speed

struct SpeedCard: View {
    @Environment(BeatModel.self) private var model
    @Environment(\.palette) private var pal
    @Environment(\.uiScale) private var s

    var body: some View {
        let current = SpeedAnimal.nearest(to: model.bpm)
        Card {
            VStack(spacing: 8 * s) {
                HStack(spacing: 6 * s) {
                    ForEach(SpeedAnimal.all) { animal in
                        Button {
                            model.setBPM(animal.bpm)
                        } label: {
                            VStack(spacing: 0) {
                                Text(animal.emoji)
                                    .font(.system(size: 28 * s))
                                Text(animal.name)
                                    .font(.kid(10 * s, .bold))
                                    .foregroundStyle(animal == current ? Color(hex: 0x5A3E00) : pal.softInk)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56 * s)
                            .background(
                                RoundedRectangle(cornerRadius: 16 * s, style: .continuous)
                                    .fill(animal == current ? pal.selection : pal.buttonFill))
                            .scaleEffect(animal == current ? 1.06 : 1)
                            .animation(.spring(response: 0.3, dampingFraction: 0.55), value: current)
                        }
                        .buttonStyle(BouncyButtonStyle())
                        .accessibilityLabel("\(animal.name) speed")
                    }
                }

                HStack(spacing: 10 * s) {
                    RepeatButton(systemImage: "minus", tint: Color(hex: 0x3BB8F0)) { model.nudgeBPM(-1) }
                        .accessibilityLabel("Slower")
                    HStack(alignment: .firstTextBaseline, spacing: 6 * s) {
                        Text("\(model.bpm)")
                            .font(.kid(36 * s))
                            .monospacedDigit()
                            .contentTransition(.numericText(value: Double(model.bpm)))
                            .animation(.snappy, value: model.bpm)
                        Text("beats\na minute")
                            .font(.kid(11 * s, .bold))
                            .foregroundStyle(pal.softInk)
                            .lineSpacing(-2)
                    }
                    .foregroundStyle(pal.ink)
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                    RepeatButton(systemImage: "plus", tint: Color(hex: 0xFF6B6B)) { model.nudgeBPM(1) }
                        .accessibilityLabel("Faster")
                }
            }
        }
    }
}

// MARK: - Hops (beats per bar)

struct HopsCard: View {
    @Environment(BeatModel.self) private var model
    @Environment(\.palette) private var pal
    @Environment(\.uiScale) private var s

    var body: some View {
        Card {
            HStack(spacing: 10 * s) {
                RoundStepButton(systemImage: "minus", tint: pal.padDark, enabled: model.beatsPerBar > BeatModel.beatRange.lowerBound) {
                    model.setBeats(model.beatsPerBar - 1)
                }
                .accessibilityLabel("Fewer hops")

                HStack(spacing: 5 * s) {
                    ForEach(0..<model.beatsPerBar, id: \.self) { i in
                        LilyPadShape()
                            .fill(i == 0 ? Color(hex: 0xFF8FC7) : pal.pad)
                            .frame(width: 22 * s, height: 14 * s)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: model.beatsPerBar)
                .frame(maxWidth: .infinity)
                .accessibilityElement()
                .accessibilityLabel("\(model.beatsPerBar) hops in each round")

                Text("\(model.beatsPerBar)")
                    .font(.kid(26 * s))
                    .foregroundStyle(pal.ink)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(model.beatsPerBar)))
                    .animation(.snappy, value: model.beatsPerBar)
                    .frame(minWidth: 22 * s)

                RoundStepButton(systemImage: "plus", tint: pal.padDark, enabled: model.beatsPerBar < BeatModel.beatRange.upperBound) {
                    model.setBeats(model.beatsPerBar + 1)
                }
                .accessibilityLabel("More hops")
            }
        }
    }
}

// MARK: - Sounds

struct SoundCard: View {
    @Environment(BeatModel.self) private var model
    @Environment(\.palette) private var pal
    @Environment(\.uiScale) private var s

    var body: some View {
        Card {
            HStack(spacing: 4 * s) {
                ForEach(Kit.allCases) { kit in
                    let selected = model.kit == kit
                    Button {
                        model.selectKit(kit)
                    } label: {
                        VStack(spacing: 2 * s) {
                            Text(kit.emoji)
                                .font(.system(size: 25 * s))
                                .frame(width: 48 * s, height: 48 * s)
                                .background(Circle().fill(kit.tint.opacity(selected ? 0.45 : 0.18)))
                                .overlay(Circle().stroke(kit.tint, lineWidth: selected ? 3.5 * s : 0))
                                .scaleEffect(selected ? 1.08 : 1)
                            Text(kit.name)
                                .font(.kid(10 * s, .bold))
                                .foregroundStyle(selected ? pal.ink : pal.softInk)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                        .animation(.spring(response: 0.3, dampingFraction: 0.55), value: selected)
                    }
                    .buttonStyle(BouncyButtonStyle())
                    .accessibilityLabel("\(kit.name) sound")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
    }
}

// MARK: - Play row

struct PlayRow: View {
    @Environment(BeatModel.self) private var model
    @Environment(\.uiScale) private var s

    var body: some View {
        HStack(spacing: 22 * s) {
            PressButton(action: model.tapTempo) {
                RoundEmojiLabel(emoji: "🥁", caption: "Tap speed", tint: Color(hex: 0xFFB347), size: 66 * s,
                                pulse: model.tapTempoTime)
            }
            .accessibilityLabel("Tap to set the speed")

            PlayButton(size: 100 * s)

            PressButton(action: model.clap) {
                RoundEmojiLabel(emoji: "👏", caption: "Clap!", tint: Color(hex: 0xB28DFF), size: 66 * s,
                                pulse: model.clapTime)
            }
            .accessibilityLabel("Clap along")
        }
    }
}

struct PlayButton: View {
    @Environment(BeatModel.self) private var model
    let size: CGFloat

    var body: some View {
        let playing = model.isPlaying
        let color = playing ? Color(hex: 0xFF5A5F) : Color(hex: 0x34C759)
        Button(action: model.togglePlay) {
            TimelineView(.animation(paused: !playing)) { _ in
                let clock = model.clock(at: CACurrentMediaTime())
                let pulse = clock.map { exp(-$0.since * 6) * ($0.beatInBar == 0 ? 1 : 0.6) } ?? 0
                ZStack {
                    Circle().fill(color.opacity(0.3))
                        .scaleEffect(1 + 0.22 * pulse)
                    Circle().fill(color.gradient)
                        .padding(size * 0.06)
                        .shadow(color: color.opacity(0.5), radius: size * 0.08, y: size * 0.04)
                    Image(systemName: playing ? "stop.fill" : "play.fill")
                        .font(.system(size: size * 0.36, weight: .black))
                        .foregroundStyle(.white)
                        .offset(x: playing ? 0 : size * 0.035)
                        .contentTransition(.symbolEffect(.replace))
                }
                .frame(width: size, height: size)
            }
        }
        .buttonStyle(BouncyButtonStyle())
        .accessibilityLabel(playing ? "Stop" : "Play")
    }
}

struct RoundEmojiLabel: View {
    @Environment(\.palette) private var pal
    @Environment(\.uiScale) private var s
    let emoji: String
    let caption: String
    let tint: Color
    let size: CGFloat
    var pulse: Double = -100

    var body: some View {
        VStack(spacing: 3 * s) {
            Text(emoji)
                .font(.system(size: size * 0.46))
                .frame(width: size, height: size)
                .background(Circle().fill(tint.gradient))
                .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 3 * s))
                .shadow(color: tint.opacity(0.45), radius: 6 * s, y: 3 * s)
                .keyframeAnimator(initialValue: 1.0, trigger: pulse) { content, scale in
                    content.scaleEffect(scale)
                } keyframes: { _ in
                    SpringKeyframe(1.18, duration: 0.08)
                    SpringKeyframe(1.0, duration: 0.3)
                }
            Text(caption)
                .font(.kid(12 * s, .bold))
                .foregroundStyle(pal.softInk)
        }
    }
}

// MARK: - Button primitives

/// Fires on touch-down (not release) so taps can be timed against the beat.
struct PressButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: () -> Label
    @GestureState private var pressed = false

    var body: some View {
        label()
            .scaleEffect(pressed ? 0.88 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.5), value: pressed)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0).updating($pressed) { _, state, _ in
                    if !state { action() }
                    state = true
                })
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { action() }
    }
}

/// Press once to nudge, hold to keep going.
struct RepeatButton: View {
    @Environment(\.uiScale) private var s
    let systemImage: String
    let tint: Color
    let action: () -> Void
    @GestureState private var pressed = false
    @State private var repeater = Repeater()

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 22 * s, weight: .black))
            .foregroundStyle(.white)
            .frame(width: 50 * s, height: 50 * s)
            .background(Circle().fill(tint.gradient))
            .scaleEffect(pressed ? 0.86 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.5), value: pressed)
            .gesture(
                DragGesture(minimumDistance: 0).updating($pressed) { _, state, _ in
                    if !state {
                        action()
                        repeater.start(action)
                    }
                    state = true
                })
            .onChange(of: pressed) { _, isDown in
                if !isDown { repeater.stop() }
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { action() }
    }
}

final class Repeater {
    private var timer: Timer?

    func start(_ action: @escaping () -> Void) {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: false) { [weak self] _ in
            self?.timer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { _ in action() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}

struct RoundStepButton: View {
    @Environment(\.uiScale) private var s
    let systemImage: String
    let tint: Color
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 20 * s, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 44 * s, height: 44 * s)
                .background(Circle().fill(tint.gradient))
                .opacity(enabled ? 1 : 0.35)
        }
        .buttonStyle(BouncyButtonStyle())
        .disabled(!enabled)
    }
}
