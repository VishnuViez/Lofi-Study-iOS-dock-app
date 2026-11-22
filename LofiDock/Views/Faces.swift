import SwiftUI

/// The study-room scene with the clock on the wall beside the window.
struct LofiRoomFace: View {
    let date: Date
    let sessionElapsed: TimeInterval
    let size: CGSize
    var recordSpinning = true
    @Environment(\.showsRain) private var showsRain

    var body: some View {
        let scale = DockMetrics.scale(for: size)
        let panel = DockMetrics.clockPanel(in: size)
        ZStack {
            AnimationTimeline { time, _ in
                LofiSceneCanvas(time: time, recordSpinning: recordSpinning, rain: showsRain)
            }
            ClockOverlay(date: date, sessionElapsed: sessionElapsed, scale: scale)
                .frame(width: panel.width, height: panel.height)
                .position(x: panel.midX, y: panel.midY)
        }
    }
}

/// One huge, thin clock, StandBy style, over the lofi backdrop.
struct BigDigitsFace: View {
    let date: Date
    let sessionElapsed: TimeInterval
    let size: CGSize

    var body: some View {
        let scale = DockMetrics.scale(for: size)
        let clock = TimeFormatting.clock(date)
        ZStack {
            LofiBackdrop()
            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 10 * scale) {
                    Text(clock.time)
                        .font(.system(size: 200 * scale, weight: .thin, design: .rounded))
                        .monospacedDigit()
                    if let period = clock.period {
                        Text(period)
                            .font(.system(size: 34 * scale, weight: .medium, design: .rounded))
                            .opacity(0.6)
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                SessionLine(date: date, sessionElapsed: sessionElapsed, scale: scale)
            }
            .foregroundStyle(Palette.cream)
            .shadow(color: Palette.lamp.opacity(0.35), radius: 24 * scale)
            .padding(.horizontal, 70 * scale)
        }
    }
}

/// A paper-dial wall clock with a sweeping second hand, time and session beside it.
struct AnalogFace: View {
    let date: Date
    let sessionElapsed: TimeInterval
    let size: CGSize

