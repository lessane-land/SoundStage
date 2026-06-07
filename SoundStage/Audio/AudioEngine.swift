import AVFoundation
import CoreMedia

enum AudioEngineError: Error {
    case trackHasNoAsset
    case decodingFailed
}

/// Owns the single `AVAudioEngine` instance and the spatial-audio signal chain.
///
/// Signal flow:
///   player → AVAudioUnitEQ → AVAudioUnitReverb → mainMixer → output
///
/// Library tracks (`MPMediaItem.assetURL`, i.e. `ipod-library://` URLs) cannot
/// be opened by `AVAudioFile`, so we decode them up front with `AVAssetReader`
/// into a single PCM buffer and schedule that on the player node. This is what
/// lets the EQ/reverb actually process the user's music. (DRM-protected or
/// cloud-only items can't be decoded and surface as `decodingFailed`.)
///
/// Concurrency: this type is deliberately **not** `@MainActor`. All mutable
/// state is guarded by `lock` (an `NSLock`, to avoid `DispatchQueue`), so it's
/// safe to call from any isolation domain — hence `@unchecked Sendable`.
final class AudioEngine: @unchecked Sendable {

    static let shared = AudioEngine()

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let eq = AVAudioUnitEQ(numberOfBands: 8)
    private let reverb = AVAudioUnitReverb()

    private let lock = NSLock()
    private var currentBuffer: AVAudioPCMBuffer?
    private var isConfigured = false

    /// Frame the current segment was scheduled from (advances on seek/pause).
    private var seekFrameOffset: AVAudioFramePosition = 0
    /// Whether a segment is currently scheduled on the player.
    private var hasScheduled = false
    /// Monotonic position cache so the reported time doesn't snap back to the
    /// segment start when the player stops at the end of a buffer.
    private var lastReportedFrame: AVAudioFramePosition = 0

    private init() {}

    // MARK: - Lifecycle

    func prepare() {
        lock.lock(); defer { lock.unlock() }
        configureIfNeeded()
    }

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

    // MARK: - Playback state

    /// Total duration of the loaded track in seconds (0 if nothing loaded).
    var duration: TimeInterval {
        lock.lock(); defer { lock.unlock() }
        guard let buffer = currentBuffer else { return 0 }
        return Double(buffer.frameLength) / buffer.format.sampleRate
    }

    /// Current playback position in seconds. Frozen while paused/seeking.
    var currentTime: TimeInterval {
        lock.lock(); defer { lock.unlock() }
        guard let buffer = currentBuffer else { return 0 }
        return Double(currentFrameLocked()) / buffer.format.sampleRate
    }

    // MARK: - Loading

    /// Decodes a track's asset into a PCM buffer and readies it for playback.
    /// Throws if the track has no asset or can't be decoded (e.g. DRM).
    func load(track: Track) async throws {
        guard let url = track.assetURL else { throw AudioEngineError.trackHasNoAsset }
        let buffer = try await Self.decode(url: url)

        lock.lock(); defer { lock.unlock() }
        configureIfNeeded()
        engine.connect(player, to: eq, format: buffer.format)
        player.stop()
        currentBuffer = buffer
        seekFrameOffset = 0
        lastReportedFrame = 0
        hasScheduled = false
    }

    // MARK: - Transport

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
    /// the same frame.
    func pause() {
        lock.lock(); defer { lock.unlock() }
        seekFrameOffset = currentFrameLocked()
        lastReportedFrame = seekFrameOffset
        player.stop()
        hasScheduled = false
    }

    /// Seeks to a time (seconds), preserving the playing/paused state.
    func seek(to time: TimeInterval) {
        lock.lock(); defer { lock.unlock() }
        guard let buffer = currentBuffer else { return }
        let sampleRate = buffer.format.sampleRate
        let target = AVAudioFramePosition((max(0, time) * sampleRate).rounded())
        let wasPlaying = player.isPlaying

        player.stop()
        seekFrameOffset = min(target, AVAudioFramePosition(buffer.frameLength))
        lastReportedFrame = seekFrameOffset
        hasScheduled = false
        scheduleSegmentLocked()

        if wasPlaying {
            startEngineIfNeededLocked()
            player.play()
        }
    }

    // MARK: - Presets

