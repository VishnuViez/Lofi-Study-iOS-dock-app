import SwiftUI

@main
struct LofiDockApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// Wires the app lifecycle to the session clock, dock behaviour, frame
/// budget, countdown timer and sound.
struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var session = SessionClock()
    @State private var screen = ScreenAwakeController()
    @State private var thermal = ThermalMonitor()
    @State private var timers = TimerController()
    @State private var checklist = ChecklistStore()
    @State private var ambience = AmbiencePlayer()
    @AppStorage(Pref.rain) private var rainOn = Pref.Default.rain
    @AppStorage(Pref.vinyl) private var vinylOn = Pref.Default.vinyl
    @AppStorage(Pref.muted) private var muted = Pref.Default.muted
    @AppStorage(Pref.adaptiveMotion) private var adaptiveMotion = Pref.Default.adaptiveMotion
    @AppStorage(Pref.awakeOnlyWhileCharging) private var awakeOnlyWhileCharging = Pref.Default.awakeOnlyWhileCharging

    var body: some View {
        DockScreen(session: session, isCharging: screen.isCharging)
            .environment(timers)
            .environment(checklist)
            .environment(\.framesPerSecond, AnimationBudget.framesPerSecond(
                thermal: thermal.state, lowPowerMode: thermal.lowPowerMode, adaptive: adaptiveMotion))
            .statusBarHidden()
            .persistentSystemOverlays(.hidden)
            .preferredColorScheme(.dark)
            .onAppear {
                let ambience = ambience
                timers.onAlertStart = { ambience.startAlarm() }
                timers.onAlertStop = { ambience.stopAlarm() }
            }
            .onChange(of: scenePhase, initial: true) { _, phase in
                switch phase {
                case .active:
                    session.appDidBecomeActive()
                    screen.start()
                    thermal.start()
                    timers.refresh()
                    ambience.setMuted(muted)
                    ambience.setSources(rain: rainOn, vinyl: vinylOn)
                    ambience.setForeground(true)
                case .background:
                    session.appDidEnterBackground()
                    ambience.stopAlarm()
                    ambience.setForeground(false)
                default:
                    break
                }
            }
            .onChange(of: rainOn) { ambience.setSources(rain: rainOn, vinyl: vinylOn) }
            .onChange(of: vinylOn) { ambience.setSources(rain: rainOn, vinyl: vinylOn) }
            .onChange(of: muted) { ambience.setMuted(muted) }
            .onChange(of: awakeOnlyWhileCharging, initial: true) {
                screen.onlyWhileCharging = awakeOnlyWhileCharging
            }
    }
} 