    var body: some View {
        let scale = DockMetrics.scale(for: size)
        let clock = TimeFormatting.clock(date)
        let center = CGPoint(x: size.width * 0.36, y: size.height * 0.5)
        ZStack {
            LofiBackdrop()
            AnimationTimeline { _, now in
                Canvas { context, _ in
                    AnalogDial.draw(in: &context, center: center, radius: size.height * 0.4, hands: AnalogHands(date: now))
                }
            }
            VStack(alignment: .leading, spacing: 6 * scale) {
                HStack(alignment: .firstTextBaseline, spacing: 5 * scale) {
                    Text(clock.time)
                        .font(.system(size: 44 * scale, weight: .light, design: .rounded))
                        .monospacedDigit()
                    if let period = clock.period {
                        Text(period).font(.system(size: 16 * scale, weight: .medium, design: .rounded)).opacity(0.6)
                    }
                }
                Text(TimeFormatting.dateLine(date))
                    .font(.system(size: 15 * scale, weight: .medium, design: .rounded))
                    .opacity(0.65)
                Capsule()
                    .fill(Palette.cream.opacity(0.22))
                    .frame(width: 30 * scale, height: 1.5 * scale)
                    .padding(.vertical, 8 * scale)
                Text("SESSION")
                    .font(.system(size: 11 * scale, weight: .semibold, design: .rounded))
                    .tracking(2.5 * scale)
                    .opacity(0.55)
                Text(TimeFormatting.session(sessionElapsed))
                    .font(.system(size: 24 * scale, weight: .regular, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(Palette.cream)
            .shadow(color: Palette.lamp.opacity(0.25), radius: 14 * scale)
            .frame(width: size.width * 0.26, alignment: .leading)
            .position(x: size.width * 0.73, y: size.height * 0.5)
        }
    }
}

/// Retro split-flap cards for hours and minutes.
struct FlipFace: View {
    let date: Date
    let sessionElapsed: TimeInterval
    let size: CGSize

    var body: some View {
        let scale = DockMetrics.scale(for: size)
        let clock = TimeFormatting.clock(date)
        let parts = clock.time.split(separator: ":").map(String.init)
        ZStack {
            LofiBackdrop()
            VStack(spacing: 24 * scale) {
                HStack(spacing: 18 * scale) {
                    FlipCard(text: parts.first ?? "", corner: clock.period, scale: scale)
                    FlipCard(text: parts.last ?? "", corner: nil, scale: scale)
                }
                SessionLine(date: date, sessionElapsed: sessionElapsed, scale: scale)
                    .foregroundStyle(Palette.cream)
            }
        }
    }
}

struct FlipCard: View {
    let text: String
    let corner: String?
    let scale: CGFloat

    var body: some View {
        let radius = 22 * scale
        ZStack {
            RoundedRectangle(cornerRadius: radius)
                .fill(LinearGradient(colors: [Color(hex: 0x372A31), Color(hex: 0x2A2027)],
                                     startPoint: .top, endPoint: .center))
            // The lower flap sits a shade darker, as if lit from above.
            RoundedRectangle(cornerRadius: radius)
                .fill(Color(hex: 0x221A20))
                .mask(VStack(spacing: 0) { Color.clear; Color.black })
            Text(text)
                .font(.system(size: 170 * scale, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Palette.cream)
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.6), value: text)
            Rectangle()
                .fill(Color.black.opacity(0.6))
                .frame(height: 3 * scale)
            HStack {
                Capsule().frame(width: 6 * scale, height: 20 * scale)
                Spacer()
                Capsule().frame(width: 6 * scale, height: 20 * scale)
            }
            .foregroundStyle(Color(hex: 0x120D14))
            .padding(.horizontal, -2 * scale)
            if let corner {
                Text(corner)
                    .font(.system(size: 15 * scale, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.cream.opacity(0.5))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(16 * scale)
            }
        }
        .frame(width: 250 * scale, height: 230 * scale)
        .overlay(
            RoundedRectangle(cornerRadius: radius)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 18 * scale, y: 10 * scale)
    }
}

/// "Saturday, November 21 · SESSION 0:42:13", optionally led by the time.
struct SessionLine: View {
    let date: Date
    let sessionElapsed: TimeInterval
    let scale: CGFloat
    var showsTime = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12 * scale) {
            if showsTime {
                let clock = TimeFormatting.clock(date)
                Text([clock.time, clock.period].compactMap { $0 }.joined(separator: " "))
                    .monospacedDigit()
                Text("·").opacity(0.5)
            }
            Text(TimeFormatting.dateLine(date))
            Text("·").opacity(0.5)
            Text("SESSION")
                .font(.system(size: 12 * scale, weight: .semibold, design: .rounded))
                .tracking(2.5 * scale)
                .opacity(0.6)
            Text(TimeFormatting.session(sessionElapsed))
                .monospacedDigit()
        }
        .font(.system(size: 18 * scale, weight: .medium, design: .rounded))
        .opacity(0.8)
    }
}

/// The analog clock's dial and hands, drawn on a Canvas.
enum AnalogDial {
    static func draw(in gc: inout GraphicsContext, center c: CGPoint, radius r: CGFloat, hands: AnalogHands) {
        func point(_ degrees: Double, _ distance: CGFloat) -> CGPoint {
            let a = degrees * .pi / 180
            return CGPoint(x: c.x + distance * CGFloat(sin(a)), y: c.y - distance * CGFloat(cos(a)))
        }
        let ink = Color(hex: 0x33262A)

        // Shadow and wooden rim.
        let shadowCenter = CGPoint(x: c.x, y: c.y + r * 0.05)
        gc.fill(Path(ellipseIn: circleRect(shadowCenter, r * 1.15)), with: .radialGradient(
            Gradient(colors: [.black.opacity(0.5), .black.opacity(0)]),
            center: shadowCenter, startRadius: r * 0.9, endRadius: r * 1.15))
        gc.fill(Path(ellipseIn: circleRect(c, r)), with: .linearGradient(
            Gradient(colors: [Color(hex: 0x6A4A3C), Color(hex: 0x2E201E)]),
            startPoint: CGPoint(x: c.x, y: c.y - r), endPoint: CGPoint(x: c.x, y: c.y + r)))

        // Paper dial, warmer toward the lamp side.
        let face = r * 0.92
        gc.fill(Path(ellipseIn: circleRect(c, face)), with: .radialGradient(
            Gradient(colors: [Color(hex: 0xF5EBD8), Color(hex: 0xDCCAAA)]),
            center: CGPoint(x: c.x - face * 0.3, y: c.y - face * 0.35), startRadius: 0, endRadius: face * 1.5))

        var minorTicks = Path(), majorTicks = Path()
        for i in 0..<60 {
            let major = i.isMultiple(of: 5)
            let degrees = Double(i) * 6
            if major {
                majorTicks.move(to: point(degrees, face * 0.80))
                majorTicks.addLine(to: point(degrees, face * 0.93))
            } else {
                minorTicks.move(to: point(degrees, face * 0.88))
                minorTicks.addLine(to: point(degrees, face * 0.93))
            }
        }
        gc.stroke(minorTicks, with: .color(ink.opacity(0.35)), lineWidth: max(0.8, r * 0.008))
        gc.stroke(majorTicks, with: .color(ink.opacity(0.85)), style: StrokeStyle(lineWidth: r * 0.024, lineCap: .round))

        for (numeral, degrees) in [("12", 0.0), ("3", 90.0), ("6", 180.0), ("9", 270.0)] {
            gc.draw(Text(numeral)
                        .font(.system(size: r * 0.17, weight: .medium, design: .rounded))
                        .foregroundStyle(ink),
                    at: point(degrees, face * 0.63))
        }
        gc.draw(Text("lofi")
                    .font(.system(size: r * 0.08, weight: .semibold, design: .rounded))
                    .italic()
                    .foregroundStyle(ink.opacity(0.45)),
                at: CGPoint(x: c.x, y: c.y + face * 0.32))

        func hand(_ degrees: Double, from back: CGFloat, to length: CGFloat, width: CGFloat, color: Color) {
            var path = Path()
            path.move(to: point(degrees + 180, back))
            path.addLine(to: point(degrees, length))
            gc.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
        }
        hand(hands.hour, from: face * 0.08, to: face * 0.5, width: r * 0.055, color: ink)
        hand(hands.minute, from: face * 0.08, to: face * 0.76, width: r * 0.038, color: ink)
        hand(hands.second, from: face * 0.2, to: face * 0.84, width: max(1, r * 0.012), color: Color(hex: 0xC9785A))
        gc.fill(Path(ellipseIn: circleRect(c, r * 0.04)), with: .color(Color(hex: 0xC9785A)))
        gc.fill(Path(ellipseIn: circleRect(c, r * 0.015)), with: .color(Color(hex: 0xF5EBD8)))

        // Glass glare.
        var glare = Path()
        glare.addArc(center: c, radius: face * 0.86, startAngle: .degrees(200), endAngle: .degrees(265), clockwise: false)
        gc.stroke(glare, with: .color(.white.opacity(0.18)), style: StrokeStyle(lineWidth: r * 0.03, lineCap: .round))
    }
}
