import AVFoundation

/// Real-time, fully synthesized (no files, no DRM):
/// - **binaural beats** straight to the mixer (clean);
/// - a **mix of ambient soundscapes** (rain/ocean/forest/wind/noise/thunder/
///   fire/café/stream). Each is built from **depth layers** (a distant wash plus
///   near, discrete events — droplets, waves, crackles, chirps, bubbles) with
///   independent noise per ear so it envelops you and never loops;
/// - all ambience runs through **reverb** for a real-room/space feel;
/// - **spatial audio**: a gentle, non-mechanical circling (two incommensurate
///   orbits + per-event panning), head-anchored via AirPods.
///
/// `@unchecked Sendable`: render blocks run on the audio thread reading plain
/// parameter values (benign races).
final class BinauralEngine: @unchecked Sendable {

    static let shared = BinauralEngine()

    /// Soundscape type codes (index into the level arrays).
    static let typeCount = 10   // 0 unused; 1...9 soundscapes
    private static let pool = 12 // transient-event voices per pooled soundscape

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
    private var ambLevels = [Float](repeating: 0, count: typeCount)
    private var spatialAmount = 0.0
    private var headYaw = 0.0

    // Tones state.
    private var phaseLeft = 0.0
    private var phaseRight = 0.0
    private var padPhase = 0.0      // warm mono sub-octave drone
    private var toneBreath = 0.0    // slow amplitude breathing
    private var toneLpL: Float = 0  // gentle smoothing per ear
    private var toneLpR: Float = 0
    private var tonesAmp = 0.0

    // Shared noise + generic one-pole filter banks (per type, per ear).
    private var rng: UInt32 = 0x9E3779B9
    private var lpA_L = [Float](repeating: 0, count: typeCount)
    private var lpA_R = [Float](repeating: 0, count: typeCount)
    private var lpB_L = [Float](repeating: 0, count: typeCount)
    private var lpB_R = [Float](repeating: 0, count: typeCount)
    private var brownL = [Float](repeating: 0, count: typeCount)
    private var brownR = [Float](repeating: 0, count: typeCount)

    // Rain: near droplet voices (damped "plinks") at random pan/pitch.
    private var rainEnv = [Float](repeating: 0, count: pool)
    private var rainPh  = [Double](repeating: 0, count: pool)
    private var rainInc = [Double](repeating: 0, count: pool)
    private var rainPan = [Float](repeating: 0.5, count: pool)
    private var rainDec = [Float](repeating: 0.999, count: pool)

    // Fire: crackle/pop voices.
    private var crkEnv = [Float](repeating: 0, count: pool)
    private var crkPh  = [Double](repeating: 0, count: pool)
    private var crkInc = [Double](repeating: 0, count: pool)
    private var crkPan = [Float](repeating: 0.5, count: pool)
    private var crkDec = [Float](repeating: 0.99, count: pool)

    // Stream: bubble blips (short up-chirps).
    private var bubEnv = [Float](repeating: 0, count: pool)
    private var bubPh  = [Double](repeating: 0, count: pool)
    private var bubInc = [Double](repeating: 0, count: pool)
    private var bubChirp = [Double](repeating: 0, count: pool)
    private var bubPan = [Float](repeating: 0.5, count: pool)

    // Ocean: one rolling wave event at a time (irregular period), over far surf.
    private var wavePos = 1.0     // progress 0...1 (>=1 ⇒ pick next wave)
    private var waveDur = 6.0
    private var waveAmp: Float = 0.8
    private var wavePan: Float = 0.5

    // Forest: occasional bird chirp.
    private var birdEnv: Float = 0
    private var birdPh = 0.0
    private var birdInc = 0.0
    private var birdSweep = 0.0
    private var birdTimer = 1.5
    private var birdPan: Float = 0.5

    // Wind: drifting gust + faint whistle.
    private var gust: Float = 0.4
    private var gustTarget: Float = 0.4
    private var whistle: Float = 0

    // Thunder: rare rolling rumble events with an onset crack.
    private var thunRumble: Float = 0
    private var thunCrack: Float = 0
    private var thunTimer = 4.0
    private var thunPan: Float = 0.5

    // Café: sparse cup/spoon clink over a dark murmur.
    private var cafeEnv: Float = 0
    private var cafePh = 0.0
    private var cafeInc = 0.0
    private var cafePan: Float = 0.5

    // Slow shared LFOs + spatial orbits.
    private var waveLFO = 0.0
    private var windLFO = 0.0
    private var rotA = 0.0
    private var rotB = 0.0
    private var ambientAmp = 0.0

    private init() {}

