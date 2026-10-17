import AVFoundation
import QuartzCore
import os

/// A beat as it will be heard: `time` is in host seconds (same clock as `CACurrentMediaTime`).
struct BeatEvent {
    var time: Double = -.infinity
    var index: Int = -1
    var beatInBar: Int = 0
    var beatsPerBar: Int = 1
}

struct SampleRef {
    var data: UnsafePointer<Float>?
    var count: Int = 0
}

/// Indexes into the engine's sample table.
enum Slot {
    static let woodAccent = 0
    static let woodBeat = 1
    static let drumAccent = 2
    static let drumBeat = 3
    static let bellAccent = 4
    static let bellBeat = 5
    static let frogAccent = 6
    static let frogBeat = 7
    static let clap = 8
    static let pianoBase = 9    // 13 semitones, C5 ... C6
    static let voiceBase = 22   // spoken "one" ... "eight"
    static let count = 30
}

/// Sample-accurate metronome. One `AVAudioSourceNode` renders every click itself, so beats never
/// drift, tempo changes are glitch-free, and the UI can ask exactly when each beat reaches the speaker.
///
/// Threading: everything the render thread shares with the main thread lives behind `lock` and is
/// stored in fixed, never-reallocated buffers so the render callback never allocates.
final class MetronomeEngine {
    static let sampleRate: Double = 48_000

    struct Params {
        var bpm: Double = 96
        var beatsPerBar = 4
        var kit: Kit = .wood
        var playing = false
        var startToken = 0
        var latency: Double = 0
    }

    private struct Voice {
        var data: UnsafePointer<Float>
        var count: Int
        var position: Int
        var delay: Int
        var gain: Float
    }

    private struct OneShot {
        var slot: Int
        var gain: Float
    }

    private static let eventCapacity = 8
    private static let oneShotCapacity = 8
    private static let voiceCapacity = 32

    private let engine = AVAudioEngine()
    private var source: AVAudioSourceNode?
    private var wantsRunning = false
    private let lock: UnsafeMutablePointer<os_unfair_lock>

    // Shared with the render thread; guarded by `lock`.
    private var params = Params()
    private let slots: UnsafeMutablePointer<SampleRef>
    private let events: UnsafeMutablePointer<BeatEvent>
    private var eventCursor = 0
    private let oneShots: UnsafeMutablePointer<OneShot>
    private var oneShotCount = 0

    // Owned by the render thread.
    private let voices: UnsafeMutablePointer<Voice>
    private var voiceCount = 0
    private var framesToNextBeat: Double = 0
    private var beatInBar = 0
    private var beatIndex = 0
    private var renderToken = -1
    private var renderBPM: Double = 0

    init() {
        lock = .allocate(capacity: 1)
        lock.initialize(to: os_unfair_lock())
        slots = .allocate(capacity: Slot.count)
        slots.initialize(repeating: SampleRef(), count: Slot.count)
        events = .allocate(capacity: Self.eventCapacity)
        events.initialize(repeating: BeatEvent(), count: Self.eventCapacity)
        oneShots = .allocate(capacity: Self.oneShotCapacity)
        oneShots.initialize(repeating: OneShot(slot: 0, gain: 0), count: Self.oneShotCapacity)
        voices = .allocate(capacity: Self.voiceCapacity)

        for (slot, samples) in SoundSynth.makeBank() {
            install(samples, at: slot)
        }
        observeSystemEvents()
    }

    // MARK: - Control (main thread)

    func start() {
        wantsRunning = true
        let session = AVAudioSession.sharedInstance()
        if source == nil {
            // One-time setup; repeating these calls on every foreground blocks the main thread.
            do {
                try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
                try? session.setPreferredIOBufferDuration(0.005)
                try session.setActive(true)
            } catch {
                print("Audio session error: \(error)")
            }
            let format = AVAudioFormat(standardFormatWithSampleRate: Self.sampleRate, channels: 1)!
            let node = AVAudioSourceNode(format: format) { [unowned self] isSilence, timestamp, frameCount, buffers in
                self.render(isSilence: isSilence, timestamp: timestamp, frameCount: Int(frameCount), buffers: buffers)
            }
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
            source = node
        }
        let latency = session.outputLatency
        update { $0.latency = latency }
        startEngineIfNeeded()
    }

    func pause() {
        wantsRunning = false
        engine.pause()
    }

    func update(_ change: (inout Params) -> Void) {
        withLock { change(&params) }
    }

    func play() {
        withLock {
            params.playing = true
            params.startToken += 1
            for i in 0..<Self.eventCapacity { events[i] = BeatEvent() }
            eventCursor = 0
        }
    }

    func stop() {
        withLock { params.playing = false }
    }

    /// Plays a sound right away, outside the beat grid (taps, previews, celebrations).
    func trigger(slot: Int, gain: Float = 1) {
        withLock {
            guard oneShotCount < Self.oneShotCapacity else { return }
            oneShots[oneShotCount] = OneShot(slot: slot, gain: gain)
            oneShotCount += 1
        }
    }

    func install(_ samples: [Float], at slot: Int) {
        guard !samples.isEmpty, slot < Slot.count else { return }
        let buffer = UnsafeMutablePointer<Float>.allocate(capacity: samples.count)
        buffer.initialize(from: samples, count: samples.count)
        // Any previous buffer is intentionally kept alive: a voice may still be reading it.
        withLock { slots[slot] = SampleRef(data: UnsafePointer(buffer), count: samples.count) }
    }

