import SwiftUI

/// A countdown timer in the familiar iPhone Clock layout: wheels to set it, a
/// ring while it runs, Cancel on the left and Start/Pause on the right.
struct TimerFace: View {
    let date: Date
    let sessionElapsed: TimeInterval
    let size: CGSize
    @Environment(TimerController.self) private var timers
    @AppStorage(Pref.muted) private var muted = Pref.Default.muted

    var body: some View {
        let scale = DockMetrics.scale(for: size)
        let timer = timers.timer
        ZStack {
            LofiBackdrop()
            VStack(spacing: 8 * scale) {
                HStack(spacing: 40 * scale) {
                    RoundButton(title: "Cancel", kind: .quiet, scale: scale) { timers.cancel() }
                        .disabled(timer.phase == .idle)
                    Group {
                        if timer.phase == .idle {
                            DurationPicker(length: Binding(get: { timers.pickedLength },
                                                           set: { timers.pickedLength = $0 }),
                                           scale: scale)
                        } else {
                            CountdownRing(timer: timer, now: date, scale: scale)
                        }
                    }
                    .frame(width: 360 * scale, height: 290 * scale)
                    primaryButton(for: timer, scale: scale)
                }
                SessionLine(date: date, sessionElapsed: sessionElapsed, scale: scale * 0.85, showsTime: true)
                    .foregroundStyle(Palette.cream)
            }
        }
    }

    @ViewBuilder
    private func primaryButton(for timer: CountdownTimer, scale: CGFloat) -> some View {
        switch timer.phase {
        case .idle:
            RoundButton(title: "Start", kind: .go, scale: scale) { timers.start(muted: muted) }
                .disabled(timers.pickedLength < 1)
        case .running:
            RoundButton(title: "Pause", kind: .hold, scale: scale) { timers.pause() }
        case .paused:
            RoundButton(title: "Resume", kind: .go, scale: scale) { timers.resume(muted: muted) }
        case .finished:
            RoundButton(title: "Stop", kind: .stop, scale: scale) { timers.cancel() }
        }
    }
}

/// Remaining time inside a ring that empties as the countdown runs.
struct CountdownRing: View {
    let timer: CountdownTimer
    let now: Date
    let scale: CGFloat

