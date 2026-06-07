# SoundStage

SoundStage is an iOS/iPadOS app (SwiftUI, Swift 6) that applies spatial-audio
presets to music playback. It simulates acoustic environments — warehouse,
club, festival, and more — using `AVAudioEngine`, `AVAudioUnitReverb` and
`AVAudioUnitEQ`.

- **Phase 1** targets the user's local music library (`MPMediaLibrary`).
- **Phase 2** will integrate Apple Music via MusicKit.

## Requirements

- iOS 17+ / iPadOS 17+
- Xcode 16+
- Swift 6 (strict concurrency)

## Getting started

Open `SoundStage.xcodeproj` in Xcode 16 and run the **SoundStage** scheme on an
iPhone or iPad simulator (or device). The project uses Xcode 16
file-system-synchronized groups, so the folder tree under `SoundStage/` is the
source of truth — add a file to a folder and it is picked up automatically, no
project edits required.

> Library playback requires a device/simulator with music in the local library
> and the "Apple Music" (media library) permission, prompted on first use.

## Architecture

MVVM, one view model per screen.

| Type | Role |
| --- | --- |
| `AudioEngine` | Singleton. Owns the `AVAudioEngine` graph and applies presets. Not `@MainActor` — the audio graph is built and mutated off the main thread. |
| `LibraryService` | `MPMediaLibrary` access and track metadata. |
| `PresetStore` | Defines the six built-in presets and persists the selection. |
| `NowPlayingViewModel` | Drives the main player screen. |
| `PresetSelectorViewModel` | Drives the preset picker. |

### Audio signal chain

```
player → AVAudioUnitEQ → AVAudioUnitReverb → AVAudioEnvironmentNode → mainMixer → output
```

Each `Preset` carries a reverb voicing + blend, a parametric EQ shape
(`[EQBand]`) and a perceptual room size, all as `Sendable` value types.

## Project layout

```
SoundStage/
  App/                 SoundStageApp.swift — entry point
  Audio/               AudioEngine, Preset, PresetStore
  Library/             LibraryService, Track
  Features/
    NowPlaying/        player screen + view model
    PresetSelector/    preset picker, cards + view model
  Design/
    DesignTokens.swift colors, typography, spacing
    Components/        WaveformView, EQCurveView
  Resources/           Assets.xcassets
```

## Presets (Phase 1)

Club · Warehouse Berlin · Festival Outdoor · Headphone Journey · Focus · Running

## Constraints

- No third-party dependencies — pure Apple frameworks.
- No emojis anywhere in the app.
- All async work uses Swift Concurrency (`async`/`await`).
