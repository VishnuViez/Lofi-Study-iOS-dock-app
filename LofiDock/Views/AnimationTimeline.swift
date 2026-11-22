import SwiftUI

/// A fixed point in time for rendering faces without a live clock
/// (the macOS preview tool); nil in the app.
struct FrozenMoment {
    var time: Double
    var date: Date
}

private struct FramesPerSecondKey: EnvironmentKey {
    static let defaultValue = AnimationBudget.full
}

private struct FrozenMomentKey: EnvironmentKey {
    static let defaultValue: FrozenMoment? = nil
}

private struct ShowsRainKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// Whether faces draw falling rain (the "Rain on the window" setting).
    var showsRain: Bool {
        get { self[ShowsRainKey.self] }
        set { self[ShowsRainKey.self] = newValue }
    }

    /// Redraw rate for animated scenery, from AnimationBudget.
    var framesPerSecond: Double {
        get { self[FramesPerSecondKey.self] }
        set { self[FramesPerSecondKey.self] = newValue }
    }

    var frozenMoment: FrozenMoment? {
        get { self[FrozenMomentKey.self] }
        set { self[FrozenMomentKey.self] = newValue }
    }
}

/// Drives a face's animation: `time` is seconds since the face appeared and
/// `date` the current instant, redrawn at the environment's frame budget.
struct AnimationTimeline<Content: View>: View {
    @Environment(\.framesPerSecond) private var framesPerSecond
    @Environment(\.frozenMoment) private var frozen
    @State private var origin = Date()
    @ViewBuilder var content: (_ time: Double, _ date: Date) -> Content

    var body: some View {
        if let frozen {
            content(frozen.time, frozen.date)
        } else {
            TimelineView(.animation(minimumInterval: 1 / max(framesPerSecond, 1))) { timeline in
                content(timeline.date.timeIntervalSince(origin), timeline.date)
            }
        }
    }
}