    // MARK: - Parameters

    func setTone(carrier: Double, beat: Double) {
        carrierHz = max(40, carrier)
        beatHz = max(0.5, beat)
    }

    /// Sets the level (0...1) of one soundscape layer; 0 disables it.
    func setAmbientLevel(type: Int, level: Double) {
        guard type > 0, type < Self.typeCount else { return }
        ambLevels[type] = Float(max(0, min(1, level)))
    }

    func setSpatial(amount: Double) { spatialAmount = max(0, min(1, amount)) }
    func setHeadYaw(_ yaw: Double) { headYaw = yaw }

    func setMasterVolume(_ value: Double) {
        configureIfNeeded()
        engine.mainMixerNode.outputVolume = Float(max(0, min(1, value))) * 0.9
    }

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
        reverb.wetDryMix = 48

        engine.connect(tones, to: engine.mainMixerNode, format: format)
        engine.connect(ambient, to: reverb, format: format)
        engine.connect(reverb, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.9
        isConfigured = true
    }

    /// White noise in -1...1.
    private func nextNoise() -> Float {
        rng ^= rng << 13
        rng ^= rng >> 17
        rng ^= rng << 5
        return Float(Int32(bitPattern: rng)) / Float(Int32.max)
    }

    /// Uniform random in 0...1.
    private func nextUniform() -> Float { nextNoise() * 0.5 + 0.5 }

    /// Equal-ish-power pan: pan 0 = hard left, 1 = hard right.
    private func panGains(_ pan: Float) -> (Float, Float) {
        ((1 - pan).squareRoot(), pan.squareRoot())
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
        let incPad = twoPi * (carrierHz * 0.5) / sampleRate   // sub-octave, centered
        let breathInc = twoPi * 0.08 / sampleRate
        let target = targetAmplitude
        let step = (target - tonesAmp) / Double(max(1, frames))
        let beatLevel: Float = 0.16   // the binaural beat itself
        let padLevel: Float = 0.11    // warm body so it isn't a bare sine

        for frame in 0..<frames {
            tonesAmp += step
            let env = Float(tonesAmp)
            toneBreath += breathInc; if toneBreath > twoPi { toneBreath -= twoPi }
            let breath = Float(0.88 + 0.12 * sin(toneBreath))
            let pad = Float(sin(padPhase)) * padLevel * breath
            let l = Float(sin(phaseLeft)) * beatLevel + pad
            let r = Float(sin(phaseRight)) * beatLevel + pad
            // Gentle one-pole smoothing rounds the very top edge / onset clicks.
            toneLpL += (l - toneLpL) * 0.6
            toneLpR += (r - toneLpR) * 0.6
            left[frame] = toneLpL * env
            right[frame] = toneLpR * env
            phaseLeft += incLeft; if phaseLeft > twoPi { phaseLeft -= twoPi }
            phaseRight += incRight; if phaseRight > twoPi { phaseRight -= twoPi }
            padPhase += incPad; if padPhase > twoPi { padPhase -= twoPi }
        }
        tonesAmp = target
        return noErr
    }

    // MARK: - Render: ambient mix (depth layers + discrete events)