    func recentEvents() -> [BeatEvent] {
        // Allocate before taking the lock so the audio thread never waits on malloc.
        var result: [BeatEvent] = []
        result.reserveCapacity(Self.eventCapacity)
        withLock {
            for i in 0..<Self.eventCapacity where events[i].index >= 0 {
                result.append(events[i])
            }
        }
        return result
    }

    // MARK: - Render (audio thread)

    private func render(isSilence: UnsafeMutablePointer<ObjCBool>,
                        timestamp: UnsafePointer<AudioTimeStamp>,
                        frameCount: Int,
                        buffers: UnsafeMutablePointer<AudioBufferList>) -> OSStatus {
        let sr = Self.sampleRate
        let stamp = timestamp.pointee
        let hostSeconds = stamp.mFlags.contains(.hostTimeValid)
            ? AVAudioTime.seconds(forHostTime: stamp.mHostTime)
            : CACurrentMediaTime()

        os_unfair_lock_lock(lock)
        let p = params
        for k in 0..<oneShotCount {
            let shot = oneShots[k]
            var ref = slots[shot.slot]
            if ref.count == 0 { ref = slots[Slot.woodAccent] }
            startVoice(ref, delay: 0, gain: shot.gain)
        }
        oneShotCount = 0
        os_unfair_lock_unlock(lock)

        if p.startToken != renderToken {
            renderToken = p.startToken
            framesToNextBeat = 0
            beatInBar = 0
            beatIndex = 0
            renderBPM = p.bpm
        }
        if p.bpm != renderBPM {
            // Keep our place inside the current beat when the tempo changes mid-beat.
            framesToNextBeat *= renderBPM / p.bpm
            renderBPM = p.bpm
        }

        if p.playing {
            let framesPerBeat = sr * 60 / p.bpm
            let beats = max(1, p.beatsPerBar)
            while framesToNextBeat < Double(frameCount) {
                let offset = max(0, Int(framesToNextBeat))
                if beatInBar >= beats { beatInBar = 0 }
                let pick = p.kit.sound(forBeat: beatInBar, of: beats)

                os_unfair_lock_lock(lock)
                var ref = slots[pick.slot]
                if ref.count == 0 { ref = slots[beatInBar == 0 ? Slot.woodAccent : Slot.woodBeat] }
                events[eventCursor % Self.eventCapacity] = BeatEvent(
                    time: hostSeconds + Double(offset) / sr + p.latency,
                    index: beatIndex,
                    beatInBar: beatInBar,
                    beatsPerBar: beats)
                eventCursor += 1
                os_unfair_lock_unlock(lock)

                startVoice(ref, delay: offset, gain: pick.gain)
                beatIndex += 1
                beatInBar = (beatInBar + 1) % beats
                framesToNextBeat += framesPerBeat
            }
            framesToNextBeat -= Double(frameCount)
        }

        let list = UnsafeMutableAudioBufferListPointer(buffers)
        guard let first = list.first, let out = first.mData?.assumingMemoryBound(to: Float.self) else {
            return noErr
        }
        out.update(repeating: 0, count: frameCount)

        if voiceCount == 0 {
            isSilence.pointee = true
        } else {
            mixVoices(into: out, frameCount: frameCount)
        }
        for b in 1..<list.count {
            if let data = list[b].mData {
                data.copyMemory(from: out, byteCount: frameCount * MemoryLayout<Float>.size)
            }
        }
        return noErr
    }

    private func mixVoices(into out: UnsafeMutablePointer<Float>, frameCount: Int) {
        var v = 0
        while v < voiceCount {
            var voice = voices[v]
            let start = voice.delay
            let frames = min(frameCount - start, voice.count - voice.position)
            if frames > 0 {
                let src = voice.data + voice.position
                let gain = voice.gain
                for i in 0..<frames { out[start + i] += src[i] * gain }
                voice.position += frames
            }
            voice.delay = 0
            if voice.position >= voice.count {
                voiceCount -= 1
                voices[v] = voices[voiceCount]
            } else {
                voices[v] = voice
                v += 1
            }
        }
        for i in 0..<frameCount {
            out[i] = max(-1, min(1, out[i] * 0.9))
        }
    }

    private func startVoice(_ ref: SampleRef, delay: Int, gain: Float) {
        guard let data = ref.data, ref.count > 0 else { return }
        let voice = Voice(data: data, count: ref.count, position: 0, delay: delay, gain: gain)
        if voiceCount < Self.voiceCapacity {
            voices[voiceCount] = voice
            voiceCount += 1
        } else {
            voices[0] = voice
        }
    }

    // MARK: - Helpers

    @inline(__always)
    private func withLock<T>(_ body: () -> T) -> T {
        os_unfair_lock_lock(lock)
        defer { os_unfair_lock_unlock(lock) }
        return body()
    }

    private func startEngineIfNeeded() {
        guard wantsRunning, !engine.isRunning else { return }
        do {
            engine.prepare()
            try engine.start()
        } catch {
            print("Audio engine failed to start: \(error)")
        }
    }

    private func observeSystemEvents() {
        let center = NotificationCenter.default
        center.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
            self?.startEngineIfNeeded()
        }
        center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            if raw == AVAudioSession.InterruptionType.ended.rawValue {
                try? AVAudioSession.sharedInstance().setActive(true)
                self?.startEngineIfNeeded()
            }
        }
        center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] _ in
            let latency = AVAudioSession.sharedInstance().outputLatency
            self?.update { $0.latency = latency }
        }
    }
}
