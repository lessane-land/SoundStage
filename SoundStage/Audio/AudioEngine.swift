import AVFoundation

enum AudioEngineError: Error {
    case trackHasNoAsset
    case decodingFailed
}

/// Owns the single `AVAudioEngine` instance and the spatial-audio signal chain.
///
/// Signal flow:
///   player → AVAudioUnitEQ → AVAudioUnitReverb → mainMixer → output
///
/// Library tracks (`MPMediaItem.assetURL`, i.e. `ipod-library://` URLs) can't be
/// opened by `AVAudioFile`, so playback streams PCM chunks decoded by
/// `TrackSource`/`TrackDecoder` (`AVAssetReader`) and schedules them on the
/// player node with look-ahead. This keeps memory flat and start latency low,
/// and lets the EQ/reverb actually process the user's music. DRM/cloud-only
/// items can't be decoded and surface as `decodingFailed`.
///
/// Concurrency: deliberately **not** `@MainActor`. All mutable state is guarded
/// by `lock` (an `NSLock`, to avoid `DispatchQueue`), so it's safe to call from
/// any isolation domain — hence `@unchecked Sendable`. Locking lives only in
/// synchronous helpers; the async `load` does its `await`s lock-free and then
/// hands off to `install`.
final class AudioEngine: @unchecked Sendable {

    static let shared = AudioEngine()

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let eq = AVAudioUnitEQ(numberOfBands: 8)
    private let reverb = AVAudioUnitReverb()

    private let lock = NSLock()
    private let sampleRate = 44_100.0
    /// Single processing format for the whole chain, so EQ/reverb never get
    /// weakened by a sample-rate mismatch. Matches the decoder's output.
    private let processingFormat = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
    /// Buffers scheduled ahead of the playhead.
    private let prefetchCount = 3

    private var source: TrackSource?
    private var decoder: TrackDecoder?
    private var isConfigured = false

    private var totalFrames: AVAudioFramePosition = 0
    /// Stereo mid/side width baked into decoded buffers (1 = unchanged).
    private var currentWidthFactor: Float = 1.0
    /// Reverb factory preset currently loaded, so we only reload (which clicks)
    /// when the room-size bucket actually changes — not on every slider tick.
    private var currentReverbPreset: AVAudioUnitReverbPreset?

    // 16D rotation: the signature spinning-around-your-head effect, made by
    // sweeping the stereo pan with an LFO.
    private var rotationSpeed: Double = 0      // revolutions per second; 0 = off
    private var rotationDepth: Float = 0.95    // how wide the swing goes (0...1)
    private var rotationTask: Task<Void, Never>?
    /// Frame the current decoder started at (advances on seek).
    private var baseFrame: AVAudioFramePosition = 0
    /// Monotonic position cache so reported time never snaps backward.
    private var lastReportedFrame: AVAudioFramePosition = 0
    /// Bumped on every load/seek so stale completion callbacks are ignored.
    private var generation = 0
    /// Set when the decoder is exhausted (so end-of-track can be reported).
    private var atEnd = false

    private init() {}

    // MARK: - Lifecycle

    func prepare() {
        lock.lock(); defer { lock.unlock() }
        configureIfNeeded()
    }

    func stop() {
        lock.lock(); defer { lock.unlock() }
        player.stop()
        engine.stop()
    }

    // MARK: - Playback state

    var duration: TimeInterval {
        lock.lock(); defer { lock.unlock() }
        guard source != nil else { return 0 }
        return Double(totalFrames) / sampleRate
    }

    var currentTime: TimeInterval {
        lock.lock(); defer { lock.unlock() }
        guard source != nil else { return 0 }
        return Double(currentFrameLocked()) / sampleRate
    }

    // MARK: - Loading

    /// Loads a track for streaming playback. Throws if it has no asset or can't
    /// be decoded (e.g. DRM). Performs its `await`s lock-free, then installs.
    func load(track: Track) async throws {
        guard let url = track.assetURL else { throw AudioEngineError.trackHasNoAsset }
        let source = try await TrackSource(url: url, sampleRate: sampleRate)
        let decoder = try source.makeDecoder(fromFrame: 0, widthFactor: snapshotWidthFactor())
        install(source: source, decoder: decoder)
    }