    /// Copies a preset's parameters onto the live reverb and EQ nodes.
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
    }

    // MARK: - Private helpers (call with `lock` held)

    private func configureIfNeeded() {
        guard !isConfigured else { return }

        engine.attach(player)
        engine.attach(eq)
        engine.attach(reverb)

        engine.connect(player, to: eq, format: nil)
        engine.connect(eq, to: reverb, format: nil)
        engine.connect(reverb, to: engine.mainMixerNode, format: nil)

        reverb.loadFactoryPreset(.mediumHall)
        reverb.wetDryMix = 0

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

    /// Schedules the remainder of the buffer from `seekFrameOffset`.
    private func scheduleSegmentLocked() {
        guard let buffer = currentBuffer else { return }
        let segment: AVAudioPCMBuffer
        if seekFrameOffset <= 0 {
            segment = buffer
        } else {
            guard let sliced = Self.slice(buffer, from: AVAudioFrameCount(seekFrameOffset)) else { return }
            segment = sliced
        }
        guard segment.frameLength > 0 else { return }
        player.scheduleBuffer(segment, at: nil, options: [], completionHandler: nil)
        hasScheduled = true
    }

    private func currentFrameLocked() -> AVAudioFramePosition {
        guard let buffer = currentBuffer else { return 0 }
        let length = AVAudioFramePosition(buffer.frameLength)
        if player.isPlaying,
           let nodeTime = player.lastRenderTime,
           let playerTime = player.playerTime(forNodeTime: nodeTime) {
            let frame = min(seekFrameOffset + playerTime.sampleTime, length)
            lastReportedFrame = max(lastReportedFrame, frame)
        }
        return min(lastReportedFrame, length)
    }

    private func clamp(_ value: Float, _ lower: Float, _ upper: Float) -> Float {
        min(max(value, lower), upper)
    }

    // MARK: - Decoding

    /// Decodes an audio asset URL into a standard float PCM buffer (stereo,
    /// 44.1kHz). Reads in chunks straight into the destination buffer.
    private static func decode(url: URL) async throws -> AVAudioPCMBuffer {
        let asset = AVURLAsset(url: url)
        guard let assetTrack = try await asset.loadTracks(withMediaType: .audio).first else {
            throw AudioEngineError.decodingFailed
        }

        let sampleRate = 44_100.0
        let channels = 2
        let reader = try AVAssetReader(asset: asset)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: channels
        ]
        let output = AVAssetReaderTrackOutput(track: assetTrack, outputSettings: settings)
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { throw AudioEngineError.decodingFailed }
        reader.add(output)
        guard reader.startReading() else { throw reader.error ?? AudioEngineError.decodingFailed }

        // Preallocate from the asset duration (+ padding for rounding), with a
        // bounded fallback if the duration is unknown/indefinite (avoids NaN).
        let duration = try await asset.load(.duration)
        let seconds = CMTimeGetSeconds(duration)
        let safeSeconds = (seconds.isFinite && seconds > 0) ? seconds : 600
        let estimatedFrames = AVAudioFrameCount(safeSeconds * sampleRate) + 8_192
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: AVAudioChannelCount(channels)),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: estimatedFrames),
              let channelData = buffer.floatChannelData else {
            throw AudioEngineError.decodingFailed
        }

        var writeFrame = 0
        let capacity = Int(estimatedFrames)

        while reader.status == .reading, let sample = output.copyNextSampleBuffer() {
            if let blockBuffer = CMSampleBufferGetDataBuffer(sample) {
                let byteCount = CMBlockBufferGetDataLength(blockBuffer)
                let floatCount = byteCount / MemoryLayout<Float>.size
                var interleaved = [Float](repeating: 0, count: floatCount)
                CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: byteCount, destination: &interleaved)

                let frames = floatCount / channels
                let writable = min(frames, capacity - writeFrame)
                if writable > 0 {
                    for frame in 0..<writable {
                        for channel in 0..<channels {
                            channelData[channel][writeFrame + frame] = interleaved[frame * channels + channel]
                        }
                    }
                    writeFrame += writable
                }
            }
            CMSampleBufferInvalidate(sample)
        }

        if reader.status == .failed {
            throw reader.error ?? AudioEngineError.decodingFailed
        }
        guard writeFrame > 0 else { throw AudioEngineError.decodingFailed }

        buffer.frameLength = AVAudioFrameCount(writeFrame)
        return buffer
    }

    /// Copies the buffer from `start` to the end into a fresh buffer.
    private static func slice(_ buffer: AVAudioPCMBuffer, from start: AVAudioFrameCount) -> AVAudioPCMBuffer? {
        let total = buffer.frameLength
        guard start < total else { return nil }
        let count = total - start
        guard let out = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: count),
              let src = buffer.floatChannelData,
              let dst = out.floatChannelData else {
            return nil
        }
        out.frameLength = count
        let channels = Int(buffer.format.channelCount)
        for channel in 0..<channels {
            for frame in 0..<Int(count) {
                dst[channel][frame] = src[channel][Int(start) + frame]
            }
        }
        return out
    }
}
