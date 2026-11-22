import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Pref.face) private var face = Pref.Default.face
    @AppStorage(Pref.nightDimming) private var nightDimming = Pref.Default.nightDimming
    @AppStorage(Pref.nightStart) private var nightStart = Pref.Default.nightStart
    @AppStorage(Pref.nightEnd) private var nightEnd = Pref.Default.nightEnd
    @AppStorage(Pref.burnInShift) private var burnInShift = Pref.Default.burnInShift
    @AppStorage(Pref.adaptiveMotion) private var adaptiveMotion = Pref.Default.adaptiveMotion
    @AppStorage(Pref.rain) private var rainOn = Pref.Default.rain
    @AppStorage(Pref.vinyl) private var vinylOn = Pref.Default.vinyl
    @AppStorage(Pref.muted) private var muted = Pref.Default.muted
    @AppStorage(Pref.rainVisual) private var rainVisual = Pref.Default.rainVisual
    @AppStorage(Pref.awakeOnlyWhileCharging) private var awakeOnlyWhileCharging = Pref.Default.awakeOnlyWhileCharging

    var body: some View {
        NavigationStack {
            Form {
                Section("Clock") {
                    Picker("Face", selection: $face) {
                        ForEach(ClockFace.allCases) { Text($0.title).tag($0) }
                    }
                }

                Section {
                    Toggle("Only while charging", isOn: $awakeOnlyWhileCharging)
                } header: {
                    Text("Keep screen on")
                } footer: {
                    Text(awakeOnlyWhileCharging
                         ? "The screen stays on while the phone is charging. Off the charger it follows your Auto-Lock setting."
                         : "The screen stays on whenever Lofi Dock is open, whatever Auto-Lock is set to. Off the charger that uses more battery.")
                }

                Section {
                    Toggle("Night dimming", isOn: $nightDimming)
                    if nightDimming {
                        DatePicker("From", selection: time($nightStart), displayedComponents: .hourAndMinute)
                        DatePicker("Until", selection: time($nightEnd), displayedComponents: .hourAndMinute)
                    }
                } footer: {
                    Text("Dims the screen and warms its colours during these hours, so the clock doesn't light up a dark room.")
                }

                Section {
                    Toggle("Rain on the window", isOn: $rainVisual)
                } footer: {
                    Text("The falling-rain animation. The rain sound has its own switch under Sound.")
                }

                Section {
                    Toggle("Burn-in protection", isOn: $burnInShift)
                } footer: {
                    Text("Shifts the picture a few pixels every minute. Worth keeping on for OLED iPhones; harmless on LCD models.")
                }

                Section {
                    Toggle("Ease off when warm", isOn: $adaptiveMotion)
                } footer: {
                    Text("Slows the background animation when the phone heats up on the charger, or in Low Power Mode. The clock keeps exact time either way.")
                }

                Section {
                    Toggle("Mute all sound", isOn: $muted)
                    Toggle("Rain", isOn: $rainOn).disabled(muted)
                    Toggle("Vinyl crackle", isOn: $vinylOn).disabled(muted)
                } header: {
                    Text("Sound")
                } footer: {
                    Text("Mute also silences the timer chime. A finished timer still blinks and vibrates.")
                }

                Section("Open on charge") {
                    Text("To open Lofi Dock whenever the phone goes on a charger: Shortcuts app → Automation → New → Charger → Is Connected → Run Immediately, then add the action Open App → Lofi Dock.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Lofi Dock")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    /// Adapts minutes-after-midnight storage to a time picker.
    private func time(_ minutes: Binding<Int>) -> Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: minutes.wrappedValue / 60, minute: minutes.wrappedValue % 60,
                                      second: 0, of: .now) ?? .now
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                minutes.wrappedValue = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            }
        )
    }
}
