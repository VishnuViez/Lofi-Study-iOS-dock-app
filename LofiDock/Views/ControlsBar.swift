import SwiftUI

/// The bar a tap brings up: which face is showing (tap to go to the next),
/// mute, rain and vinyl toggles, settings, and a bolt while charging.
struct ControlsBar: View {
    let face: ClockFace
    @Binding var muted: Bool
    @Binding var rainOn: Bool
    @Binding var vinylOn: Bool
    let isCharging: Bool
    var onNextFace: () -> Void
    var onSettings: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            Button(action: onNextFace) {
                HStack(spacing: 7) {
                    ForEach(ClockFace.allCases) { option in
                        Circle()
                            .fill(Palette.cream.opacity(option == face ? 0.9 : 0.3))
                            .frame(width: 6, height: 6)
                    }
                    Text(face.title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Palette.cream.opacity(0.9))
                        .padding(.leading, 4)
                }
                .padding(.horizontal, 10)
                .frame(height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Clock face: \(face.title). Next face")

            Rectangle().fill(Palette.cream.opacity(0.18)).frame(width: 1, height: 22).padding(.horizontal, 4)

            iconButton(muted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                       tint: muted ? Color(hex: 0xFF9C80) : Palette.cream.opacity(0.85)) { muted.toggle() }
                .accessibilityLabel("Mute all sound")
                .accessibilityValue(muted ? "On" : "Off")
            toggle("cloud.rain.fill", isOn: $rainOn, label: "Rain sound")
            toggle("opticaldisc.fill", isOn: $vinylOn, label: "Vinyl crackle")
            iconButton("gearshape.fill", action: onSettings)
                .accessibilityLabel("Settings")
            if isCharging {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.lamp.opacity(0.8))
                    .frame(width: 26, height: 44)
                    .accessibilityLabel("Charging")
            }
        }
        .padding(.horizontal, 10)
        .background(Capsule().fill(Color(hex: 0x15101C, opacity: 0.82)))
        .overlay(Capsule().stroke(Palette.cream.opacity(0.08), lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
    }

    /// While muted, tapping a sound unmutes and turns that sound on, so the
    /// tap always does what the icon suggests: play this.
    private func toggle(_ symbol: String, isOn: Binding<Bool>, label: LocalizedStringKey) -> some View {
        iconButton(symbol, tint: Palette.cream.opacity(isOn.wrappedValue && !muted ? 0.9 : 0.3)) {
            if muted {
                muted = false
                isOn.wrappedValue = true
            } else {
                isOn.wrappedValue.toggle()
            }
        }
        .accessibilityLabel(label)
        .accessibilityValue(isOn.wrappedValue ? "On" : "Off")
    }

    /// The tint is a parameter rather than a modifier applied by the caller:
    /// a foregroundStyle set here would override any applied outside.
    private func iconButton(_ symbol: String, tint: Color = Palette.cream.opacity(0.85),
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .medium))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(tint)
    }
} 
