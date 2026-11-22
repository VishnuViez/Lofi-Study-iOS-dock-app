import Foundation

/// Procedural rain-on-glass and vinyl-surface noise for the study ambience.
/// It is generated sample by sample, so the app ships no audio files and the
/// sound never audibly loops.
///
/// `render` runs on the real-time audio thread. It must not allocate, lock or
/// touch Objective-C, so all state is plain value types, copied into locals
/// for the loop; that also keeps Swift's dynamic exclusivity checks on class
/// properties out of the per-sample path.
final class AmbienceSynth {
    /// Loudness targets (0...1) written from the main thread; the render loop
    /// glides toward them. Plain Floats suffice: aligned 32-bit stores are
    /// atomic on arm64, and a stale read only delays a fade by one buffer.
    var rainLevel: Float = 0
    var vinylLevel: Float = 0

    /// Time constant of fades between levels.
    static let glideSeconds: Float = 0.3

    let sampleRate: Float
    private var rng: NoiseRandom
    private var rainLeft: RainVoice
    private var rainRight: RainVoice
    private var vinyl: VinylVoice
    private var rainGain: Float = 0
    private var vinylGain: Float = 0
    private let glide: Float

    init(sampleRate: Double, seed: UInt64 = 0x51EE_7A1D_0C0F_FEE5) {
        let rate = Float(sampleRate)
        self.sampleRate = rate
        rng = NoiseRandom(seed: seed)
        rainLeft = RainVoice(sampleRate: rate, swellPhase: 0)
        rainRight = RainVoice(sampleRate: rate, swellPhase: 2.1)
        vinyl = VinylVoice(sampleRate: rate)
        glide = 1 - exp(-1 / (rate * Self.glideSeconds))
    }

    /// Drops both sources to silence instantly, so the next start fades in.
    /// Only call while no render is in flight (engine stopped).
    func silence() {
        rainGain = 0
        vinylGain = 0
    }

    func render(frames: Int, left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>) {
        var rng = self.rng
        var rainL = rainLeft, rainR = rainRight, vinyl = self.vinyl
        var rainGain = self.rainGain, vinylGain = self.vinylGain
        let rainTarget = rainLevel, vinylTarget = vinylLevel, glide = self.glide

        for i in 0..<frames {
            rainGain += (rainTarget - rainGain) * glide
            vinylGain += (vinylTarget - vinylGain) * glide
            var l: Float = 0, r: Float = 0
            if rainGain > 1e-4 {
                l += rainL.next(&rng) * rainGain
                r += rainR.next(&rng) * rainGain
            }
            if vinylGain > 1e-4 {
                let v = vinyl.next(&rng) * vinylGain
                l += v
                r += v
            }
            left[i] = softClip(l)
            right[i] = softClip(r)
        }

        self.rng = rng
        rainLeft = rainL
        rainRight = rainR
        self.vinyl = vinyl
        self.rainGain = rainGain
        self.vinylGain = vinylGain
    }
}

/// One channel of rain: a steady band of pink-noise hiss (the wash of drops on
/// glass), a soft low body, and sparse close drops that tick.
struct RainVoice {
    private var pink = PinkNoise()
    private var hissHighPass: OnePole
    private var hissLowPass: OnePole
    private var brown: Float = 0
    private var bodyLowPass: OnePole
    private var dropHighPass: OnePole
    private var drop: Float = 0
    private var swellPhase: Float
    private let swellStep: Float
    private let dropChance: Float
    private let dropDecay: Float

    init(sampleRate: Float, swellPhase: Float) {
        hissHighPass = OnePole(cutoff: 350, sampleRate: sampleRate)
        hissLowPass = OnePole(cutoff: 5_500, sampleRate: sampleRate)
        bodyLowPass = OnePole(cutoff: 180, sampleRate: sampleRate)
        dropHighPass = OnePole(cutoff: 2_500, sampleRate: sampleRate)
        self.swellPhase = swellPhase
        swellStep = 2 * .pi * 0.07 / sampleRate      // the shower thickens and thins every ~14 s
        dropChance = 22 / sampleRate                  // ~22 close drops a second
        dropDecay = exp(-1 / (sampleRate * 0.003))    // each rings for ~3 ms
    }

    mutating func next(_ rng: inout NoiseRandom) -> Float {
        let hiss = hissLowPass.lowPass(hissHighPass.highPass(pink.next(rng.bipolar())))
        brown = (brown + 0.02 * rng.bipolar()) / 1.02
        let body = bodyLowPass.lowPass(brown)
        if rng.unit() < dropChance {
            let a = rng.unit()
            drop = 0.1 + 0.5 * a * a
        }
        let tick = dropHighPass.highPass(rng.bipolar()) * drop
        drop *= dropDecay
        swellPhase += swellStep
        if swellPhase > 2 * .pi { swellPhase -= 2 * .pi }
        let swell = 0.85 + 0.15 * sin(swellPhase)
        return (hiss * Mix.rainHiss + body * Mix.rainBody + tick * Mix.rainDrops) * swell
    }
}

