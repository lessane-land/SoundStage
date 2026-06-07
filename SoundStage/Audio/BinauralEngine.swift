import AVFoundation

/// Generates, in real time and entirely from synthesis (no files, no DRM):
/// - **binaural beats**: a tone in each ear, detuned by the beat rate;
/// - an **ambient soundscape** (rain / ocean / forest / wind / noise);
/// - **spatial audio**: the ambient layer orbits the listener (the beat stays
///   as the fixed L/R pulse, since that difference *is* the binaural effect).
///
/// Not `@MainActor`: the render block runs on the audio thread. Parameters are
/// plain values read there (benign races), hence `@unchecked Sendable`.
final class BinauralEngine: @unchecked Sendable {

    static let shared = BinauralEngine()

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private let sampleRate: Double = 44_100
    private var isConfigured = false

    // Parameters (set from main, read on the audio thread).
    private var carrierHz = 200.0
    private var beatHz = 10.0
    private var targetAmplitude = 0.0
    private var ambientType = 0        // 0 none,1 rain,2 ocean,3 forest,4 wind,5 white
    private var ambientLevel = 0.0     // 0...1
    private var spatialAmount = 0.0    // 0...1 (orbit speed)
    private var headYaw = 0.0          // radians, from AirPods motion
    private var headTracking = false   // anchor the soundscape to the world

    // Audio-thread state.
    private var phaseLeft = 0.0
    private var phaseRight = 0.0
    private var amplitude = 0.0
    private var rng: UInt32 = 0x9E3779B9
    private var lpA: Float = 0          // generic low-pass states
    private var lpB: Float = 0
    private var brown: Float = 0
    private var waveLFO = 0.0
    private var windLFO = 0.0
    private var rotationPhase = 0.0

    private init() {}

    func setTone(carrier: Double, beat: Double) {
        carrierHz = max(50, carrier)
        beatHz = max(0.5, beat)
    }

    func setAmbient(type: Int, level: Double) {
        ambientType = type
        ambientLevel = max(0, min(1, level))
    }

    func setSpatial(amount: Double) {
        spatialAmount = max(0, min(1, amount))
    }

    func setHeadYaw(_ yaw: Double) { headYaw = yaw }

    func setHeadTracking(_ on: Bool) {
        headTracking = on
        if !on { headYaw = 0 }
    }

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

    private func nextNoise() -> Float {
        rng ^= rng << 13
        rng ^= rng >> 17
        rng ^= rng << 5
        return Float(Int32(bitPattern: rng)) / Float(Int32.max)
    }

    private func render(frameCount: AVAudioFrameCount, abl ablPointer: UnsafeMutablePointer<AudioBufferList>) -> OSStatus {
        let buffers = UnsafeMutableAudioBufferListPointer(ablPointer)
        guard buffers.count >= 2,
              let left = buffers[0].mData?.assumingMemoryBound(to: Float.self),
              let right = buffers[1].mData?.assumingMemoryBound(to: Float.self) else {
            return noErr
        }

        let frames = Int(frameCount)
        let beat = beatHz, carrier = carrierHz
        let incLeft = 2 * Double.pi * (carrier - beat / 2) / sampleRate
        let incRight = 2 * Double.pi * (carrier + beat / 2) / sampleRate
        let twoPi = 2 * Double.pi
        let target = targetAmplitude
        let ampStep = (target - amplitude) / Double(max(1, frames))
        let toneLevel: Float = 0.22
        let ambLevel = Float(ambientLevel) * 0.45
        let type = ambientType
        let waveInc = twoPi * 0.10 / sampleRate
        let windInc = twoPi * 0.07 / sampleRate
        let rotInc = twoPi * (spatialAmount * 0.2) / sampleRate
        // Head tracking anchors the soundscape to the world at full depth; the
        // yaw offset makes it stay put as the head turns.
        let depth: Float = headTracking ? 1.0 : Float(spatialAmount)
        let yaw = headTracking ? headYaw : 0.0

        for frame in 0..<frames {
            amplitude += ampStep
            let env = Float(amplitude)

            // Binaural tones (fixed L/R).
            let toneL = Float(sin(phaseLeft)) * toneLevel
            let toneR = Float(sin(phaseRight)) * toneLevel
            phaseLeft += incLeft; if phaseLeft > twoPi { phaseLeft -= twoPi }
            phaseRight += incRight; if phaseRight > twoPi { phaseRight -= twoPi }

            // Ambient soundscape (mono).
            var amb: Float = 0
            if type != 0 && ambLevel > 0 {
                let w = nextNoise()
                switch type {
                case 1: // Rain — bright, high-passed hiss
                    lpA += (w - lpA) * 0.45
                    amb = (w - lpA) * 0.9
                case 2: // Ocean — brown noise with slow swell
                    brown += w * 0.015
                    brown *= 0.992
                    waveLFO += waveInc; if waveLFO > twoPi { waveLFO -= twoPi }
                    amb = brown * 3.2 * Float(0.35 + 0.65 * (0.5 + 0.5 * sin(waveLFO)))
                case 3: // Forest — soft mid band + gentle motion
                    lpA += (w - lpA) * 0.20
                    lpB += (lpA - lpB) * 0.6
                    windLFO += windInc; if windLFO > twoPi { windLFO -= twoPi }
                    amb = (lpA - lpB) * 2.6 * Float(0.5 + 0.5 * (0.5 + 0.5 * sin(windLFO)))
                case 4: // Wind — low rumble, slowly varying
                    lpA += (w - lpA) * 0.05
                    windLFO += windInc; if windLFO > twoPi { windLFO -= twoPi }
                    amb = lpA * 2.8 * Float(0.4 + 0.6 * (0.5 + 0.5 * sin(windLFO)))
                default: // White noise
                    amb = w * 0.5
                }
                amb *= ambLevel
            }

            // Spatial pan of the ambient layer (orbits, and head-anchored when
            // head tracking is on).
            var panL: Float = 0.7071, panR: Float = 0.7071
            if depth > 0.001 {
                rotationPhase += rotInc; if rotationPhase > twoPi { rotationPhase -= twoPi }
                let pos = Float(sin(rotationPhase - yaw)) * depth
                let angle = (pos * 0.5 + 0.5) * (Float.pi / 2)
                panL = cos(angle); panR = sin(angle)
            }

            left[frame] = (toneL + amb * panL) * env
            right[frame] = (toneR + amb * panR) * env
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
