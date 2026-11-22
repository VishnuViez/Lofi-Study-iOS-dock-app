import Foundation

/// How often the animated scenery redraws. An always-on screen on a wireless
/// charger runs warm, and iOS slows charging when the phone gets hot, so with
/// adaptive motion on the frame rate backs off as the thermal state rises.
/// The time shown never depends on this: clocks tick on their own timeline.
enum AnimationBudget {
    static let full: Double = 30

    static func framesPerSecond(thermal: ProcessInfo.ThermalState, lowPowerMode: Bool, adaptive: Bool) -> Double {
        guard adaptive else { return full }
        switch thermal {
        case .critical: return 1
        case .serious: return 8
        case .fair: return lowPowerMode ? 10 : 20
        default: return lowPowerMode ? 15 : full
        }
    }
} 
