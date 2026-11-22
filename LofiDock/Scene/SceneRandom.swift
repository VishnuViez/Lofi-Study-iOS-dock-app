import Foundation

/// Stable pseudo-random values keyed by (index, salt), so every frame places
/// the same stars, buildings and raindrops without storing any of them.
enum SceneRandom {
    /// Uniform in 0..<1 (splitmix64 finaliser).
    static func unit(_ index: Int, _ salt: Int = 0) -> Double {
        var z = UInt64(bitPattern: Int64(index)) &* 0x9E37_79B9_7F4A_7C15
            &+ UInt64(bitPattern: Int64(salt)) &* 0xD1B5_4A32_D192_ED03
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z ^= z >> 31
        return Double(z >> 11) / Double(UInt64(1) << 53)
    }
}

@inline(__always) func rnd(_ index: Int, _ salt: Int) -> CGFloat {
    CGFloat(SceneRandom.unit(index, salt))
}

@inline(__always) func fract(_ x: Double) -> Double {
    x - x.rounded(.down)
} 
