# SoundStage — CLAUDE.md

## What this app is
SoundStage is an iOS/iPadOS app (SwiftUI, Swift 6) that applies spatial audio 
presets to music playback. It simulates acoustic environments (warehouse, club, 
festival, etc.) using AVAudioEngine, AVAudioUnitReverb, and AVAudioUnitEQ.

Phase 1 targets the user's local music library (MPMediaLibrary).
Phase 2 will integrate Apple Music via MusicKit.

## Platform
- iOS 17+ and iPadOS 17+
- Xcode 16+
- Swift 6, strict concurrency
- SwiftUI only — no UIKit unless strictly necessary

## Architecture
MVVM. One ViewModel per screen. No massive view files.

- `AudioEngine` — singleton, owns AVAudioEngine instance, loads presets
- `LibraryService` — MPMediaLibrary access and track metadata
- `PresetStore` — defines and persists preset configurations
- `NowPlayingViewModel` — drives the main player screen
- `PresetSelectorViewModel` — drives the preset picker

## Audio Stack
AVAudioEngine pipeline:
  MPMediaPlayer output → AVAudioUnitEQ → AVAudioUnitReverb → 
  AVAudioEnvironmentNode → AVAudioOutputNode

Each Preset is a struct with:
  - reverbPreset: AVAudioUnitReverbPreset
  - reverbBlend: Float (0.0–1.0)
  - eqBands: [AVAudioUnitEQFilterParameters]
  - roomSize: Float
  - label: String
  - description: String

## Presets (Phase 1)
- Club
- Warehouse Berlin
- Festival Outdoor
- Headphone Journey
- Focus
- Running

## File structure
SoundStage/
  App/
    SoundStageApp.swift
  Audio/
    AudioEngine.swift
    PresetStore.swift
    Preset.swift
  Library/
    LibraryService.swift
    Track.swift
  Features/
    NowPlaying/
      NowPlayingView.swift
      NowPlayingViewModel.swift
    PresetSelector/
      PresetSelectorView.swift
      PresetSelectorViewModel.swift
      PresetCardView.swift
  Design/
    DesignTokens.swift    ← colors, typography, spacing constants
    Components/
      WaveformView.swift
      EQCurveView.swift

## Design tokens
Background primary: #0A0A0F
Accent: #6C5CE7
Active state: #FDCB6E (amber)
Text primary: #FFFFFF
Text secondary: #8A8A9A
Card surface: rgba(255,255,255,0.06) — glassmorphism

## What to build first
1. New SwiftUI project, iPhone + iPad target
2. DesignTokens.swift with all colors
3. AudioEngine.swift — bare AVAudioEngine setup, no presets yet
4. Preset.swift — the data model
5. PresetStore.swift — hardcoded array of 6 presets
6. NowPlayingView.swift — static UI, no audio yet
7. Wire them together

## Constraints
- No emojis anywhere in the app
- No third-party dependencies in Phase 1 — pure Apple frameworks only
- All async work uses Swift Concurrency (async/await), no DispatchQueue 
  unless forced by a legacy API
- AVAudioEngine must be initialized on the audio thread, not MainActor
