# Agent instructions for klck

SwiftUI metronome + mic tuner for macOS (and iOS from the same sources). Built with SwiftPM, no Xcode project for macOS.

## Build / test / look

- `make check` builds `Klck.app` and runs the tests. Run it before saying a change works. Output is one line per step plus any errors; exit codes are real.
- `make test` runs tests only. It prints failing assertions and a one-line summary.
- `make snapshot` renders the main window offscreen to `build/snapshot.png` and exits. No window opens and nothing on the desktop moves, so use it freely to check UI changes, then read the PNG. `SIZE=620x2000` shows the whole scroll view (the tuner panel is near the bottom).
- `make run` / `make run-console` open a real window and can grab the mic. Ask the user before running them.
- `make logs` streams the running app's unified log (`NSLog` output).
- `make CONFIG=debug` for a debug bundle.

## Conventions

- Apple's `make` is 3.81: no `.SHELLFLAGS`, and the shell may export `MAKEFLAGS=-j`. Recipes that pipe must `set -o pipefail` inline. `.NOTPARALLEL` keeps targets serial.
- Signing: `build_app.sh` signs with the first Apple Development certificate so the mic permission survives rebuilds. Don't switch it back to ad-hoc.
- Shared sources must build for iOS too. Wrap AppKit code in `#if os(macOS)` (see `Snapshot.swift`).
- Audio timing lives in sample frames inside the `AVAudioSourceNode` render callback (`Audio/AudioEngine.swift`). Don't drive clicks from timers.
- Pitch detection is `Audio/Tuner.swift` (autocorrelation + parabolic interpolation). `Tests/KlckLayoutTests/TunerTests.swift` feeds it synthetic tones; add cases there when you change detection.
- Tests are XCTest. Construct fresh `MetronomeModel()` / `Tuner()` instances.
- Presets live in `~/Library/Application Support/Klck/presets.json`. Don't delete it in scripts.