    /// Reads the current width factor under the lock (safe from the async load).
    private func snapshotWidthFactor() -> Float {
        lock.lock(); defer { lock.unlock() }
        return currentWidthFactor
    }

    private func install(source: TrackSource, decoder: TrackDecoder) {
        lock.lock(); defer { lock.unlock() }
        configureIfNeeded()
        engine.connect(player, to: eq, format: processingFormat)
        player.stop()
        generation += 1
        self.source = source
        self.decoder = decoder
        totalFrames = source.totalFrames
        baseFrame = 0
        lastReportedFrame = 0
        atEnd = false
        primeLocked()
    }

    // MARK: - Transport

    func play() {
        lock.lock(); defer { lock.unlock() }
        configureIfNeeded()
        try? activateSession()
        startEngineIfNeededLocked()
        player.play()
    }

    func pause() {
        lock.lock(); defer { lock.unlock() }
        player.pause()
    }

    func seek(to time: TimeInterval) {
        lock.lock(); defer { lock.unlock() }
        guard let source else { return }
        let target = AVAudioFramePosition((max(0, time) * sampleRate).rounded())
        let frame = min(target, totalFrames)
        let wasPlaying = player.isPlaying

        player.stop()
        generation += 1
        baseFrame = frame
        lastReportedFrame = frame
        atEnd = false
        decoder = try? source.makeDecoder(fromFrame: frame, widthFactor: currentWidthFactor)
        primeLocked()

        if wasPlaying {
            startEngineIfNeededLocked()
            player.play()
        }
    }

    // MARK: - Presets

    /// Applies the full preset, including stereo width (which re-decodes). Use
    /// when committing a preset.
    func apply(_ preset: Preset) {
        lock.lock(); defer { lock.unlock() }
        configureIfNeeded()
        applyReverbAndEQLocked(preset, reloadIR: true)

        // Stereo Width is baked into decoded buffers. Gentle range (0.6...1.4)
        // so widening stays clean. If it changed, re-decode from current spot.
        let newWidth = 0.6 + clamp(preset.stereoWidth, 0, 1) * 0.8
        if abs(newWidth - currentWidthFactor) > 0.01 {
            currentWidthFactor = newWidth
            reloadDecoderAtCurrentPositionLocked()
        }
    }

    /// Applies only the live-safe params (reverb space/depth + EQ), skipping the
    /// width re-decode. Used for smooth slider previews while dragging.
    func applyEffects(_ preset: Preset) {
        lock.lock(); defer { lock.unlock() }
        configureIfNeeded()
        applyReverbAndEQLocked(preset, reloadIR: false)
    }

    // MARK: - 16D rotation

    /// Sets the 16D spin rate (revolutions per second). 0 disables it and
    /// recenters. ~0.05–0.25 rev/s is the typical "8D/16D" sweet spot.
    func setRotation(speed: Double) {
        lock.lock()
        rotationSpeed = max(0, speed)
        let active = rotationSpeed > 0
        let alreadyRunning = rotationTask != nil
        lock.unlock()

        if active && !alreadyRunning {
            startRotationLoop()
        } else if !active {
            stopRotationLoop()
        }
    }