    private func renderAmbient(frameCount: AVAudioFrameCount, abl: UnsafeMutablePointer<AudioBufferList>) -> OSStatus {
        let buffers = UnsafeMutableAudioBufferListPointer(abl)
        guard buffers.count >= 2,
              let left = buffers[0].mData?.assumingMemoryBound(to: Float.self),
              let right = buffers[1].mData?.assumingMemoryBound(to: Float.self) else { return noErr }

        let frames = Int(frameCount)
        let twoPi = 2 * Double.pi
        let dt = 1.0 / sampleRate
        let anyActive = ambLevels.contains { $0 > 0 }
        let target = anyActive ? targetAmplitude : 0
        let step = (target - ambientAmp) / Double(max(1, frames))
        let waveInc = twoPi * 0.09 / sampleRate
        let windInc = twoPi * 0.06 / sampleRate
        // Two incommensurate orbit rates so the pan never feels metronomic.
        // Kept slow + gentle: fast circling is a dizziness/motion-sickness trigger.
        let rotIncA = twoPi * (0.055 + spatialAmount * 0.11) / sampleRate
        let rotIncB = twoPi * (0.028 + spatialAmount * 0.05) / sampleRate
        let depth = Float(spatialAmount)
        let yaw = Float(headYaw)

        for frame in 0..<frames {
            ambientAmp += step
            let env = Float(ambientAmp)

            waveLFO += waveInc; if waveLFO > twoPi { waveLFO -= twoPi }
            windLFO += windInc; if windLFO > twoPi { windLFO -= twoPi }
            let forestMod = Float(0.5 + 0.5 * (0.5 + 0.5 * sin(windLFO)))
            let cafeMod = Float(0.55 + 0.45 * (0.5 + 0.5 * sin(windLFO * 0.7)))

            var ambL: Float = 0, ambR: Float = 0

            // 1 — RAIN: distant sheet (per-ear filtered noise) + near droplets.
            if ambLevels[1] > 0 {
                let lvl = ambLevels[1]
                let nL = nextNoise(), nR = nextNoise()
                lpA_L[1] += (nL - lpA_L[1]) * 0.12
                lpA_R[1] += (nR - lpA_R[1]) * 0.12
                var l = (nL - lpA_L[1]) * 0.22   // high-passed → airy sheet
                var r = (nR - lpA_R[1]) * 0.22
                // Spawn droplets irregularly (~110/sec across the field).
                if nextUniform() < 0.0026 {
                    spawn(env: &rainEnv, ph: &rainPh, inc: &rainInc, pan: &rainPan,
                          amp: 0.18 + nextUniform() * 0.5,
                          freq: 1400 + Double(nextUniform()) * 2600,
                          pan01: nextUniform())
                    // give this voice a random short decay (~10-40 ms)
                    if let i = lastSpawn { rainDec[i] = 0.9970 + nextUniform() * 0.0025 }
                }
                for i in 0..<Self.pool where rainEnv[i] > 0.0004 {
                    rainPh[i] += rainInc[i]
                    let s = Float(sin(rainPh[i])) * rainEnv[i]
                    let (gL, gR) = panGains(rainPan[i])
                    l += s * gL; r += s * gR
                    rainEnv[i] *= rainDec[i]
                }
                ambL += l * lvl; ambR += r * lvl
            }

            // 2 — OCEAN: far surf (brown swell) + one rolling near wave at a time.
            if ambLevels[2] > 0 {
                let lvl = ambLevels[2]
                let nL = nextNoise(), nR = nextNoise()
                brownL[2] += nL * 0.012; brownL[2] *= 0.9928
                brownR[2] += nR * 0.012; brownR[2] *= 0.9928
                let farSwell = Float(0.4 + 0.6 * (0.5 + 0.5 * sin(waveLFO)))
                var l = brownL[2] * 2.6 * farSwell
                var r = brownR[2] * 2.6 * farSwell
                // Near wave: rises, breaks (bright foam at the crest), recedes.
                wavePos += dt / waveDur
                if wavePos >= 1 {
                    wavePos = 0
                    waveDur = 4.5 + Double(nextUniform()) * 6.0
                    waveAmp = 0.55 + nextUniform() * 0.45
                    wavePan = nextUniform()
                }
                let shape = Float(sin(Double.pi * wavePos))            // 0→1→0 swell
                let crest = max(0, shape - 0.55) * 2.2                 // foam near peak
                let foam = (nextNoise() - lpB_L[2]); lpB_L[2] += (nextNoise() - lpB_L[2]) * 0.5
                let body = brownL[2] * 3.0
                let wave = (body + foam * crest * 0.5) * shape * waveAmp
                let (gL, gR) = panGains(wavePan)
                l += wave * gL; r += wave * gR
                ambL += l * lvl; ambR += r * lvl
            }

            // 3 — FOREST: leafy rustle (band-passed) + occasional bird chirps.
            if ambLevels[3] > 0 {
                let lvl = ambLevels[3]
                let nL = nextNoise(), nR = nextNoise()
                lpA_L[3] += (nL - lpA_L[3]) * 0.22; lpB_L[3] += (lpA_L[3] - lpB_L[3]) * 0.55
                lpA_R[3] += (nR - lpA_R[3]) * 0.22; lpB_R[3] += (lpA_R[3] - lpB_R[3]) * 0.55
                var l = (lpA_L[3] - lpB_L[3]) * 2.4 * forestMod
                var r = (lpA_R[3] - lpB_R[3]) * 2.4 * forestMod
                birdTimer -= dt
                if birdTimer <= 0 {
                    birdTimer = 0.8 + Double(nextUniform()) * 3.4
                    birdEnv = 0.22 + nextUniform() * 0.3
                    birdInc = twoPi * (2200 + Double(nextUniform()) * 2200) / sampleRate
                    birdSweep = (Double(nextUniform()) - 0.4) * birdInc * 0.5
                    birdPan = nextUniform()
                    birdPh = 0
                }
                if birdEnv > 0.0008 {
                    birdPh += birdInc + birdSweep * Double(1 - birdEnv) // tiny pitch glide
                    let vib = 1 + 0.02 * sin(birdPh * 0.12)
                    let s = Float(sin(birdPh * vib)) * birdEnv
                    let (gL, gR) = panGains(birdPan)
                    l += s * gL; r += s * gR
                    birdEnv *= 0.9992
                }
                ambL += l * lvl; ambR += r * lvl
            }

            // 4 — WIND: drifting gusts (slow random walk) + faint whistle.
            if ambLevels[4] > 0 {
                let lvl = ambLevels[4]
                let nL = nextNoise(), nR = nextNoise()
                if nextUniform() < 0.00004 { gustTarget = 0.18 + nextUniform() * 0.82 }
                gust += (gustTarget - gust) * 0.00006
                lpA_L[4] += (nL - lpA_L[4]) * 0.045; lpA_R[4] += (nR - lpA_R[4]) * 0.045
                // whistle: a resonant band that swells with the strongest gusts
                whistle += (nextNoise() - whistle) * 0.02
                let whis = whistle * max(0, gust - 0.55) * 1.4
                let l = (lpA_L[4] * 2.6 + whis) * gust
                let r = (lpA_R[4] * 2.6 + whis * 0.8) * gust
                ambL += l * lvl; ambR += r * lvl
            }

            // 5 — WHITE NOISE: even, full-band.
            if ambLevels[5] > 0 {
                let lvl = ambLevels[5]
                ambL += nextNoise() * 0.42 * lvl
                ambR += nextNoise() * 0.42 * lvl
            }

            // 6 — THUNDER: mostly quiet, with rare rolling rumble + onset crack.
            if ambLevels[6] > 0 {
                let lvl = ambLevels[6]
                thunTimer -= dt
                if thunTimer <= 0 {
                    thunTimer = 7 + Double(nextUniform()) * 12
                    thunRumble = 0.8 + nextUniform() * 0.2
                    thunCrack = 0.6 + nextUniform() * 0.4
                    thunPan = 0.35 + nextUniform() * 0.3
                }
                let nL = nextNoise(), nR = nextNoise()
                brownL[6] += nL * 0.02; brownL[6] *= 0.9985
                brownR[6] += nR * 0.02; brownR[6] *= 0.9985
                let roll = Float(0.6 + 0.4 * sin(windLFO * 0.5))
                var l = brownL[6] * 5.2 * thunRumble * roll
                var r = brownR[6] * 5.2 * thunRumble * roll
                if thunCrack > 0.001 {                       // sharp leading edge
                    l += nL * thunCrack * 0.5
                    r += nR * thunCrack * 0.5
                    thunCrack *= 0.992
                }
                let (gL, gR) = panGains(thunPan)
                l *= gL * 1.3; r *= gR * 1.3
                thunRumble *= 0.99996                        // multi-second decay
                ambL += l * lvl; ambR += r * lvl
            }

            // 7 — FIRE: low roar (filtered noise) + frequent varied crackle/pops.
            if ambLevels[7] > 0 {
                let lvl = ambLevels[7]
                let nL = nextNoise(), nR = nextNoise()
                lpA_L[7] += (nL - lpA_L[7]) * 0.08; lpA_R[7] += (nR - lpA_R[7]) * 0.08
                var l = lpA_L[7] * 1.7
                var r = lpA_R[7] * 1.7
                if nextUniform() < 0.010 {                   // small crackle
                    spawn(env: &crkEnv, ph: &crkPh, inc: &crkInc, pan: &crkPan,
                          amp: 0.1 + nextUniform() * 0.3,
                          freq: 1800 + Double(nextUniform()) * 3500,
                          pan01: nextUniform())
                    if let i = lastSpawn { crkDec[i] = 0.985 + nextUniform() * 0.01 }
                }
                if nextUniform() < 0.0012 {                  // occasional bigger pop
                    spawn(env: &crkEnv, ph: &crkPh, inc: &crkInc, pan: &crkPan,
                          amp: 0.35 + nextUniform() * 0.4,
                          freq: 500 + Double(nextUniform()) * 900,
                          pan01: nextUniform())
                    if let i = lastSpawn { crkDec[i] = 0.972 + nextUniform() * 0.01 }
                }
                for i in 0..<Self.pool where crkEnv[i] > 0.0006 {
                    crkPh[i] += crkInc[i]
                    let s = Float(sin(crkPh[i])) * crkEnv[i]
                    let (gL, gR) = panGains(crkPan[i])
                    l += s * gL; r += s * gR
                    crkEnv[i] *= crkDec[i]
                }
                ambL += l * lvl; ambR += r * lvl
            }

            // 8 — CAFÉ: dark, warm crowd murmur (no hiss) + sparse cup clink.
            if ambLevels[8] > 0 {
                let lvl = ambLevels[8]
                let nL = nextNoise(), nR = nextNoise()
                lpA_L[8] += (nL - lpA_L[8]) * 0.05   // heavy lowpass → low murmur
                lpA_R[8] += (nR - lpA_R[8]) * 0.05
                var l = lpA_L[8] * 4.2 * cafeMod
                var r = lpA_R[8] * 4.2 * cafeMod
                if nextUniform() < 0.0006 {          // occasional cup / spoon clink
                    cafeEnv = 0.05 + nextUniform() * 0.10
                    cafeInc = twoPi * (1700 + Double(nextUniform()) * 1500) / sampleRate
                    cafePan = nextUniform(); cafePh = 0
                }
                if cafeEnv > 0.0006 {
                    cafePh += cafeInc
                    let s = Float(sin(cafePh)) * cafeEnv
                    let (gL, gR) = panGains(cafePan)
                    l += s * gL; r += s * gR
                    cafeEnv *= 0.990
                }
                ambL += l * lvl; ambR += r * lvl
            }

            // 9 — STREAM: flowing water — low gurgle + light trickle + bubbles.
            if ambLevels[9] > 0 {
                let lvl = ambLevels[9]
                let nL = nextNoise(), nR = nextNoise()
                lpA_L[9] += (nL - lpA_L[9]) * 0.5; lpA_R[9] += (nR - lpA_R[9]) * 0.5
                brownL[9] += nL * 0.012; brownL[9] *= 0.99   // watery low movement
                brownR[9] += nR * 0.012; brownR[9] *= 0.99
                var l = (nL - lpA_L[9]) * 0.26 + brownL[9] * 1.7
                var r = (nR - lpA_R[9]) * 0.26 + brownR[9] * 1.7
                if nextUniform() < 0.010 {
                    let i = freeVoice(bubEnv)
                    bubEnv[i] = 0.15 + nextUniform() * 0.3
                    bubInc[i] = twoPi * (500 + Double(nextUniform()) * 700) / sampleRate
                    bubChirp[i] = bubInc[i] * (0.6 + Double(nextUniform()) * 1.2) // upward
                    bubPan[i] = nextUniform()
                    bubPh[i] = 0
                }
                for i in 0..<Self.pool where bubEnv[i] > 0.0008 {
                    bubInc[i] += bubChirp[i] * dt * 12        // quick rising blip
                    bubPh[i] += bubInc[i]
                    let s = Float(sin(bubPh[i])) * bubEnv[i]
                    let (gL, gR) = panGains(bubPan[i])
                    l += s * gL; r += s * gR
                    bubEnv[i] *= 0.992
                }
                ambL += l * lvl; ambR += r * lvl
            }

            // Overall trim so stacked layers stay clean.
            ambL *= 0.55; ambR *= 0.55

            // Spatial: gentle non-mechanical circling (two orbits) + head yaw.
            if depth > 0.001 {
                rotA += rotIncA; if rotA > twoPi { rotA -= twoPi }
                rotB += rotIncB; if rotB > twoPi { rotB -= twoPi }
                let sway = (Float(sin(rotA - Double(yaw))) * 0.7 + Float(sin(rotB)) * 0.3) * depth
                let gainL = 1 - max(0, sway) * 0.6
                let gainR = 1 - max(0, -sway) * 0.6
                ambL *= gainL; ambR *= gainR
            }

            left[frame] = ambL * env
            right[frame] = ambR * env
        }
        ambientAmp = target
        return noErr
    }

    // MARK: - Voice-pool helpers

    private var lastSpawn: Int?

    /// Finds the quietest free voice in a pool (steals the oldest if all busy).
    private func freeVoice(_ env: [Float]) -> Int {
        var idx = 0
        var min: Float = .greatestFiniteMagnitude
        for i in 0..<Self.pool where env[i] < min { min = env[i]; idx = i }
        return idx
    }

    /// Triggers a damped-sine voice (droplet / crackle) in a pool.
    private func spawn(env: inout [Float], ph: inout [Double], inc: inout [Double],
                       pan: inout [Float], amp: Float, freq: Double, pan01: Float) {
        let i = freeVoice(env)
        env[i] = amp
        inc[i] = 2 * Double.pi * freq / sampleRate
        ph[i] = 0
        pan[i] = pan01
        lastSpawn = i
    }

    private func activateSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)
    }
}
