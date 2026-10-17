import SwiftUI

/// The sound Hoppy plays on each beat.
enum Kit: String, CaseIterable, Identifiable {
    case wood, drum, bell, piano, frog, voice

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .wood: "🪵"
        case .drum: "🥁"
        case .bell: "🔔"
        case .piano: "🎹"
        case .frog: "🐸"
        case .voice: "🗣️"
        }
    }

    var name: String {
        switch self {
        case .wood: "Tock"
        case .drum: "Drum"
        case .bell: "Bell"
        case .piano: "Song"
        case .frog: "Ribbit"
        case .voice: "Count"
        }
    }

    var tint: Color {
        switch self {
        case .wood: Color(hex: 0xC98B4F)
        case .drum: Color(hex: 0xFF6B6B)
        case .bell: Color(hex: 0xFFC93C)
        case .piano: Color(hex: 0x8E7CFF)
        case .frog: Color(hex: 0x5CC94A)
        case .voice: Color(hex: 0x3BB8F0)
        }
    }

    /// Called on the audio thread: must not allocate.
    func sound(forBeat beat: Int, of beats: Int) -> (slot: Int, gain: Float) {
        let accent = beat == 0
        switch self {
        case .wood: return accent ? (Slot.woodAccent, 1) : (Slot.woodBeat, 0.9)
        case .drum: return accent ? (Slot.drumAccent, 1) : (Slot.drumBeat, 0.85)
        case .bell: return accent ? (Slot.bellAccent, 1) : (Slot.bellBeat, 0.85)
        case .frog: return accent ? (Slot.frogAccent, 1) : (Slot.frogBeat, 0.9)
        case .voice: return (Slot.voiceBase + min(beat, 7), accent ? 1 : 0.85)
        case .piano:
            // Short bars play an arpeggio (do-mi-sol-do), long bars climb the scale.
            let semitone: Int
            if beats == 2 {
                semitone = beat == 0 ? 0 : 7
            } else if beats <= 4 {
                switch beat {
                case 0: semitone = 0
                case 1: semitone = 4
                case 2: semitone = 7
                default: semitone = 12
                }
            } else {
                switch beat {
                case 0: semitone = 0
                case 1: semitone = 2
                case 2: semitone = 4
                case 3: semitone = 5
                case 4: semitone = 7
                case 5: semitone = 9
                case 6: semitone = 11
                default: semitone = 12
                }
            }
            return (Slot.pianoBase + semitone, accent ? 1 : 0.8)
        }
    }
}

/// Tempo presets a six-year-old can understand without reading numbers.
struct SpeedAnimal: Identifiable, Equatable {
    let emoji: String
    let name: String
    let bpm: Int
    var id: String { name }

    static let all = [
        SpeedAnimal(emoji: "🐌", name: "Snail", bpm: 60),
        SpeedAnimal(emoji: "🐢", name: "Turtle", bpm: 76),
        SpeedAnimal(emoji: "🐰", name: "Bunny", bpm: 96),
        SpeedAnimal(emoji: "🐎", name: "Pony", bpm: 120),
        SpeedAnimal(emoji: "🐆", name: "Cheetah", bpm: 144),
        SpeedAnimal(emoji: "🚀", name: "Rocket", bpm: 176),
    ]

    static func nearest(to bpm: Int) -> SpeedAnimal {
        all.min { abs($0.bpm - bpm) < abs($1.bpm - bpm) } ?? all[2]
    }
}

/// Rewards for clapping on the beat.
enum Hat: Int, CaseIterable {
    case none, bow, daisy, cap, topHat, crown

    var emoji: String? {
        switch self {
        case .none: nil
        case .bow: "🎀"
        case .daisy: "🌼"
        case .cap: "🧢"
        case .topHat: "🎩"
        case .crown: "👑"
        }
    }

    var starsNeeded: Int {
        switch self {
        case .none: 0
        case .bow: 5
        case .daisy: 12
        case .cap: 20
        case .topHat: 35
        case .crown: 60
        }
    }

    static func unlocked(stars: Int) -> [Hat] {
        allCases.filter { stars >= $0.starsNeeded }
    }

    static func next(after stars: Int) -> Hat? {
        allCases.first { $0.starsNeeded > stars }
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
