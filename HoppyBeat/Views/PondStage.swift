import SwiftUI
import QuartzCore

/// The animated pond: Hoppy jumps pad-to-pad so that every landing is exactly a beat.
struct PondStage: View {
    @Environment(BeatModel.self) private var model
    @Environment(\.palette) private var pal
    @Environment(\.uiScale) private var s
    @GestureState private var touching = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 30 * s, style: .continuous)
        GeometryReader { geo in
            // Full frame rate only while the beat is running; idle drifting clouds need far less.
            TimelineView(.animation(minimumInterval: model.isPlaying ? nil : 1.0 / 30)) { _ in
                PondScene(size: geo.size, t: CACurrentMediaTime(), model: model, pal: pal, s: s)
            }
        }
        .clipShape(shape)
        .contentShape(shape)
        // Fire on touch-down: on-beat clapping needs the moment the finger lands.
        .gesture(
            DragGesture(minimumDistance: 0).updating($touching) { _, state, _ in
                if !state { model.stageTapped() }
                state = true
            })
        .overlay(alignment: .top) {
            VStack(spacing: 8 * s) {
                StageHUD()
                hint
            }
            .padding(12 * s)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Pond. Tap on the beat to clap along.")
    }

    @ViewBuilder private var hint: some View {
        if model.isPlaying && model.clapsThisRun == 0 {
            Text("Tap the pond on the beat! 👏")
                .font(.kid(15 * s, .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14 * s)
                .padding(.vertical, 7 * s)
                .background(Capsule().fill(.black.opacity(0.25)))
                .allowsHitTesting(false)
                .transition(.opacity)
        }
    }
}

/// Positions of the lily pads. More than four pads on a narrow pond snake over two rows.
struct PondLayout {
    let size: CGSize
    let count: Int
    let columns: Int
    let rows: Int
    let padSize: CGFloat
    let frogSize: CGFloat
    let horizon: CGFloat
    let waterTop: CGFloat
    private let margin: CGFloat
    private let slot: CGFloat

    init(size: CGSize, beats: Int) {
        self.size = size
        count = max(1, beats)
        let w = size.width, h = max(size.height, 1)
        columns = (count <= 4 || w / h >= 1.35) ? count : Int((Double(count) / 2).rounded(.up))
        rows = count > columns ? 2 : 1
        horizon = h * 0.40
        waterTop = h * 0.50
        margin = w * 0.06
        slot = (w - 2 * margin) / CGFloat(columns)
        padSize = min(slot * 0.84, h * (rows == 2 ? 0.22 : 0.28), w * 0.3)
        frogSize = min(padSize * 0.95, h * 0.25)
    }

    func padCenter(_ i: Int) -> CGPoint {
        let row = i / columns
        var column = i % columns
        if row == 1 { column = columns - 1 - column }
        let x = margin + slot * (CGFloat(column) + 0.5)
        let y: CGFloat = rows == 1 ? size.height * 0.75 : (row == 0 ? size.height * 0.65 : size.height * 0.87)
        return CGPoint(x: x, y: y)
    }

    /// Where Hoppy's feet touch the pad.
    func seat(_ i: Int) -> CGPoint {
        let c = padCenter(i % count)
        return CGPoint(x: c.x, y: c.y - padSize * 0.05)
    }
}

private struct FrogPose {
    var point: CGPoint
    var scaleX: CGFloat = 1
    var scaleY: CGFloat = 1
    var mouth: Double = 0
    var look: CGFloat = 0
    var eyesClosed = false
}

struct PondScene: View {
    let size: CGSize
    let t: Double
    let model: BeatModel
    let pal: Palette
    let s: CGFloat

