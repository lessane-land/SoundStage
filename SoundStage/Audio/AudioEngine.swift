import AVFoundation

enum AudioEngineError: Error {
    case trackHasNoAsset
}

/// Owns the single `AVAudioEngine` instance and the spatial-audio signal chain.
///
/// Signal flow (see CLAUDE.md):
///   player → AVAudioUnitEQ → AVAudioUnitReverb → AVAudioEnvironmentNode → mainMixer → output
///
/// Concurrency: this type is deliberately **not** `@MainActor`. Per the project
/// constraints the audio graph is built and mutated off the main thread. All
/// mutable state is guarded by `lock`, so the engine is safe to call from any
/// isolation domain — hence `@unchecked Sendable`. We use an `NSLock` rather
/// than a `DispatchQueue` to honor the "no DispatchQueue" constraint while
/// still serializing access to the (non-Sendable) AVAudioEngine graph.
final class AudioEngine: @unchecked Sendable {

    static let shared = AudioEngine()

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let eq = AVAudioUnitEQ(numberOfBands: 8)
    private let reverb = AVAudioUnitReverb()
    private let environment = AVAudioEnvironmentNode()

    private let lock = NSLock()
    private var currentFile: AVAudioFile?
    private var isConfigured = false

    /// Frame the current segment was scheduled from (advances on seek/pause).
    private var seekFrameOffset: AVAudioFramePosition = 0
    /// Whether a segment is currently scheduled on the player.
    private var hasScheduled = false

    private init() {}

    // MARK: - Lifecycle

    /// Attaches and wires up the node graph. Idempotent.
    func prepare() {
        lock.lock(); defer { lock.unlock() }
        configureIfNeeded()
    }

    /// Configures the audio session and starts the engine.
    func start() throws {
        lock.lock(); defer { lock.unlock() }
        configureIfNeeded()
        try activateSession()
        engine.prepare()
        if !engine.isRunning {
            try engine.start()
        }
    }

    func stop() {
        lock.lock(); defer { lock.unlock() }
        player.stop()
        engine.stop()
    }

    // MARK: - Playback

    /// Total duration of the loaded track in seconds (0 if nothing loaded).
    var duration: TimeInterval {
        lock.lock(); defer { lock.unlock() }
        guard let file = currentFile else { return 0 }
        return Double(file.length) / file.processingFormat.sampleRate
    }

    /// Current playback position in seconds. Frozen while paused/seeking.
    var currentTime: TimeInterval {
        lock.lock(); defer { lock.unlock() }
        guard let file = currentFile else { return 0 }
        return Double(currentFrameLocked()) / file.processingFormat.sampleRate
    }

    /// Loads a track's underlying asset and reconnects the chain to its format.
    func load(track: Track) throws {
        guard let url = track.assetURL else { throw AudioEngineError.trackHasNoAsset }
        let file = try AVAudioFile(forReading: url)

        lock.lock(); defer { lock.unlock() }
        configureIfNeeded()
        // Reconnect the player using the file's native format so sample rates match.
        engine.connect(player, to: eq, format: file.processingFormat)
        player.stop()
        currentFile = file
        seekFrameOffset = 0
        hasScheduled = false
    }

    func play() {
        lock.lock(); defer { lock.unlock() }
        configureIfNeeded()
        try? activateSession()
        startEngineIfNeededLocked()
        if !hasScheduled {
            scheduleSegmentLocked()
        }
        player.play()
    }

    /// Pauses by capturing the position and stopping, so playback resumes from
    /// the same frame. `AVAudioPlayerNode.pause` alone loses `playerTime`, so we
    /// record the offset ourselves.
    func pause() {
        lock.lock(); defer { lock.unlock() }
        seekFrameOffset = currentFrameLocked()
        player.stop()
        hasScheduled = false
    }

    /// Seeks to a time (seconds), preserving the playing/paused state.
    func seek(to time: TimeInterval) {
        lock.lock(); defer { lock.unlock() }
        guard let file = currentFile else { return }
        let sampleRate = file.processingFormat.sampleRate
        let target = AVAudioFramePosition((max(0, time) * sampleRate).rounded())
        let wasPlaying = player.isPlaying

        player.stop()
        seekFrameOffset = min(target, file.length)
        hasScheduled = false
        scheduleSegmentLocked()

        if wasPlaying {
            startEngineIfNeededLocked()
            player.play()
        }
    }

    // MARK: - Presets

    /// Copies a preset's parameters onto the live reverb, EQ and environment nodes.
    func apply(_ preset: Preset) {
        lock.lock(); defer { lock.unlock() }
        configureIfNeeded()

        reverb.loadFactoryPreset(preset.reverbPreset)
        reverb.wetDryMix = clamp(preset.reverbBlend, 0, 1) * 100

        for (index, band) in eq.bands.enumerated() {
            if index < preset.eqBands.count {
                let model = preset.eqBands[index]
                band.filterType = model.filterType
                band.frequency = model.frequency
                band.gain = model.gain
                band.bandwidth = model.bandwidth
                band.bypass = false
            } else {
                band.bypass = true
                band.gain = 0
            }
        }

        environment.reverbParameters.enable = preset.roomSize > 0.05
        environment.reverbParameters.level = -24 + clamp(preset.roomSize, 0, 1) * 24
        environment.reverbParameters.loadFactoryReverbPreset(environmentReverb(for: preset.roomSize))
    }

    // MARK: - Private helpers (must be called with `lock` held)

    private func configureIfNeeded() {
        guard !isConfigured else { return }

        engine.attach(player)
        engine.attach(eq)
        engine.attach(reverb)
        engine.attach(environment)

        engine.connect(player, to: eq, format: nil)
        engine.connect(eq, to: reverb, format: nil)
        engine.connect(reverb, to: environment, format: nil)
        engine.connect(environment, to: engine.mainMixerNode, format: nil)

        reverb.loadFactoryPreset(.mediumHall)
        reverb.wetDryMix = 0

        isConfigured = true
    }

    private func startEngineIfNeededLocked() {
        guard !engine.isRunning else { return }
        engine.prepare()
        try? engine.start()
    }

    /// Schedules the remainder of the file from `seekFrameOffset`.
    private func scheduleSegmentLocked() {
        guard let file = currentFile else { return }
        let frameCount = AVAudioFrameCount(max(0, file.length - seekFrameOffset))
        guard frameCount > 0 else { return }
        player.scheduleSegment(
            file,
            startingFrame: seekFrameOffset,
            frameCount: frameCount,
            at: nil
        )
        hasScheduled = true
    }

    /// Resolves the current playback frame, adding the seek offset to the
    /// player's node time while playing, or the frozen offset otherwise.
    private func currentFrameLocked() -> AVAudioFramePosition {
        guard let file = currentFile else { return 0 }
        if player.isPlaying,
           let nodeTime = player.lastRenderTime,
           let playerTime = player.playerTime(forNodeTime: nodeTime) {
            return min(seekFrameOffset + playerTime.sampleTime, file.length)
        }
        return min(seekFrameOffset, file.length)
    }

    private func activateSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [])
        try session.setActive(true)
    }

    private func environmentReverb(for roomSize: Float) -> AVAudioUnitReverbPreset {
        switch roomSize {
        case ..<0.25: return .smallRoom
        case ..<0.5: return .mediumRoom
        case ..<0.8: return .largeRoom
        default: return .largeHall
        }
    }

    private func clamp(_ value: Float, _ lower: Float, _ upper: Float) -> Float {
        min(max(value, lower), upper)
    }
}
