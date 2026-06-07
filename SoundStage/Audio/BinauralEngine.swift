import AVFoundation

/// Generates binaural beats in real time: a pure tone in each ear whose
/// frequencies differ by the "beat" rate, so the brain perceives a pulse at
/// that rate. No source audio, no DRM — entirely synthesized.
///
/// Not `@MainActor`: the render block runs on the audio thread. Parameters are
/// plain values read there (benign races, smoothed), so it's `@unchecked
/// Sendable`.
final class BinauralEngine: @unchecked Sendable {

    static let shared = BinauralEngine()

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private let sampleRate: Double = 44_100
    private var isConfigured = false

    // Audio-thread state.
    private var phaseLeft = 0.0
    private var phaseRight = 0.0
    private var amplitude = 0.0

    // Parameters (set from the main actor, read on the audio thread).
    private var carrierHz = 200.0
    private var beatHz = 10.0
    private var targetAmplitude = 0.0

    private init() {}

    func setTone(carrier: Double, beat: Double) {
        carrierHz = max(50, carrier)
        beatHz = max(0.5, beat)
    }

    func play() {
        configureIfNeeded()
        activateSession()
        if !engine.isRunning {
            engine.prepare()
            try? engine.start()
        }
        targetAmplitude = 0.30
    }

    func pause() {
        targetAmplitude = 0.0
    }

    func stop() {
        targetAmplitude = 0.0
        engine.stop()
    }

    private func configureIfNeeded() {
        guard !isConfigured else { return }
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else { return }

        let node = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, ablPointer in
            guard let self else { return noErr }
            return self.render(frameCount: frameCount, abl: ablPointer)
        }
        sourceNode = node
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.9
        isConfigured = true
    }

    private func render(frameCount: AVAudioFrameCount, abl ablPointer: UnsafeMutablePointer<AudioBufferList>) -> OSStatus {
        let buffers = UnsafeMutableAudioBufferListPointer(ablPointer)
        guard buffers.count >= 2,
              let left = buffers[0].mData?.assumingMemoryBound(to: Float.self),
              let right = buffers[1].mData?.assumingMemoryBound(to: Float.self) else {
            return noErr
        }

        let carrier = carrierHz
        let beat = beatHz
        let incLeft = 2 * Double.pi * (carrier - beat / 2) / sampleRate
        let incRight = 2 * Double.pi * (carrier + beat / 2) / sampleRate
        let target = targetAmplitude
        let frames = Int(frameCount)
        let ampStep = (target - amplitude) / Double(max(1, frames))
        let twoPi = 2 * Double.pi

        for frame in 0..<frames {
            amplitude += ampStep
            let level = Float(amplitude)
            left[frame] = Float(sin(phaseLeft)) * level
            right[frame] = Float(sin(phaseRight)) * level
            phaseLeft += incLeft
            if phaseLeft > twoPi { phaseLeft -= twoPi }
            phaseRight += incRight
            if phaseRight > twoPi { phaseRight -= twoPi }
        }
        amplitude = target
        return noErr
    }

    private func activateSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)
    }
}