    var body: some View {
        let layout = PondLayout(size: size, beats: model.beatsPerBar)
        let clock = model.clock(at: t)
        let pose = frogPose(layout, clock)
        ZStack(alignment: .topLeading) {
            sky(layout, clock)
            land(layout)
            pads(layout, clock)
            countBubble(layout, clock)
            frog(layout, pose)
            if pal.isNight { fireflies(layout, clock) }
            sleepyZs(layout, pose)
            feedbackBubble
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    // MARK: Scenery

    @ViewBuilder private func sky(_ L: PondLayout, _ clock: BeatClock?) -> some View {
        let w = size.width, h = size.height
        let r = min(w, h) * 0.075
        let downbeat = clock.map { $0.beatInBar == 0 ? exp(-$0.since * 5) : 0 } ?? 0

        LinearGradient(colors: [pal.skyTop, pal.skyBottom], startPoint: .top, endPoint: .bottom)
            .frame(width: w, height: L.waterTop)

        if pal.isNight {
            Canvas { ctx, _ in
                for i in 0..<28 {
                    let x = hash01(i, 1) * w
                    let y = hash01(i, 2) * L.horizon * 0.95
                    let d = (1.5 + hash01(i, 3) * 2.5) * s
                    let o = 0.35 + 0.65 * abs(sin(t * (0.6 + hash01(i, 4)) + Double(i)))
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: d, height: d)), with: .color(.white.opacity(o)))
                }
            }
            MoonView(radius: r)
                .scaleEffect(1 + 0.06 * downbeat)
                .position(x: w * 0.74, y: h * 0.25)
        } else {
            ForEach(0..<3, id: \.self) { i in
                let cw = w * (0.16 + 0.05 * CGFloat(i))
                let speed = (6 + Double(i) * 4) * Double(s)
                let span = Double(w + cw * 2)
                let x = (hash01(i, 9) * span + t * speed).truncatingRemainder(dividingBy: span) - Double(cw)
                CloudView(width: cw)
                    .position(x: x, y: h * (0.1 + 0.08 * CGFloat(i)))
            }
            SunView(radius: r, t: t)
                .scaleEffect(1 + 0.08 * downbeat)
                .position(x: w * 0.74, y: h * 0.25)
        }
    }

    @ViewBuilder private func land(_ L: PondLayout) -> some View {
        let w = size.width, h = size.height
        HillShape(base: L.waterTop + 2, amplitude: h * 0.13, waves: 1.3, phase: 0.6)
            .fill(pal.hillBack)
        HillShape(base: L.waterTop + 2, amplitude: h * 0.07, waves: 2.2, phase: 2.0)
            .fill(pal.hillFront)

        LinearGradient(colors: [pal.waterTop, pal.waterBottom], startPoint: .top, endPoint: .bottom)
            .frame(width: w, height: h - L.waterTop)
            .offset(y: L.waterTop)
        Rectangle().fill(.white.opacity(0.35))
            .frame(width: w, height: 3 * s)
            .offset(y: L.waterTop)

        Canvas { ctx, _ in
            for i in 0..<7 {
                let span = Double(w) + 80
                let x = (hash01(i, 5) * span - t * (10 + 8 * hash01(i, 6)) * Double(s))
                    .truncatingRemainder(dividingBy: span)
                let wx = x < 0 ? x + span : x
                let y = Double(L.waterTop) + Double(h - L.waterTop) * (0.08 + 0.85 * hash01(i, 7))
                let ww = (26 + 22 * hash01(i, 8)) * Double(s)
                var p = Path()
                p.move(to: CGPoint(x: wx - 40, y: y))
                p.addQuadCurve(to: CGPoint(x: wx - 40 + ww * 0.5, y: y), control: CGPoint(x: wx - 40 + ww * 0.25, y: y - 5 * Double(s)))
                p.addQuadCurve(to: CGPoint(x: wx - 40 + ww, y: y), control: CGPoint(x: wx - 40 + ww * 0.75, y: y + 5 * Double(s)))
                ctx.stroke(p, with: .color(.white.opacity(0.3)), style: StrokeStyle(lineWidth: 2.5 * s, lineCap: .round))
            }
        }

        ForEach(0..<5, id: \.self) { i in
            let left = i < 3
            let x = left ? w * (0.025 + 0.035 * CGFloat(i)) : w * (0.94 + 0.035 * CGFloat(i - 3))
            CattailView(height: h * (0.2 + 0.05 * CGFloat(i % 2)), s: s)
                .rotationEffect(.degrees(sin(t * 1.3 + Double(i)) * 4), anchor: .bottom)
                .position(x: x, y: L.waterTop + 4 * s - h * (0.1 + 0.025 * CGFloat(i % 2)))
        }
    }

    // MARK: Pads

    private func pads(_ L: PondLayout, _ clock: BeatClock?) -> some View {
        ForEach(0..<L.count, id: \.self) { i in
            let active = clock.map { $0.beatInBar % L.count == i } ?? false
            PadView(size: L.padSize, isAccent: i == 0, since: active ? clock?.since : nil, pal: pal, s: s)
                .position(L.padCenter(i))
        }
    }

    @ViewBuilder private func countBubble(_ L: PondLayout, _ clock: BeatClock?) -> some View {
        if let c = clock, c.since < 0.7 {
            let seat = L.seat(c.beatInBar)
            let e = c.since
            let pop = min(1, e * 9)
            Text("\(c.beatInBar + 1)")
                .font(.kid(L.frogSize * 0.55))
                .foregroundStyle(.white)
                .shadow(color: pal.padDark.opacity(0.8), radius: 0, x: 2 * s, y: 3 * s)
                .scaleEffect(0.5 + 0.6 * pop)
                .opacity(1 - e / 0.7)
                .position(x: seat.x, y: seat.y - L.frogSize * 1.45 - CGFloat(e) * 40 * s)
        }
    }

    // MARK: Hoppy

    private func frogPose(_ L: PondLayout, _ clock: BeatClock?) -> FrogPose {
        if let c = clock {
            let from = c.beatInBar % L.count
            let to = c.nextBeatInBar % L.count
            let p0 = L.seat(from), p1 = L.seat(to)
            let jumpDuration = min(c.interval * 0.6, 0.42)
            let jumpStart = c.interval - jumpDuration
            var pose = FrogPose(point: p0)
            pose.look = max(-1, min(1, (p1.x - p0.x) / max(L.padSize, 1)))
            pose.mouth = (from == 0 || model.kit == .frog) ? exp(-c.since * 7) : 0

            if c.since < jumpStart {
                // Squash on landing, then crouch just before take-off.
                let land = exp(-c.since * 14)
                let crouch = smoothstep(jumpStart - 0.12, jumpStart, c.since)
                pose.scaleX = 1 + 0.22 * land + 0.08 * crouch
                pose.scaleY = 1 - 0.2 * land - 0.1 * crouch
            } else {
                let q = min(1, (c.since - jumpStart) / jumpDuration)
                let distance = hypot(p1.x - p0.x, p1.y - p0.y)
                let height = L.padSize * 0.75 + distance * 0.22
                let arc = CGFloat(4 * q * (1 - q))
                pose.point = CGPoint(x: p0.x + (p1.x - p0.x) * CGFloat(q),
                                     y: p0.y + (p1.y - p0.y) * CGFloat(q) - height * arc)
                pose.scaleX = 0.9
                pose.scaleY = 1.12
            }
            return pose
        }

        var pose = FrogPose(point: L.seat(0))
        let sleeping = model.isSleeping(at: t)
        let hop = t - model.hopTime
        if hop >= 0 && hop < 0.5 {
            let q = hop / 0.5
            pose.point.y -= L.padSize * 0.7 * CGFloat(4 * q * (1 - q))
            pose.mouth = 1 - q
            pose.scaleY = 1.1
            pose.scaleX = 0.92
        } else {
            let breathe = sin(t * (sleeping ? 1.6 : 2.6)) * 0.025
            pose.scaleY = 1 + breathe
            pose.scaleX = 1 - breathe * 0.5
            pose.look = CGFloat(sin(t * 0.45)) * 0.8
        }
        pose.eyesClosed = sleeping || (t + 0.3).truncatingRemainder(dividingBy: 3.7) < 0.13
        return pose
    }

    private func frog(_ L: PondLayout, _ pose: FrogPose) -> some View {
        FrogView(size: L.frogSize, eyesClosed: pose.eyesClosed, mouthOpen: pose.mouth, look: pose.look, hat: model.hat.emoji)
            .scaleEffect(x: pose.scaleX, y: pose.scaleY, anchor: .bottom)
            .position(x: pose.point.x, y: pose.point.y - L.frogSize * 0.48)
    }

    @ViewBuilder private func sleepyZs(_ L: PondLayout, _ pose: FrogPose) -> some View {
        if model.isSleeping(at: t) {
            ForEach(0..<3, id: \.self) { i in
                let e = (t * 0.5 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                Text("z")
                    .font(.kid(L.frogSize * (0.18 + 0.22 * e)))
                    .foregroundStyle(.white.opacity(1 - e))
                    .position(x: pose.point.x + L.frogSize * (0.35 + 0.3 * e),
                              y: pose.point.y - L.frogSize * (0.95 + 0.8 * e))
            }
        }
    }

    private func fireflies(_ L: PondLayout, _ clock: BeatClock?) -> some View {
        let pulse = clock.map { 0.35 + 0.65 * exp(-$0.since * 4) } ?? 0.5
        return Canvas { ctx, size in
            for i in 0..<7 {
                let x = size.width * (0.1 + 0.8 * hash01(i, 11)) + 30 * s * sin(t * 0.7 + Double(i) * 2)
                let y = size.height * (0.22 + 0.32 * hash01(i, 12)) + 18 * s * sin(t * 1.1 + Double(i))
                let glow = 18 * s * pulse
                ctx.fill(Path(ellipseIn: CGRect(x: x - glow / 2, y: y - glow / 2, width: glow, height: glow)),
                         with: .color(Color(hex: 0xFFF59D).opacity(0.25 * pulse)))
                let core = 5 * s
                ctx.fill(Path(ellipseIn: CGRect(x: x - core / 2, y: y - core / 2, width: core, height: core)),
                         with: .color(Color(hex: 0xFFFDE0).opacity(0.5 + 0.5 * pulse)))
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder private var feedbackBubble: some View {
        if let fb = model.feedback, t - fb.time < 1 {
            let e = t - fb.time
            let (text, color) = Self.style(for: fb.kind)
            let pop = e < 0.12 ? e / 0.12 * 1.2 : max(1, 1.2 - (e - 0.12) * 2)
            Text(text)
                .font(.kid(28 * s))
                .foregroundStyle(.white)
                .padding(.horizontal, 18 * s)
                .padding(.vertical, 8 * s)
                .background(Capsule().fill(color).shadow(color: .black.opacity(0.2), radius: 4 * s, y: 3 * s))
                .scaleEffect(pop)
                .opacity(e > 0.75 ? (1 - e) / 0.25 : 1)
                .position(x: size.width / 2, y: size.height * 0.32 - CGFloat(e) * 24 * s)
        }
    }

    static func style(for kind: TapFeedback.Kind) -> (String, Color) {
        switch kind {
        case .perfect: ("Perfect! ⭐️", Color(hex: 0xFF9F1C))
        case .great: ("Great! ⭐️", Color(hex: 0x34C759))
        case .early: ("A bit early 🐇", Color(hex: 0x8E7CFF))
        case .late: ("A bit late 🐢", Color(hex: 0x3BB8F0))
        }
    }
}

private func smoothstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
    guard b > a else { return x >= b ? 1 : 0 }
    let u = min(1, max(0, (x - a) / (b - a)))
    return u * u * (3 - 2 * u)
}

// MARK: - Scenery pieces

struct PadView: View {
    let size: CGFloat
    let isAccent: Bool
    let since: Double?
    let pal: Palette
    let s: CGFloat

    var body: some View {
        let d = size
        let hit = since.map { exp(-$0 * 5) } ?? 0
        ZStack {
            if let since {
                ForEach(0..<2, id: \.self) { r in
                    let e = since - Double(r) * 0.15
                    if e > 0 && e < 0.9 {
                        Ellipse()
                            .stroke(.white.opacity((1 - e / 0.9) * 0.7), lineWidth: 3 * s)
                            .frame(width: d * (1 + e * 1.4), height: d * 0.42 * (1 + e * 1.4))
                    }
                }
            }
            Ellipse().fill(.black.opacity(0.16))
                .frame(width: d * 1.04, height: d * 0.42)
                .offset(y: d * 0.05)
            LilyPadShape()
                .fill(LinearGradient(colors: [pal.padLight, pal.pad, pal.padDark], startPoint: .top, endPoint: .bottom))
                .frame(width: d, height: d * 0.42)
            LilyPadShape()
                .stroke(pal.glow, lineWidth: 5 * s)
                .frame(width: d, height: d * 0.42)
                .shadow(color: pal.glow, radius: 8 * s)
                .opacity(hit)
            if isAccent {
                FlowerView(size: d * 0.3)
                    .scaleEffect(1 + 0.35 * hit, anchor: .bottom)
                    .offset(x: -d * 0.4, y: -d * 0.02)
            }
        }
        .offset(y: d * 0.05 * hit)
    }
}

struct LilyPadShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: r.midX, y: r.midY)
        let notch = -Double.pi / 2 + 0.6
        let half = 0.26
        p.move(to: c)
        let steps = 48
        for i in 0...steps {
            let a = notch + half + (2 * .pi - 2 * half) * Double(i) / Double(steps)
            p.addLine(to: CGPoint(x: c.x + cos(a) * r.width / 2, y: c.y + sin(a) * r.height / 2))
        }
        p.closeSubpath()
        return p
    }
}

