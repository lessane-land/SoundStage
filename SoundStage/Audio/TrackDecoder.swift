import AVFoundation
import CoreMedia

/// Loads an asset's audio track metadata once, then vends fresh streaming
/// decoders positioned at an arbitrary start frame (used for seeking).
///
/// Created off the main thread; not `Sendable` — only ever touched by
/// `AudioEngine` under its lock.
final class TrackSource {
    /// Standard (deinterleaved float) output format the engine connects with.
    let format: AVAudioFormat
    /// Total frames at `format.sampleRate` (from the asset duration).
    let totalFrames: AVAudioFramePosition

    private let asset: AVURLAsset
    private let assetTrack: AVAssetTrack
    private let sampleRate: Double
    private let channels: Int

    init(url: URL, sampleRate: Double = 44_100, channels: Int = 2) async throws {
        let asset = AVURLAsset(url: url)
        guard let assetTrack = try await asset.loadTracks(withMediaType: .audio).first else {
            throw AudioEngineError.decodingFailed
        }
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate,
                                         channels: AVAudioChannelCount(channels)) else {
            throw AudioEngineError.decodingFailed
        }
        let duration = try await asset.load(.duration)
        let seconds = CMTimeGetSeconds(duration)
        let safeSeconds = (seconds.isFinite && seconds > 0) ? seconds : 0

        self.asset = asset
        self.assetTrack = assetTrack
        self.format = format
        self.sampleRate = sampleRate
        self.channels = channels
        self.totalFrames = AVAudioFramePosition(safeSeconds * sampleRate)
    }

    /// `widthFactor` is the stereo mid/side multiplier (1 = unchanged, 0 = mono,
    /// >1 = wider) baked into the decoded buffers.
    func makeDecoder(fromFrame startFrame: AVAudioFramePosition, widthFactor: Float) throws -> TrackDecoder {
        try TrackDecoder(
            asset: asset,
            track: assetTrack,
            format: format,
            sampleRate: sampleRate,
            channels: channels,
            startFrame: startFrame,
            widthFactor: widthFactor
        )
    }
}

/// Streams PCM chunks from an `AVAssetReader`, one decoded buffer per
/// `nextBuffer()` call, returning `nil` at end of stream.
final class TrackDecoder {
    let format: AVAudioFormat

    private let reader: AVAssetReader
    private let output: AVAssetReaderTrackOutput
    private let channels: Int
    private let widthFactor: Float

    init(asset: AVURLAsset, track: AVAssetTrack, format: AVAudioFormat,
         sampleRate: Double, channels: Int, startFrame: AVAudioFramePosition, widthFactor: Float) throws {
        self.format = format
        self.channels = channels
        self.widthFactor = widthFactor
        self.reader = try AVAssetReader(asset: asset)

        if startFrame > 0 {
            let start = CMTime(value: startFrame, timescale: CMTimeScale(sampleRate))
            reader.timeRange = CMTimeRange(start: start, duration: .positiveInfinity)
        }

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: channels
        ]
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { throw AudioEngineError.decodingFailed }
        reader.add(output)
        guard reader.startReading() else { throw reader.error ?? AudioEngineError.decodingFailed }
        self.output = output
    }

    /// Decodes and returns the next chunk as a deinterleaved float buffer.
    func nextBuffer() -> AVAudioPCMBuffer? {
        while reader.status == .reading {
            guard let sample = output.copyNextSampleBuffer() else { return nil }
            defer { CMSampleBufferInvalidate(sample) }
            guard let block = CMSampleBufferGetDataBuffer(sample) else { continue }

            let byteCount = CMBlockBufferGetDataLength(block)
            let floatCount = byteCount / MemoryLayout<Float>.size
            let frames = AVAudioFrameCount(floatCount / channels)
            guard frames > 0,
                  let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
                  let channelData = buffer.floatChannelData else { continue }

            var interleaved = [Float](repeating: 0, count: floatCount)
            CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: byteCount, destination: &interleaved)

            if channels == 2 {
                // Mid/side stereo widening, cleanly gain-compensated so widening
                // can't push past full scale (no distortion, no clipping).
                let norm = 1.0 / (0.5 + 0.5 * widthFactor)
                for frame in 0..<Int(frames) {
                    let left = interleaved[frame * 2]
                    let right = interleaved[frame * 2 + 1]
                    let mid = (left + right) * 0.5
                    let side = (left - right) * 0.5 * widthFactor
                    channelData[0][frame] = (mid + side) * norm
                    channelData[1][frame] = (mid - side) * norm
                }
            } else {
                for frame in 0..<Int(frames) {
                    for channel in 0..<channels {
                        channelData[channel][frame] = interleaved[frame * channels + channel]
                    }
                }
            }
            buffer.frameLength = frames
            return buffer
        }
        return nil
    }
}
