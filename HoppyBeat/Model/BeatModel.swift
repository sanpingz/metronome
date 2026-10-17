import SwiftUI
import UIKit
import QuartzCore

/// Where we are in the beat right now, as heard from the speaker.
struct BeatClock {
    let index: Int
    let beatInBar: Int
    let nextBeatInBar: Int
    let beatsPerBar: Int
    /// Seconds since the current beat was heard.
    let since: Double
    /// Seconds between this beat and the next one.
    let interval: Double
}

struct TapFeedback: Equatable {
    enum Kind { case perfect, great, early, late }
    let kind: Kind
    let time: Double
}

struct Celebration: Equatable {
    let emoji: String
    let title: String
    let time: Double
    let seed: Int
}

@Observable @MainActor
final class BeatModel {
    static let tempoRange = 30...200
    static let beatRange = 1...8
    static let sleepAfter: Double = 30

    private(set) var bpm: Int
    private(set) var beatsPerBar: Int
    private(set) var kit: Kit
    private(set) var hat: Hat
    private(set) var stars: Int
    private(set) var streak = 0
    private(set) var isPlaying = false
    private(set) var feedback: TapFeedback?
    private(set) var celebration: Celebration?
    private(set) var lastInteraction = CACurrentMediaTime()
    private(set) var hopTime: Double = -100
    private(set) var tapTempoTime: Double = -100
    private(set) var clapTime: Double = -100
    private(set) var clapsThisRun = 0

    @ObservationIgnored let engine = MetronomeEngine()
    @ObservationIgnored private let voice = VoiceCounter()
    @ObservationIgnored private let defaults = UserDefaults.standard
    @ObservationIgnored private var tapTimes: [Double] = []
    @ObservationIgnored private var lastScoredBeat = -1
    @ObservationIgnored private var lastHapticBeat = -1
    @ObservationIgnored private var watcher: Timer?
    @ObservationIgnored private let softHaptic = UIImpactFeedbackGenerator(style: .light)
    @ObservationIgnored private let strongHaptic = UIImpactFeedbackGenerator(style: .heavy)
    @ObservationIgnored private let successHaptic = UINotificationFeedbackGenerator()

    init() {
        let d = UserDefaults.standard
        let savedBPM = d.integer(forKey: "bpm")
        let savedBeats = d.integer(forKey: "beats")
        bpm = savedBPM == 0 ? 96 : savedBPM.clamped(to: Self.tempoRange)
        beatsPerBar = savedBeats == 0 ? 4 : savedBeats.clamped(to: Self.beatRange)
        kit = Kit(rawValue: d.string(forKey: "kit") ?? "") ?? .wood
        let savedStars = max(0, d.integer(forKey: "stars"))
        let savedHat = Hat(rawValue: d.integer(forKey: "hat")) ?? .none
        stars = savedStars
        hat = Hat.unlocked(stars: savedStars).contains(savedHat) ? savedHat : .none

        let (b, n, k) = (Double(bpm), beatsPerBar, kit)
        engine.update {
            $0.bpm = b
            $0.beatsPerBar = n
            $0.kit = k
        }
        engine.start()

        voice.renderCounts(upTo: 8) { [weak self] clips in
            guard let self else { return }
            for (i, clip) in clips.enumerated() {
                self.engine.install(clip, at: Slot.voiceBase + i)
            }
        }
    }

    // MARK: - Settings

    func setBPM(_ value: Int) {
        touch()
        let v = value.clamped(to: Self.tempoRange)
        guard v != bpm else { return }
        bpm = v
        defaults.set(v, forKey: "bpm")
        engine.update { $0.bpm = Double(v) }
    }

    func nudgeBPM(_ delta: Int) {
        setBPM(bpm + delta)
    }

    func setBeats(_ value: Int) {
        touch()
        let v = value.clamped(to: Self.beatRange)
        guard v != beatsPerBar else { return }
        beatsPerBar = v
        defaults.set(v, forKey: "beats")
        engine.update { $0.beatsPerBar = v }
        if !isPlaying { hop() }
    }

    func selectKit(_ newKit: Kit) {
        touch()
        kit = newKit
        defaults.set(newKit.rawValue, forKey: "kit")
        engine.update { $0.kit = newKit }
        if !isPlaying {
            let pick = newKit.sound(forBeat: 0, of: beatsPerBar)
            engine.trigger(slot: pick.slot, gain: pick.gain)
        }
    }

    func cycleHat() {
        touch()
        let options = Hat.unlocked(stars: stars)
        guard options.count > 1 else { return }
        let i = options.firstIndex(of: hat) ?? 0
        hat = options[(i + 1) % options.count]
        defaults.set(hat.rawValue, forKey: "hat")
        hopTime = CACurrentMediaTime()
    }

    // MARK: - Transport

    func togglePlay() {
        isPlaying ? stop() : start()
    }

    func start() {
        touch()
        engine.start()
        lastScoredBeat = -1
        lastHapticBeat = -1
        streak = 0
        clapsThisRun = 0
        feedback = nil
        engine.play()
        isPlaying = true
        UIApplication.shared.isIdleTimerDisabled = true
        startWatcher()
    }

    func stop() {
        touch()
        engine.stop()
        isPlaying = false
        UIApplication.shared.isIdleTimerDisabled = false
        watcher?.invalidate()
        watcher = nil
    }