struct FlowerView: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { i in
                Ellipse().fill(Color(hex: 0xFF8FC7))
                    .frame(width: size * 0.36, height: size * 0.56)
                    .offset(y: -size * 0.24)
                    .rotationEffect(.degrees(Double(i) * 60))
            }
            Circle().fill(Color(hex: 0xFFD54F))
                .frame(width: size * 0.36)
        }
        .frame(width: size, height: size)
    }
}

struct HillShape: Shape {
    var base: CGFloat
    var amplitude: CGFloat
    var waves: Double
    var phase: Double

    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: base))
        let steps = 40
        for i in 0...steps {
            let u = Double(i) / Double(steps)
            let y = base - amplitude * CGFloat(0.5 + 0.5 * sin(u * .pi * 2 * waves + phase))
            p.addLine(to: CGPoint(x: r.width * CGFloat(u), y: y))
        }
        p.addLine(to: CGPoint(x: r.width, y: base))
        p.closeSubpath()
        return p
    }
}

struct CloudView: View {
    let width: CGFloat

    var body: some View {
        ZStack(alignment: .bottom) {
            Capsule().frame(width: width, height: width * 0.32)
            Circle().frame(width: width * 0.42).offset(x: -width * 0.16, y: -width * 0.1)
            Circle().frame(width: width * 0.54).offset(x: width * 0.1, y: -width * 0.14)
        }
        .foregroundStyle(.white.opacity(0.92))
    }
}

