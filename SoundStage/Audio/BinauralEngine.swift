import AVFoundation

/// Generates, in real time and entirely from synthesis (no files, no DRM):
/// - **binaural beats**: a tone in each ear, detuned by the beat rate (clean,
///   straight to the mixer);
/// - an **ambient soundscape** (rain/ocean/forest/wind/noise), generated with
///   independent noise per ear (enveloping) and run through **reverb** so it
///   feels like a real space around you;
/// - **spatial audio**: a gentle circling emphasis, head-anchored via AirPods.
///
/// `@unchecked Sendable`: the render blocks run on the audio thread and read
/// plain parameter values (benign races).
final class BinauralEngine: @unchecked Sendable {

    static let shared = BinauralEngine()

    private let engine = AVAudioEngine()
    private var tonesNode: AVAudioSourceNode?
    private var ambientNode: AVAudioSourceNode?
    private let reverb = AVAudioUnitReverb()
    private let sampleRate: Double = 44_100
    private var isConfigured = false

    // Parameters.
    private var carrierHz = 120.0
    private var beatHz = 10.0
    private var targetAmplitude = 0.0
    private var ambientType = 0
    private var ambientLevel = 0.0
    private var spatialAmount = 0.0
    private var headYaw = 0.0    // from AirPods; always applied (0 if unavailable)

    // Tones audio-thread state.
    private var phaseLeft = 0.0
    private var phaseRight = 0.0
    private var tonesAmp = 0.0

    // Ambient audio-thread state (independent per ear).
    private var rng: UInt32 = 0x9E3779B9
    private var lpA_L: Float = 0, lpA_R: Float = 0
    private var lpB_L: Float = 0, lpB_R: Float = 0
    private var brownL: Float = 0, brownR: Float = 0
    private var waveLFO = 0.0
    private var windLFO = 0.0
    private var rotationPhase = 0.0
    private var ambientAmp = 0.0

    private init() {}

    // MARK: - Parameters

    func setTone(carrier: Double, beat: Double) {
        carrierHz = max(40, carrier)
        beatHz = max(0.5, beat)
    }

    func setAmbient(type: Int, level: Double) {
        ambientType = type
        ambientLevel = max(0, min(1, level))
    }

    func setSpatial(amount: Double) { spatialAmount = max(0, min(1, amount)) }
    func setHeadYaw(_ yaw: Double) { headYaw = yaw }

    // MARK: - Transport

    func play() {
        configureIfNeeded()
        activateSession()
        if !engine.isRunning {
            engine.prepare()
            try? engine.start()
        }
        targetAmplitude = 0.9
    }

    func pause() { targetAmplitude = 0.0 }

    func stop() {
        targetAmplitude = 0.0
        engine.stop()
    }

    // MARK: - Graph