    func scenePhaseChanged(_ phase: ScenePhase) {
        switch phase {
        case .active:
            engine.start()
        case .background:
            if isPlaying { stop() }
            engine.pause()
        default:
            break
        }
    }

    // MARK: - Play along

    /// Taps on the pond: clap along while playing, make Hoppy jump while stopped.
    func stageTapped() {
        if isPlaying {
            clap()
        } else {
            touch()
            hop()
        }
    }

    func clap() {
        touch()
        clapTime = CACurrentMediaTime()
        engine.trigger(slot: Slot.clap, gain: 0.8)
        guard isPlaying else {
            hopTime = CACurrentMediaTime()
            return
        }
        clapsThisRun += 1
        score(at: CACurrentMediaTime() - 0.015)
    }

    /// Tap the drum a few times and the metronome follows your speed.
    func tapTempo() {
        touch()
        let now = CACurrentMediaTime()
        tapTempoTime = now
        engine.trigger(slot: Slot.drumBeat, gain: 0.9)
        if let last = tapTimes.last, now - last > 2 { tapTimes.removeAll() }
        tapTimes.append(now)
        if tapTimes.count > 6 { tapTimes.removeFirst() }
        guard tapTimes.count >= 2 else { return }
        let gaps = zip(tapTimes.dropFirst(), tapTimes).map { $0 - $1 }
        let average = gaps.reduce(0, +) / Double(gaps.count)
        setBPM(Int((60 / average).rounded()))
    }

    func isSleeping(at t: Double) -> Bool {
        !isPlaying && t - lastInteraction > Self.sleepAfter
    }

    func clock(at t: Double) -> BeatClock? {
        guard isPlaying else { return nil }
        let events = engine.recentEvents()
        guard let last = events.filter({ $0.time <= t }).max(by: { $0.index < $1.index }) else { return nil }
        let next = events.first { $0.index == last.index + 1 }
        let interval = next.map { $0.time - last.time } ?? 60 / Double(bpm)
        let nextBeat = next?.beatInBar ?? (last.beatInBar + 1) % max(1, beatsPerBar)
        return BeatClock(index: last.index,
                         beatInBar: last.beatInBar,
                         nextBeatInBar: nextBeat,
                         beatsPerBar: last.beatsPerBar,
                         since: t - last.time,
                         interval: max(0.1, interval))
    }

    // MARK: - Private

    private func touch() {
        lastInteraction = CACurrentMediaTime()
    }

    private func hop() {
        hopTime = CACurrentMediaTime()
        engine.trigger(slot: Slot.frogAccent, gain: 0.9)
    }

    private func score(at t: Double) {
        let events = engine.recentEvents()
        let interval = 60 / Double(bpm)
        var candidates = events.map { (index: $0.index, time: $0.time) }
        if let newest = events.max(by: { $0.index < $1.index }) {
            candidates.append((newest.index + 1, newest.time + interval))
        }
        guard let target = candidates.min(by: { abs($0.time - t) < abs($1.time - t) }),
              target.index != lastScoredBeat else { return }
        lastScoredBeat = target.index

        let delta = t - target.time
        let perfectWindow = min(0.07, interval * 0.18)
        let greatWindow = min(0.14, interval * 0.32)
        let kind: TapFeedback.Kind
        if abs(delta) <= perfectWindow {
            kind = .perfect
        } else if abs(delta) <= greatWindow {
            kind = .great
        } else {
            kind = delta < 0 ? .early : .late
        }
        feedback = TapFeedback(kind: kind, time: CACurrentMediaTime())

        switch kind {
        case .perfect, .great:
            streak += 1
            award()
        case .early, .late:
            streak = 0
        }
    }

    private func award() {
        stars += 1
        defaults.set(stars, forKey: "stars")
        if let newHat = Hat.allCases.first(where: { $0.starsNeeded == stars && $0 != .none }) {
            hat = newHat
            defaults.set(newHat.rawValue, forKey: "hat")
            celebrate(newHat.emoji ?? "🎉", "New hat!")
        } else if stars % 10 == 0 {
            celebrate("⭐️", "\(stars) stars!")
        } else if streak % 8 == 0 {
            celebrate("🔥", "Super hopper!")
        }
    }

    private func celebrate(_ emoji: String, _ title: String) {
        let party = Celebration(emoji: emoji, title: title, time: CACurrentMediaTime(), seed: Int.random(in: 0...99_999))
        celebration = party
        successHaptic.notificationOccurred(.success)
        engine.trigger(slot: Slot.bellAccent, gain: 0.7)
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            if self?.celebration == party { self?.celebration = nil }
        }
    }

    private func startWatcher() {
        watcher?.invalidate()
        softHaptic.prepare()
        strongHaptic.prepare()
        let timer = Timer(timeInterval: 1.0 / 120, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.watchBeat() }
        }
        RunLoop.main.add(timer, forMode: .common)
        watcher = timer
    }

    /// Haptics land on the beat the child hears, not when it was scheduled.
    private func watchBeat() {
        guard let c = clock(at: CACurrentMediaTime()), c.index != lastHapticBeat else { return }
        lastHapticBeat = c.index
        if c.beatInBar == 0 {
            strongHaptic.impactOccurred(intensity: 0.9)
        } else {
            softHaptic.impactOccurred(intensity: 0.55)
        }
    }
}