struct SunView: View {
    let radius: CGFloat
    let t: Double

    var body: some View {
        let r = radius
        let ink = Color(hex: 0x8A5A12)
        ZStack {
            ForEach(0..<10, id: \.self) { i in
                Capsule().fill(Color(hex: 0xFFC93C))
                    .frame(width: r * 0.22, height: r * 0.5)
                    .offset(y: -r * 1.32)
                    .rotationEffect(.degrees(Double(i) * 36 + t * 12))
            }
            Circle()
                .fill(RadialGradient(colors: [Color(hex: 0xFFF3A0), Color(hex: 0xFFD23F)], center: .center, startRadius: 0, endRadius: r))
                .frame(width: r * 2, height: r * 2)
            HStack(spacing: r * 0.5) {
                Capsule().frame(width: r * 0.16, height: r * 0.26)
                Capsule().frame(width: r * 0.16, height: r * 0.26)
            }
            .foregroundStyle(ink)
            .offset(y: -r * 0.18)
            SmileShape()
                .stroke(ink, style: StrokeStyle(lineWidth: r * 0.1, lineCap: .round))
                .frame(width: r * 0.7, height: r * 0.18)
                .offset(y: r * 0.25)
            HStack(spacing: r * 0.95) {
                Circle().fill(Color(hex: 0xFF9E7A).opacity(0.7)).frame(width: r * 0.28)
                Circle().fill(Color(hex: 0xFF9E7A).opacity(0.7)).frame(width: r * 0.28)
            }
            .offset(y: r * 0.15)
        }
    }
}

