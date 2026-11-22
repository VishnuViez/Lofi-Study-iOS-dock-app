import Foundation
import Testing
@testable import LofiDock

struct AmbienceSynthTests {
    static let rate = 48_000

    /// Renders like the audio thread does: 512-frame buffers.
    func render(_ synth: AmbienceSynth, seconds: Double) -> (left: [Float], right: [Float]) {
        let frames = Int(Double(Self.rate) * seconds)
        var left = [Float](repeating: 0, count: frames), right = left
        left.withUnsafeMutableBufferPointer { l in
            right.withUnsafeMutableBufferPointer { r in
                var i = 0
                while i < frames {
                    let n = min(512, frames - i)
                    synth.render(frames: n, left: l.baseAddress! + i, right: r.baseAddress! + i)
                    i += n
                }
            }
        }
        return (left, right)
    }

    func rms(_ x: ArraySlice<Float>) -> Float {
        (x.reduce(0) { $0 + $1 * $1 } / Float(x.count)).squareRoot()
    }

    func synth(rain: Float, vinyl: Float, seed: UInt64 = 7) -> AmbienceSynth {
        let s = AmbienceSynth(sampleRate: Double(Self.rate), seed: seed)
        s.rainLevel = rain
        s.vinylLevel = vinyl
        return s
    }

    @Test func silentWhenBothSourcesAreOff() {
        let out = render(synth(rain: 0, vinyl: 0), seconds: 1)
        #expect(out.left.allSatisfy { $0 == 0 } && out.right.allSatisfy { $0 == 0 })
    }

    /// Around −20 dBFS: present at normal phone volume without dominating it.
    @Test func rainSitsInAComfortableRange() {
        let out = render(synth(rain: 1, vinyl: 0), seconds: 4)
        let steady = out.left[(Self.rate * 2)...]
        #expect((0.05...0.2).contains(rms(steady)))
        #expect(steady.allSatisfy { $0.isFinite && abs($0) < 1 })
    }

    /// Crackle is sparse transients, not a steady hiss: high peak-to-RMS ratio.
    @Test func vinylIsSparseCrackle() {
        let out = render(synth(rain: 0, vinyl: 1), seconds: 6)
        let steady = out.left[(Self.rate * 2)...]
        let peak = steady.map(abs).max() ?? 0
        #expect(peak / rms(steady) > 8)
        #expect(peak < 1)
    }

    @Test func fadesInRatherThanJumping() {
        let out = render(synth(rain: 1, vinyl: 0), seconds: 3)
        let first10ms = out.left[0..<(Self.rate / 100)]
        let steady = out.left[(Self.rate * 2)...]
        #expect(rms(first10ms) < rms(steady) * 0.1)
    }

    @Test func turningASourceOffFadesItOut() {
        let s = synth(rain: 1, vinyl: 0)
        _ = render(s, seconds: 2)
        s.rainLevel = 0
        let out = render(s, seconds: 2.5)
        let tail = out.left[(Self.rate * 2)...]
        #expect(rms(tail) < 0.002)
    }

    @Test func sameSeedSameSound() {
        let a = render(synth(rain: 1, vinyl: 1, seed: 42), seconds: 0.5)
        let b = render(synth(rain: 1, vinyl: 1, seed: 42), seconds: 0.5)
        #expect(a.left == b.left && a.right == b.right)
    }

    /// Independent noise per channel gives width; identical channels would
    /// collapse the rain to the middle.
    @Test func rainChannelsAreDecorrelated() {
        let out = render(synth(rain: 1, vinyl: 0), seconds: 3)
        let l = out.left[(Self.rate * 2)...], r = out.right[(Self.rate * 2)...]
        let dot = zip(l, r).reduce(Float(0)) { $0 + $1.0 * $1.1 }
        let correlation = dot / (rms(l) * rms(r) * Float(l.count))
        #expect(abs(correlation) < 0.3)
    }
}