/// Surface noise of a spinning record: faint hiss, frequent tiny ticks, the
/// odd louder pop, and one scratch that comes round with every turn.
struct VinylVoice {
    private var hissHighPass: OnePole
    private var popLowPass: OnePole
    private var rumbleLowPass: OnePole
    private var tick: Float = 0
    private var pop: Float = 0
    private var turn: Float = 0
    private let turnStep: Float
    private let tickChance: Float
    private let popChance: Float
    private let tickDecay: Float
    private let popDecay: Float

    init(sampleRate: Float) {
        hissHighPass = OnePole(cutoff: 3_000, sampleRate: sampleRate)
        popLowPass = OnePole(cutoff: 2_200, sampleRate: sampleRate)
        rumbleLowPass = OnePole(cutoff: 45, sampleRate: sampleRate)
        turnStep = (100 / 3) / 60 / sampleRate        // 33⅓ rpm
        tickChance = 14 / sampleRate
        popChance = 0.5 / sampleRate
        tickDecay = exp(-1 / (sampleRate * 0.0003))
        popDecay = exp(-1 / (sampleRate * 0.0018))
    }

    mutating func next(_ rng: inout NoiseRandom) -> Float {
        if rng.unit() < tickChance {
            let a = rng.unit()
            tick = 0.05 + 0.4 * a * a * a
        }
        if rng.unit() < popChance {
            pop = 0.4 + 0.4 * rng.unit()
        }
        turn += turnStep
        if turn >= 1 {
            turn -= 1
            pop = max(pop, 0.25)
        }
        let hiss = hissHighPass.highPass(rng.bipolar())
        let crackle = tick * rng.bipolar() + popLowPass.lowPass(pop * rng.bipolar()) * 1.6
        tick *= tickDecay
        pop *= popDecay
        let rumble = rumbleLowPass.lowPass(rng.bipolar())
        return hiss * Mix.vinylHiss + crackle * Mix.vinylCrackle + rumble * Mix.vinylRumble
    }
}

/// Per-component levels, set by ear and checked against the RMS/peak ranges
/// asserted in AmbienceSynthTests.
private enum Mix {
    static let rainHiss: Float = 1.0
    static let rainBody: Float = 1.5
    static let rainDrops: Float = 0.3
    static let vinylHiss: Float = 0.015
    static let vinylCrackle: Float = 1.0
    static let vinylRumble: Float = 0.6
}

/// xorshift64: fast, allocation-free noise source for the render thread.
struct NoiseRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    @inline(__always) mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }

    /// Uniform in 0..<1.
    @inline(__always) mutating func unit() -> Float {
        Float(next() >> 40) * (1 / 16_777_216)
    }

    /// Uniform in -1..<1.
    @inline(__always) mutating func bipolar() -> Float {
        unit() * 2 - 1
    }
}

/// Paul Kellet's refined pink-noise filter (−3 dB/octave from white).
struct PinkNoise {
    private var b0: Float = 0, b1: Float = 0, b2: Float = 0, b3: Float = 0
    private var b4: Float = 0, b5: Float = 0, b6: Float = 0

    @inline(__always) mutating func next(_ white: Float) -> Float {
        b0 = 0.99886 * b0 + white * 0.0555179
        b1 = 0.99332 * b1 + white * 0.0750759
        b2 = 0.96900 * b2 + white * 0.1538520
        b3 = 0.86650 * b3 + white * 0.3104856
        b4 = 0.55000 * b4 + white * 0.5329522
        b5 = -0.7616 * b5 - white * 0.0168980
        let pink = b0 + b1 + b2 + b3 + b4 + b5 + b6 + white * 0.5362
        b6 = white * 0.115926
        return pink * 0.11
    }
}

/// One-pole filter. Use each instance as either a low-pass or a high-pass.
struct OnePole {
    private let a: Float
    private var z: Float = 0

    init(cutoff: Float, sampleRate: Float) {
        a = 1 - exp(-2 * .pi * cutoff / sampleRate)
    }

    @inline(__always) mutating func lowPass(_ x: Float) -> Float {
        z += a * (x - z)
        return z
    }

    @inline(__always) mutating func highPass(_ x: Float) -> Float {
        x - lowPass(x)
    }
}

/// Smooth limiter (Padé tanh), exact ±1 at ±3, so stacked peaks never clip hard.
@inline(__always) private func softClip(_ x: Float) -> Float {
    let c = min(max(x, -3), 3)
    return c * (27 + c * c) / (27 + 9 * c * c)
} 
