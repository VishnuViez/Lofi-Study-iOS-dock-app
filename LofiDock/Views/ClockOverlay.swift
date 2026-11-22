import SwiftUI

struct ClockOverlay: View {
    let date: Date
    let sessionElapsed: TimeInterval
    var scale: CGFloat = 1

    var body: some View {
        let clock = TimeFormatting.clock(date)
        VStack(spacing: 4 * scale) {
            HStack(alignment: .firstTextBaseline, spacing: 6 * scale) {
                Text(clock.time)
                    .font(.system(size: 94 * scale, weight: .light, design: .rounded))
                    .monospacedDigit()
                if let period = clock.period {
                    Text(period)
                        .font(.system(size: 24 * scale, weight: .medium, design: .rounded))
                        .opacity(0.7)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.5)

            Text(TimeFormatting.dateLine(date))
                .font(.system(size: 16 * scale, weight: .medium, design: .rounded))
                .opacity(0.65)

            Capsule()
                .fill(Palette.cream.opacity(0.22))
                .frame(width: 36 * scale, height: 1.5 * scale)
                .padding(.vertical, 10 * scale)

            HStack(alignment: .firstTextBaseline, spacing: 10 * scale) {
                Text("SESSION")
                    .font(.system(size: 11 * scale, weight: .semibold, design: .rounded))
                    .tracking(2.5 * scale)
                    .opacity(0.55)
                Text(TimeFormatting.session(sessionElapsed))
                    .font(.system(size: 26 * scale, weight: .regular, design: .rounded))
                    .monospacedDigit()
            }
        }
        .foregroundStyle(Palette.cream)
        .shadow(color: .black.opacity(0.45), radius: 2 * scale, y: 1 * scale)
        .shadow(color: Palette.lamp.opacity(0.28), radius: 16 * scale)
        .accessibilityElement(children: .combine)
    }
}
