import Foundation

/// Every sound in the app is synthesized here at launch — no audio files ship with the app.
enum SoundSynth {
    static let rate = MetronomeEngine.sampleRate

    static func makeBank() -> [Int: [Float]] {
        var bank: [Int: [Float]] = [:]
        bank[Slot.woodAccent] = woodblock(freq: 1250, decay: 0.02, peak: 0.95)
        bank[Slot.woodBeat] = woodblock(freq: 880, decay: 0.016, peak: 0.75)
        bank[Slot.drumAccent] = drum(accent: true)
        bank[Slot.drumBeat] = drum(accent: false)
        bank[Slot.bellAccent] = bell(1046.5, length: 1.0, peak: 0.85)
        bank[Slot.bellBeat] = bell(783.99, length: 0.6, peak: 0.6)
        bank[Slot.frogAccent] = ribbit(accent: true)
        bank[Slot.frogBeat] = ribbit(accent: false)
        bank[Slot.clap] = clap()
        for semitone in 0...12 {
            bank[Slot.pianoBase + semitone] = piano(semitone: semitone)
        }
        return bank
    }

    // MARK: - Instruments

    private static func woodblock(freq: Double, decay: Double, peak: Float) -> [Float] {
        var noise = Noise(seed: 7)
        var x = render(0.12) { t in
            let body = sin(2 * .pi * freq * t) * exp(-t / decay)
            let ring = 0.4 * sin(2 * .pi * freq * 2.71 * t) * exp(-t / (decay * 0.4))
            let tick = noise.next() * exp(-t / 0.0015) * 0.3
            return body + ring + tick
        }
        fadeOut(&x, seconds: 0.02)
        normalize(&x, peak: peak)
        return x
    }

    private static func drum(accent: Bool) -> [Float] {
        var noise = Noise(seed: accent ? 11 : 13)
        var phase = 0.0
        var lowpass = 0.0
        var x = render(accent ? 0.38 : 0.22) { t in
            let freq = accent ? 85 + 140 * exp(-t / 0.035) : 180 + 110 * exp(-t / 0.025)
            phase += 2 * .pi * freq / rate
            // Soft saturation adds harmonics so the drum still sounds on tiny phone speakers.
            let body = tanh(2.2 * sin(phase)) * exp(-t / (accent ? 0.13 : 0.07))
            lowpass += (noise.next() - lowpass) * 0.3
            let snap = lowpass * exp(-t / (accent ? 0.01 : 0.04)) * (accent ? 0.5 : 0.7)
            return body + snap
        }
        fadeOut(&x, seconds: 0.03)
        normalize(&x, peak: accent ? 0.98 : 0.8)
        return x
    }

    private static func bell(_ freq: Double, length: Double, peak: Float) -> [Float] {
        let partials: [(ratio: Double, amp: Double, decay: Double)] = [
            (1, 1, 0.55), (2, 0.45, 0.3), (2.76, 0.32, 0.2), (5.4, 0.14, 0.09), (8.93, 0.06, 0.05),
        ]
        var x = render(length) { t in
            var s = 0.0
            for p in partials {
                s += p.amp * sin(2 * .pi * freq * p.ratio * t) * exp(-t / (p.decay * length))
            }
            return s * min(1, t / 0.0015)
        }
        fadeOut(&x, seconds: 0.06)
        normalize(&x, peak: peak)
        return x
    }

    private static func piano(semitone: Int) -> [Float] {
        let freq = 523.25 * pow(2, Double(semitone) / 12)
        var x = render(0.9) { t in
            var s = 0.0
            for h in 1...7 {
                let n = Double(h)
                s += pow(n, -1.4) * sin(2 * .pi * freq * n * (1 + 0.0007 * n) * t) * exp(-t * (2.4 + 1.6 * n))
            }
            return s * min(1, t / 0.003)
        }
        fadeOut(&x, seconds: 0.1)
        normalize(&x, peak: 0.85)
        return x
    }

    /// "Rib-bit!" on the first beat, a short "rib" otherwise.
    private static func ribbit(accent: Bool) -> [Float] {
        var x: [Float]
        if accent {
            x = croak(0.075, from: 95, to: 140)
            x += [Float](repeating: 0, count: Int(0.03 * rate))
            x += croak(0.1, from: 150, to: 105)
        } else {
            x = croak(0.07, from: 130, to: 170)
        }
        normalize(&x, peak: accent ? 0.95 : 0.75)
        return x
    }

    private static func croak(_ seconds: Double, from f0: Double, to f1: Double) -> [Float] {
        var phase = 0.0
        var low = Biquad.bandpass(700, q: 3, sampleRate: rate)
        var high = Biquad.bandpass(1700, q: 4, sampleRate: rate)
        return render(seconds) { t in
            phase += (f0 + (f1 - f0) * (t / seconds)) / rate
            phase -= floor(phase)
            let buzz = 2 * phase - 1
            let trill = 0.6 + 0.4 * sin(2 * .pi * 42 * t)
            let env = min(1, t / 0.006) * min(1, (seconds - t) / 0.018)
            return (low.process(buzz) + 0.7 * high.process(buzz)) * trill * env
        }
    }

    private static func clap() -> [Float] {
        var noise = Noise(seed: 21)
        var filter = Biquad.bandpass(1400, q: 0.9, sampleRate: rate)
        var x = render(0.2) { t in
            var env = 0.0
            for k in 0..<3 {
                let tk = t - Double(k) * 0.009
                if tk >= 0 { env = max(env, exp(-tk / 0.0035)) }
            }
            let tail = t - 0.018
            if tail >= 0 { env = max(env, 0.75 * exp(-tail / 0.045)) }
            return filter.process(noise.next()) * env
        }
        normalize(&x, peak: 0.8)
        return x
    }

    // MARK: - Helpers

    private static func render(_ seconds: Double, _ sample: (Double) -> Double) -> [Float] {
        let n = Int(seconds * rate)
        var out = [Float](repeating: 0, count: n)
        for i in 0..<n { out[i] = Float(sample(Double(i) / rate)) }
        return out
    }

    static func normalize(_ x: inout [Float], peak: Float) {
        let maxValue = x.reduce(0) { max($0, abs($1)) }
        guard maxValue > 0 else { return }
        let gain = peak / maxValue
        for i in x.indices { x[i] *= gain }
    }

    static func fadeOut(_ x: inout [Float], seconds: Double) {
        let n = min(x.count, Int(seconds * rate))
        guard n > 0 else { return }
        let start = x.count - n
        for i in 0..<n { x[start + i] *= Float(n - i) / Float(n) }
    }
}

struct Noise {
    private var state: UInt32
    init(seed: UInt32) { state = seed }

    mutating func next() -> Double {
        state = state &* 1_664_525 &+ 1_013_904_223
        return Double(state >> 8) / Double(1 << 24) * 2 - 1
    }
}

struct Biquad {
    private var b0 = 0.0, b1 = 0.0, b2 = 0.0, a1 = 0.0, a2 = 0.0
    private var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0

    static func bandpass(_ freq: Double, q: Double, sampleRate: Double) -> Biquad {
        var f = Biquad()
        let w0 = 2 * Double.pi * freq / sampleRate
        let alpha = sin(w0) / (2 * q)
        let a0 = 1 + alpha
        f.b0 = alpha / a0
        f.b2 = -alpha / a0
        f.a1 = -2 * cos(w0) / a0
        f.a2 = (1 - alpha) / a0
        return f
    }

    mutating func process(_ x: Double) -> Double {
        let y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2 = x1; x1 = x
        y2 = y1; y1 = y
        return y
    }
}