struct MoonView: View {
    let radius: CGFloat

    var body: some View {
        let r = radius
        let ink = Color(hex: 0x6B6A8F)
        ZStack {
            Circle().fill(Color(hex: 0xFFF6C8))
                .frame(width: r * 2, height: r * 2)
                .shadow(color: Color(hex: 0xFFF6C8).opacity(0.6), radius: r * 0.6)
            Circle().fill(Color(hex: 0xEDE2A8)).frame(width: r * 0.4).offset(x: r * 0.45, y: -r * 0.5)
            Circle().fill(Color(hex: 0xEDE2A8)).frame(width: r * 0.25).offset(x: -r * 0.55, y: r * 0.45)
            HStack(spacing: r * 0.45) {
                SmileShape().stroke(ink, style: StrokeStyle(lineWidth: r * 0.09, lineCap: .round))
                    .frame(width: r * 0.32, height: r * 0.08)
                SmileShape().stroke(ink, style: StrokeStyle(lineWidth: r * 0.09, lineCap: .round))
                    .frame(width: r * 0.32, height: r * 0.08)
            }
            .offset(y: -r * 0.1)
            SmileShape().stroke(ink, style: StrokeStyle(lineWidth: r * 0.08, lineCap: .round))
                .frame(width: r * 0.36, height: r * 0.08)
                .offset(y: r * 0.35)
        }
    }
}

struct CattailView: View {
    let height: CGFloat
    let s: CGFloat

    var body: some View {
        VStack(spacing: -2 * s) {
            Capsule().fill(Color(hex: 0x8B5A2B))
                .frame(width: 9 * s, height: height * 0.28)
            Capsule().fill(Color(hex: 0x4E8F3A))
                .frame(width: 3.5 * s, height: height * 0.72)
        }
        .frame(height: height)
    }
}
