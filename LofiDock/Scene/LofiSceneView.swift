import SwiftUI

/// One frame of the study-room scene at a fixed time.
struct LofiSceneCanvas: View {
    let time: Double
    var recordSpinning = true
    var rain = true

    var body: some View {
        Canvas(opaque: true) { context, size in
            LofiScene(size: size, t: time, recordSpinning: recordSpinning, rain: rain).draw(in: &context)
        }
    }
}

/// Backdrop for the clock-only faces: dark warm gradient, slowly drifting
/// haze, faint rain and film grain. The lofi mood without the room.
struct LofiBackdrop: View {
    @Environment(\.showsRain) private var showsRain

    var body: some View {
        AnimationTimeline { time, _ in
            Canvas(opaque: true) { context, size in
                Self.draw(&context, size: size, t: time, rain: showsRain)
            }
        }
    }

    static func draw(_ gc: inout GraphicsContext, size: CGSize, t: Double, rain showsRain: Bool) {
        let full = CGRect(origin: .zero, size: size)
        gc.fill(Path(full), with: .linearGradient(
            Gradient(colors: [Color(hex: 0x110D1E), Color(hex: 0x1F1629)]),
            startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))

        // Haze: soft colour pools wandering on slow, unrelated loops.
        let pools: [(hex: UInt32, opacity: Double, period: Double, phase: Double, radius: CGFloat)] = [
            (0x7A5BB5, 0.22, 140, 0, 0.8),
            (0xFFB45E, 0.12, 110, 2.1, 0.6),
            (0xC9785A, 0.10, 170, 4.2, 0.7),
        ]
        for (i, pool) in pools.enumerated() {
            let a = t / pool.period * 2 * .pi + pool.phase
            let center = CGPoint(x: size.width * (0.5 + 0.32 * CGFloat(cos(a))),
                                 y: size.height * (0.5 + 0.28 * CGFloat(sin(a * 1.3 + Double(i)))))
            gc.fill(Path(full), with: .radialGradient(
                glowGradient(pool.hex, pool.opacity), center: center, startRadius: 0, endRadius: size.height * pool.radius))
        }

        if showsRain {
            var rain = gc
            rain.opacity = 0.4
            LofiScene.drawRain(&rain, full, t, size.height / 230)
        }

        // Grain re-rolls 12 times a second whatever the frame rate.
        let frame = Int(t * 12)
        var grain = Path()
        for i in 0..<700 {
            let key = frame &* 1_000 &+ i
            grain.addRect(CGRect(x: rnd(key, 91) * size.width, y: rnd(key, 92) * size.height, width: 1, height: 1))
        }
        gc.fill(grain, with: .color(.white.opacity(0.06)))

        gc.fill(Path(full), with: .radialGradient(
            Gradient(colors: [.black.opacity(0), .black.opacity(0.55)]),
            center: CGPoint(x: size.width / 2, y: size.height / 2),
            startRadius: size.height * 0.45, endRadius: size.width * 0.62))
    }
} 
