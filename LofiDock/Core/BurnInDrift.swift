import CoreGraphics
import Foundation

/// Walks always-on text around a small figure-eight, one step a minute, so the
/// iPhone's OLED panel never shows the same bright glyph edges for hours.
enum BurnInDrift {
    static let stepsPerLoop = 12

    static func offset(at date: Date, amplitude: CGFloat = 6) -> CGSize {
        let minute = Int((date.timeIntervalSinceReferenceDate / 60).rounded(.down))
        let step = ((minute % stepsPerLoop) + stepsPerLoop) % stepsPerLoop
        let angle = Double(step) / Double(stepsPerLoop) * 2 * .pi
        return CGSize(
            width: amplitude * CGFloat(cos(angle)),
            height: amplitude * 0.6 * CGFloat(sin(angle * 2))
        )
    }
}