    var body: some View {
        let fraction = timer.fractionRemaining(at: now)
        let lineWidth = 9 * scale
        // A finished timer blinks once a second until stopped.
        let blinkOff = timer.isFinished && Int(now.timeIntervalSinceReferenceDate).isMultiple(of: 2)
        ZStack {
            Circle().stroke(Palette.cream.opacity(0.1), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(Palette.lamp, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: Palette.lamp.opacity(0.5), radius: 8 * scale)
                .animation(.linear(duration: 1), value: fraction)
            VStack(spacing: 8 * scale) {
                Text(timer.isFinished ? "Time's up" : TimeFormatting.countdown(timer.remaining(at: now)))
                    .font(.system(size: (timer.isFinished ? 42 : 62) * scale, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.snappy, value: TimeFormatting.countdown(timer.remaining(at: now)))
                if case .running(let end) = timer.phase {
                    let clock = TimeFormatting.clock(end)
                    Label([clock.time, clock.period].compactMap { $0 }.joined(separator: " "), systemImage: "bell.fill")
                        .font(.system(size: 15 * scale, weight: .medium, design: .rounded))
                        .opacity(0.6)
                } else if timer.isPaused {
                    Text("PAUSED")
                        .font(.system(size: 12 * scale, weight: .semibold, design: .rounded))
                        .tracking(2.5 * scale)
                        .opacity(0.5)
                }
            }
            .foregroundStyle(Palette.cream)
        }
        .frame(width: 270 * scale, height: 270 * scale)
        .opacity(blinkOff ? 0.45 : 1)
        .animation(.easeInOut(duration: 0.6), value: blinkOff)
    }
}

/// Hours/min/sec wheels plus one-tap presets.
struct DurationPicker: View {
    @Binding var length: TimeInterval
    let scale: CGFloat
    private static let presetMinutes = [5, 15, 25, 45, 60]

    var body: some View {
        VStack(spacing: 12 * scale) {
            wheels.frame(height: 200 * scale)
            HStack(spacing: 8 * scale) {
                ForEach(Self.presetMinutes, id: \.self) { minutes in
                    let selected = Int(length) == minutes * 60
                    Button { length = TimeInterval(minutes * 60) } label: {
                        Text("\(minutes)m")
                            .font(.system(size: 14 * scale, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 12 * scale)
                            .padding(.vertical, 7 * scale)
                            .background(Capsule().fill(Palette.cream.opacity(selected ? 0.24 : 0.08)))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(minutes) minutes")
                }
            }
            .foregroundStyle(Palette.cream)
        }
    }

    /// One unit of the length (hours, minutes or seconds) as its own binding.
    private func unit(_ seconds: Int, wrap: Int) -> Binding<Int> {
        Binding(
            get: { (Int(length) / seconds) % wrap },
            set: { new in
                let old = (Int(length) / seconds) % wrap
                length = TimeInterval(Int(length) + (new - old) * seconds)
            }
        )
    }

    @ViewBuilder private var wheels: some View {
        #if os(iOS)
        HStack(spacing: 0) {
            wheel(unit(3600, wrap: 24), 0..<24, "hours")
            wheel(unit(60, wrap: 60), 0..<60, "min")
            wheel(unit(1, wrap: 60), 0..<60, "sec")
        }
        #else
        // macOS has no wheel picker; the preview tool shows the chosen length.
        HStack(alignment: .firstTextBaseline, spacing: 6 * scale) {
            ForEach([(3600, 24, "hours"), (60, 60, "min"), (1, 60, "sec")], id: \.2) { seconds, wrap, label in
                Text("\(unit(seconds, wrap: wrap).wrappedValue)")
                    .font(.system(size: 44 * scale, weight: .light, design: .rounded))
                Text(label)
                    .font(.system(size: 15 * scale, weight: .semibold, design: .rounded))
                    .opacity(0.7)
                    .padding(.trailing, 14 * scale)
            }
        }
        .foregroundStyle(Palette.cream)
        #endif
    }

    #if os(iOS)
    private func wheel(_ value: Binding<Int>, _ range: Range<Int>, _ label: String) -> some View {
        HStack(spacing: 2 * scale) {
            Picker(label, selection: value) {
                ForEach(range, id: \.self) { Text("\($0)").tag($0) }
            }
            .pickerStyle(.wheel)
            .frame(width: 62 * scale)
            .clipped()
            Text(label)
                .font(.system(size: 15 * scale, weight: .semibold, design: .rounded))
                .foregroundStyle(Palette.cream.opacity(0.8))
                .frame(width: 46 * scale, alignment: .leading)
        }
    }
    #endif
}

/// Round Clock-app style button in the lofi palette.
struct RoundButton: View {
    enum Kind { case quiet, go, hold, stop }

    let title: LocalizedStringKey
    let kind: Kind
    let scale: CGFloat
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16 * scale, weight: .semibold, design: .rounded))
                .foregroundStyle(tint)
                .frame(width: 82 * scale, height: 82 * scale)
                .background(Circle().fill(tint.opacity(kind == .quiet ? 0.12 : 0.2)))
                .overlay(Circle().inset(by: 3.5 * scale).stroke(tint.opacity(0.35), lineWidth: 1.5 * scale))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.4)
    }

    private var tint: Color {
        switch kind {
        case .quiet: Palette.cream
        case .go: Color(hex: 0xFFC27A)
        case .hold: Color(hex: 0xE8D27A)
        case .stop: Color(hex: 0xFF9C80)
        }
    }
}

/// Shown on the other faces while a countdown runs or rings.
struct TimerChip: View {
    let timer: CountdownTimer
    let now: Date
    var onTap: () -> Void

    var body: some View {
        let remaining = TimeFormatting.countdown(timer.remaining(at: now))
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: timer.isFinished ? "bell.fill" : "timer")
                Text(timer.isFinished ? "Time's up · Stop" : remaining)
                    .monospacedDigit()
            }
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(timer.isFinished ? Color(hex: 0xFF9C80) : Palette.cream)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(Capsule().fill(Color(hex: 0x15101C, opacity: 0.78)))
            .overlay(Capsule().stroke(Palette.cream.opacity(0.1), lineWidth: 1))
            .opacity(timer.isPaused ? 0.6 : 1)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(timer.isFinished ? "Timer finished. Stop" : "Timer, \(remaining) left")
    }
} 