    private func configureIfNeeded() {
        guard !isConfigured else { return }
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else { return }

        let tones = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, abl in
            self?.renderTones(frameCount: frameCount, abl: abl) ?? noErr
        }
        let ambient = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, abl in
            self?.renderAmbient(frameCount: frameCount, abl: abl) ?? noErr
        }
        tonesNode = tones
        ambientNode = ambient

        engine.attach(tones)
        engine.attach(ambient)
        engine.attach(reverb)
        reverb.loadFactoryPreset(.largeHall2)
        reverb.wetDryMix = 42

        engine.connect(tones, to: engine.mainMixerNode, format: format)
        engine.connect(ambient, to: reverb, format: format)
        engine.connect(reverb, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.9
        isConfigured = true
    }

    private func nextNoise() -> Float {
        rng ^= rng << 13
        rng ^= rng >> 17
        rng ^= rng << 5
        return Float(Int32(bitPattern: rng)) / Float(Int32.max)
    }

    // MARK: - Render: binaural tones

    private func renderTones(frameCount: AVAudioFrameCount, abl: UnsafeMutablePointer<AudioBufferList>) -> OSStatus {
        let buffers = UnsafeMutableAudioBufferListPointer(abl)
        guard buffers.count >= 2,
              let left = buffers[0].mData?.assumingMemoryBound(to: Float.self),
              let right = buffers[1].mData?.assumingMemoryBound(to: Float.self) else { return noErr }

        let frames = Int(frameCount)
        let twoPi = 2 * Double.pi
        let incLeft = twoPi * (carrierHz - beatHz / 2) / sampleRate
        let incRight = twoPi * (carrierHz + beatHz / 2) / sampleRate
        let target = targetAmplitude
        let step = (target - tonesAmp) / Double(max(1, frames))
        let level: Float = 0.2

        for frame in 0..<frames {
            tonesAmp += step
            let env = Float(tonesAmp)
            left[frame] = Float(sin(phaseLeft)) * level * env
            right[frame] = Float(sin(phaseRight)) * level * env
            phaseLeft += incLeft; if phaseLeft > twoPi { phaseLeft -= twoPi }
            phaseRight += incRight; if phaseRight > twoPi { phaseRight -= twoPi }
        }
        tonesAmp = target
        return noErr
    }

    // MARK: - Render: ambient soundscape (enveloping)

    private func renderAmbient(frameCount: AVAudioFrameCount, abl: UnsafeMutablePointer<AudioBufferList>) -> OSStatus {
        let buffers = UnsafeMutableAudioBufferListPointer(abl)
        guard buffers.count >= 2,
              let left = buffers[0].mData?.assumingMemoryBound(to: Float.self),
              let right = buffers[1].mData?.assumingMemoryBound(to: Float.self) else { return noErr }

        let frames = Int(frameCount)
        let type = ambientType
        let lvl = Float(ambientLevel) * 0.7
        let twoPi = 2 * Double.pi
        let target = (type != 0) ? targetAmplitude : 0
        let step = (target - ambientAmp) / Double(max(1, frames))
        let waveInc = twoPi * 0.10 / sampleRate
        let windInc = twoPi * 0.07 / sampleRate
        let rotInc = twoPi * (spatialAmount * 0.3) / sampleRate
        let depth = Float(spatialAmount)
        let yaw = headYaw

        for frame in 0..<frames {
            ambientAmp += step
            let env = Float(ambientAmp)
            var ambL: Float = 0, ambR: Float = 0

            if type != 0 && lvl > 0 {
                let wl = nextNoise(), wr = nextNoise()
                switch type {
                case 1:
                    lpA_L += (wl - lpA_L) * 0.45; ambL = (wl - lpA_L) * 0.9
                    lpA_R += (wr - lpA_R) * 0.45; ambR = (wr - lpA_R) * 0.9
                case 2:
                    brownL += wl * 0.015; brownL *= 0.992
                    brownR += wr * 0.015; brownR *= 0.992
                    waveLFO += waveInc; if waveLFO > twoPi { waveLFO -= twoPi }
                    let swell = Float(0.35 + 0.65 * (0.5 + 0.5 * sin(waveLFO)))
                    ambL = brownL * 3.4 * swell; ambR = brownR * 3.4 * swell
                case 3:
                    lpA_L += (wl - lpA_L) * 0.20; lpB_L += (lpA_L - lpB_L) * 0.6
                    lpA_R += (wr - lpA_R) * 0.20; lpB_R += (lpA_R - lpB_R) * 0.6
                    windLFO += windInc; if windLFO > twoPi { windLFO -= twoPi }
                    let mod = Float(0.5 + 0.5 * (0.5 + 0.5 * sin(windLFO)))
                    ambL = (lpA_L - lpB_L) * 2.7 * mod; ambR = (lpA_R - lpB_R) * 2.7 * mod
                case 4:
                    lpA_L += (wl - lpA_L) * 0.05; lpA_R += (wr - lpA_R) * 0.05
                    windLFO += windInc; if windLFO > twoPi { windLFO -= twoPi }
                    let mod = Float(0.4 + 0.6 * (0.5 + 0.5 * sin(windLFO)))
                    ambL = lpA_L * 2.9 * mod; ambR = lpA_R * 2.9 * mod
                default:
                    ambL = wl * 0.5; ambR = wr * 0.5
                }
                ambL *= lvl; ambR *= lvl
            }

            var gainL: Float = 1, gainR: Float = 1
            if depth > 0.001 {
                rotationPhase += rotInc; if rotationPhase > twoPi { rotationPhase -= twoPi }
                let sway = Float(sin(rotationPhase - yaw)) * depth
                gainL = 1 - max(0, sway) * 0.85
                gainR = 1 - max(0, -sway) * 0.85
            }

            left[frame] = ambL * gainL * env
            right[frame] = ambR * gainR * env
        }
        ambientAmp = target
        return noErr
    }

    private func activateSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)
    }
}
