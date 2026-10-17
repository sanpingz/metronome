import AVFoundation

/// Pre-renders spoken counts ("one", "two", …) in the device's language so they can be mixed
/// sample-accurately like any other click. All state is touched on the main queue only.
final class VoiceCounter {
    private let synthesizer = AVSpeechSynthesizer()
    private var voice: AVSpeechSynthesisVoice?
    private var words: [String] = []
    private var clips: [[Float]] = []
    private var pending: [Float] = []
    private var pendingRate: Double = 22_050
    private var wordToken = 0
    private var watchdog: DispatchWorkItem?
    private var completion: (([[Float]]) -> Void)?

    func renderCounts(upTo count: Int, completion: @escaping ([[Float]]) -> Void) {
        let chosen = AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
            ?? AVSpeechSynthesisVoice(language: "en-US")
        voice = chosen
        let formatter = NumberFormatter()
        formatter.numberStyle = .spellOut
        formatter.locale = Locale(identifier: chosen?.language ?? "en-US")
        words = (1...count).map { formatter.string(from: NSNumber(value: $0)) ?? "\($0)" }
        clips = []
        self.completion = completion
        renderNext()
    }

    private func renderNext() {
        guard clips.count < words.count else {
            completion?(clips)
            completion = nil
            return
        }
        wordToken += 1
        let token = wordToken
        pending = []

        let utterance = AVSpeechUtterance(string: words[clips.count])
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.05
        utterance.pitchMultiplier = 1.15
        armWatchdog(token, after: 2.5)

        synthesizer.write(utterance) { [weak self] buffer in
            let pcm = buffer as? AVAudioPCMBuffer
            let samples = pcm.map(VoiceCounter.monoSamples) ?? []
            let rate = pcm?.format.sampleRate ?? 22_050
            DispatchQueue.main.async {
                guard let self, token == self.wordToken else { return }
                if samples.isEmpty {
                    self.finishWord(token)
                } else {
                    self.pending += samples
                    self.pendingRate = rate
                    // Some iOS versions never send the final empty buffer, so end on silence too.
                    self.armWatchdog(token, after: 0.6)
                }
            }
        }
    }

    private func armWatchdog(_ token: Int, after seconds: Double) {
        watchdog?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.finishWord(token) }
        watchdog = item
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: item)
    }

    private func finishWord(_ token: Int) {
        guard token == wordToken else { return }
        wordToken += 1
        watchdog?.cancel()
        clips.append(Self.polish(pending, from: pendingRate))
        renderNext()
    }

    private static func monoSamples(_ buffer: AVAudioPCMBuffer) -> [Float] {
        let n = Int(buffer.frameLength)
        guard n > 0 else { return [] }
        if let data = buffer.floatChannelData {
            return Array(UnsafeBufferPointer(start: data[0], count: n))
        }
        if let data = buffer.int16ChannelData {
            return (0..<n).map { Float(data[0][$0]) / 32_768 }
        }
        if let data = buffer.int32ChannelData {
            return (0..<n).map { Float(data[0][$0]) / 2_147_483_648 }
        }
        return []
    }

    /// Trims the synthesizer's leading/trailing silence so the word starts right on the beat,
    /// then resamples to the engine rate.
    private static func polish(_ x: [Float], from rate: Double) -> [Float] {
        let peak = x.reduce(0) { max($0, abs($1)) }
        guard peak > 0.001 else { return [] }
        let threshold = peak * 0.025
        guard let first = x.firstIndex(where: { abs($0) > threshold }),
              let last = x.lastIndex(where: { abs($0) > threshold }) else { return [] }
        let start = max(0, first - Int(rate * 0.004))
        let end = min(x.count, last + Int(rate * 0.03))
        let trimmed = Array(x[start..<end])

        let target = MetronomeEngine.sampleRate
        let step = rate / target
        let outCount = Int(Double(trimmed.count) / step)
        var out = [Float](repeating: 0, count: outCount)
        for i in 0..<outCount {
            let pos = Double(i) * step
            let j = Int(pos)
            let frac = Float(pos - Double(j))
            let a = trimmed[j]
            let b = j + 1 < trimmed.count ? trimmed[j + 1] : a
            out[i] = a + (b - a) * frac
        }
        SoundSynth.fadeOut(&out, seconds: 0.02)
        SoundSynth.normalize(&out, peak: 0.95)
        return out
    }
}