    private func startRotationLoop() {
        lock.lock()
        guard rotationTask == nil else { lock.unlock(); return }
        rotationTask = Task.detached { [weak self] in
            var angle = 0.0
            var last = Date()
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(16))
                guard let self else { return }
                let now = Date()
                let dt = now.timeIntervalSince(last)
                last = now
                let (speed, depth) = self.rotationParams()
                guard speed > 0 else { continue }
                angle += 2 * Double.pi * speed * dt
                self.setMixerPan(Float(sin(angle)) * depth)
            }
        }
        lock.unlock()
    }

    private func stopRotationLoop() {
        lock.lock()
        rotationTask?.cancel()
        rotationTask = nil
        lock.unlock()
        setMixerPan(0)
    }

    private func rotationParams() -> (Double, Float) {
        lock.lock(); defer { lock.unlock() }
        return (rotationSpeed, rotationDepth)
    }

    private func setMixerPan(_ pan: Float) {
        lock.lock(); defer { lock.unlock() }
        engine.mainMixerNode.pan = max(-1, min(1, pan))
    }

    private func applyReverbAndEQLocked(_ preset: Preset, reloadIR: Bool) {
        // Room Size selects the reverberant space; Reverb Depth the wet amount.
        // Reloading the IR clicks, so only do it on commit (never while dragging).
        if reloadIR {
            let newReverbPreset = Self.reverbPreset(forRoomSize: preset.roomSize)
            if newReverbPreset != currentReverbPreset {
                reverb.loadFactoryPreset(newReverbPreset)
                currentReverbPreset = newReverbPreset
            }
        }
        reverb.wetDryMix = clamp(preset.reverbBlend, 0, 1) * 100

        for (index, band) in eq.bands.enumerated() {
            if index < preset.eqBands.count {
                let model = preset.eqBands[index]
                band.filterType = model.filterType
                band.frequency = model.frequency
                // Halve the boosts/cuts so loud masters don't clip.
                band.gain = model.gain * 0.5
                band.bandwidth = model.bandwidth
                band.bypass = false
            } else {
                band.bypass = true
                band.gain = 0
            }
        }
    }

    private static func reverbPreset(forRoomSize roomSize: Float) -> AVAudioUnitReverbPreset {
        switch roomSize {
        case ..<0.2: return .smallRoom
        case ..<0.4: return .mediumRoom
        case ..<0.6: return .largeRoom
        case ..<0.8: return .largeHall
        default: return .cathedral
        }
    }

    /// Rebuilds the decoder at the current playhead (used when stereo width
    /// changes), preserving the playing/paused state.
    private func reloadDecoderAtCurrentPositionLocked() {
        guard let source else { return }
        let frame = currentFrameLocked()
        let wasPlaying = player.isPlaying

        player.stop()
        generation += 1
        baseFrame = frame
        lastReportedFrame = frame
        atEnd = false
        decoder = try? source.makeDecoder(fromFrame: frame, widthFactor: currentWidthFactor)
        primeLocked()

        if wasPlaying {
            startEngineIfNeededLocked()
            player.play()
        }
    }

    // MARK: - Feeding (call with `lock` held)

    private func primeLocked() {
        for _ in 0..<prefetchCount {
            feedLocked(generation: generation)
        }
    }

    private func feedLocked(generation gen: Int) {
        guard gen == generation, let decoder else { return }
        guard let buffer = decoder.nextBuffer() else {
            atEnd = true
            return
        }
        player.scheduleBuffer(buffer, completionCallbackType: .dataConsumed) { [weak self] _ in
            guard let self else { return }
            // Hop off the audio thread; a detached task avoids re-entering the
            // lock synchronously during stop().
            Task.detached { self.feedNext(expecting: gen) }
        }
    }

    /// Called (off-thread) when a scheduled buffer has been consumed.
    private func feedNext(expecting gen: Int) {
        lock.lock(); defer { lock.unlock() }
        feedLocked(generation: gen)
    }

    // MARK: - Private helpers (call with `lock` held)

    private func configureIfNeeded() {
        guard !isConfigured else { return }

        engine.attach(player)
        engine.attach(eq)
        engine.attach(reverb)

        engine.connect(player, to: eq, format: processingFormat)
        engine.connect(eq, to: reverb, format: processingFormat)
        engine.connect(reverb, to: engine.mainMixerNode, format: processingFormat)

        reverb.loadFactoryPreset(.mediumHall)
        currentReverbPreset = .mediumHall
        reverb.wetDryMix = 0

        // Headroom so EQ boosts + reverb + widening can't clip into distortion.
        eq.globalGain = -3
        engine.mainMixerNode.outputVolume = 0.85

        isConfigured = true
    }

    private func activateSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [])
        try session.setActive(true)
    }

    private func startEngineIfNeededLocked() {
        guard !engine.isRunning else { return }
        engine.prepare()
        try? engine.start()
    }

    private func currentFrameLocked() -> AVAudioFramePosition {
        if player.isPlaying,
           let nodeTime = player.lastRenderTime,
           let playerTime = player.playerTime(forNodeTime: nodeTime) {
            let frame = min(baseFrame + playerTime.sampleTime, totalFrames)
            lastReportedFrame = max(lastReportedFrame, frame)
        } else if atEnd {
            // Decoder drained and the queue has finished playing.
            lastReportedFrame = totalFrames
        }
        return min(lastReportedFrame, totalFrames)
    }

    private func clamp(_ value: Float, _ lower: Float, _ upper: Float) -> Float {
        min(max(value, lower), upper)
    }
}
