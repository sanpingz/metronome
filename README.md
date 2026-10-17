# Hoppy Beat 🐸

A metronome for young kids (about 6), for iPhone and iPad. Hoppy the frog hops from lily pad to lily pad and lands exactly on every beat.

## What's inside

- **Hop on the beat.** Each lily pad is one beat in the bar. The pink-flower pad is beat 1. Hoppy squashes on landing, crouches, and jumps so that every landing is a beat. A big number pops up to help kids count. If there are more than 4 pads on a narrow screen, they wrap into a two-row path.
- **Speeds named after animals.** 🐌 Snail · 🐢 Turtle · 🐰 Bunny · 🐎 Pony · 🐆 Cheetah · 🚀 Rocket. The −/+ buttons change the speed by 1; hold them to keep going (30–200 BPM).
- **Six sounds, all generated in code** (no audio files): woodblock, drum, bell, *Song* (a do-mi-sol-do tune, or a scale climb for longer bars), *Ribbit* (a synthesized frog croak), and *Count*, which says "one, two, three…" in the device's language.
- **Clap-along game.** Tap the pond or 👏 on the beat to earn ⭐️. Hits are judged by timing ("Perfect!", "Great!", "A bit early 🐇", "A bit late 🐢"), with streaks 🔥 and confetti.
- **Hats to unlock.** Stars unlock 🎀 🌼 🧢 🎩 👑 for Hoppy. Tap the hat chip to switch.
- **Tap speed 🥁.** Tap the drum a few times and the metronome matches your speed.
- **Day/night.** Light mode is a sunny pond. Dark mode is a night pond with a sleeping moon and fireflies that pulse on the beat.
- Strong haptic on beat 1 and light haptics on the other beats (iPhone). Leave it alone for 30 seconds and Hoppy falls asleep 💤.

## Timing

`MetronomeEngine` renders every sound itself inside one `AVAudioSourceNode`, so beats are sample-accurate. It never uses timers for audio. For each beat it records the host time when the beat will reach the speaker (output latency included). Animation, haptics and clap scoring all read from that one clock, so what the child sees, feels and hears stays in sync.

## Build

```sh
brew install xcodegen          # once
xcodegen generate
open HoppyBeat.xcodeproj
```

Select your team under Signing and change the bundle id (`com.example.hoppybeat`) before running on a device. Requires iOS 17+.

UI smoke test (taps, clapping, tap speed, landscape layout):

```sh
xcodebuild test -project HoppyBeat.xcodeproj -scheme HoppyBeat -destination 'platform=iOS Simulator,name=iPhone 17e'
```

`Tools/make-icon.sh` regenerates the app icon from the same SwiftUI frog the app draws.
