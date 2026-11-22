import SwiftUI

/// Placement as fractions of the canvas, so the iPhone 15 layout
/// (852 × 393 pt landscape) scales to other phones.
enum DockMetrics {
    static func scale(for size: CGSize) -> CGFloat {
        min(size.width / 852, size.height / 393)
    }

    /// The bare wall right of the window in the Lofi Room face. The trailing
    /// margin clears the 59 pt Dynamic Island inset, on either side in landscape.
    static func clockPanel(in size: CGSize) -> CGRect {
        let minX = size.width * 0.53
        let maxX = size.width - 64 * scale(for: size)
        return CGRect(x: minX, y: size.height * 0.1, width: maxX - minX, height: size.height * 0.56)
    }

    /// A start date on a whole second, so the clock ticks with the wall clock.
    static func wholeSecond(_ date: Date = .now) -> Date {
        Date(timeIntervalSinceReferenceDate: date.timeIntervalSinceReferenceDate.rounded(.down))
    }
}

/// Night look: everything multiplied toward a deep amber-red (StandBy's night
/// mode idea, in the lofi palette) and darkened. Done in the view rather than
/// by lowering screen brightness, because an app's brightness change outlives
/// the app until the phone locks.
enum NightMode {
    static let tint = Color(red: 1, green: 0.45, blue: 0.35)
    static let darkening = 0.45
}

/// One face at one moment, with burn-in drift and night dimming applied.
/// Shared by the live screen and the macOS preview renderer.
struct DockFrame: View {
    let face: ClockFace
    let size: CGSize
    let date: Date
    let sessionElapsed: TimeInterval
    var recordSpinning = true
    var burnInShift = true
    var night = false

    var body: some View {
        let drift = burnInShift ? BurnInDrift.offset(at: date, amplitude: 6 * DockMetrics.scale(for: size)) : .zero
        faceView
            .frame(width: size.width, height: size.height)
            // Slightly oversized so drifting never uncovers an edge.
            .animation(.easeInOut(duration: 3)) { content in
                content
                    .scaleEffect(burnInShift ? 1.03 : 1)
                    .offset(drift)
            }
            .animation(.easeInOut(duration: 2)) { content in
                content
                    .colorMultiply(night ? NightMode.tint : .white)
                    .overlay(Color.black.opacity(night ? NightMode.darkening : 0).allowsHitTesting(false))
            }
            .frame(width: size.width, height: size.height)
            .clipped()
    }

    @ViewBuilder private var faceView: some View {
        switch face {
        case .room:
            LofiRoomFace(date: date, sessionElapsed: sessionElapsed, size: size, recordSpinning: recordSpinning)
        case .digits:
            BigDigitsFace(date: date, sessionElapsed: sessionElapsed, size: size)
        case .analog:
            AnalogFace(date: date, sessionElapsed: sessionElapsed, size: size)
        case .flip:
            FlipFace(date: date, sessionElapsed: sessionElapsed, size: size)
        case .timer:
            TimerFace(date: date, sessionElapsed: sessionElapsed, size: size)
        case .checklist:
            ChecklistFace(date: date, sessionElapsed: sessionElapsed, size: size)
        }
    }
}

/// The live dock: swipe sideways to change face, tap to show the controls.
struct DockScreen: View {
    let session: SessionClock
    let isCharging: Bool

    @AppStorage(Pref.face) private var face = Pref.Default.face
    @AppStorage(Pref.nightDimming) private var nightDimming = Pref.Default.nightDimming
    @AppStorage(Pref.nightStart) private var nightStart = Pref.Default.nightStart
    @AppStorage(Pref.nightEnd) private var nightEnd = Pref.Default.nightEnd
    @AppStorage(Pref.burnInShift) private var burnInShift = Pref.Default.burnInShift
    @AppStorage(Pref.rain) private var rainOn = Pref.Default.rain
    @AppStorage(Pref.vinyl) private var vinylOn = Pref.Default.vinyl
    @AppStorage(Pref.muted) private var muted = Pref.Default.muted
    @AppStorage(Pref.rainVisual) private var rainVisual = Pref.Default.rainVisual
    @Environment(TimerController.self) private var timers

    @State private var controlsVisible = false
    @State private var hideControls: Task<Void, Never>?
    @State private var showSettings = false
    @State private var arrivalEdge: Edge = .trailing

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.periodic(from: DockMetrics.wholeSecond(), by: 1)) { timeline in
                let night = nightDimming
                    && NightSchedule(startMinute: nightStart, endMinute: nightEnd).contains(timeline.date)
                ZStack(alignment: .topTrailing) {
                    DockFrame(face: face, size: geometry.size, date: timeline.date,
                              sessionElapsed: session.elapsed(at: timeline.date),
                              recordSpinning: vinylOn && !muted, burnInShift: burnInShift, night: night)
                        .environment(\.showsRain, rainVisual)
                        .id(face)
                        .transition(.push(from: arrivalEdge))
                    if face != .timer, timers.timer.phase != .idle {
                        TimerChip(timer: timers.timer, now: timeline.date) {
                            if timers.timer.isFinished { timers.cancel() } else { showFace(.timer) }
                        }
                        .colorMultiply(night ? NightMode.tint : .white)
                        .padding(.top, 16)
                        .padding(.trailing, 72 * DockMetrics.scale(for: geometry.size))
                        .transition(.opacity)
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if controlsVisible {
                    ControlsBar(face: face, muted: $muted, rainOn: $rainOn, vinylOn: $vinylOn, isCharging: isCharging,
                                onNextFace: { switchFace(by: 1) },
                                onSettings: { showSettings = true; scheduleHide() })
                        .padding(.bottom, 18)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .ignoresSafeArea()
        .background(Color.black)
        .contentShape(Rectangle())
        .onTapGesture { controlsVisible ? hide() : show() }
        .gesture(DragGesture(minimumDistance: 30).onEnded(swiped))
        .onChange(of: rainOn) { scheduleHide() }
        .onChange(of: vinylOn) { scheduleHide() }
        .onChange(of: muted) { scheduleHide() }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Next clock face") { switchFace(by: 1) }
        .accessibilityAction(named: "Show controls") { show() }
    }

    private func swiped(_ value: DragGesture.Value) {
        let dx = value.translation.width
        guard abs(dx) > 60, abs(dx) > abs(value.translation.height) * 1.5 else { return }
        switchFace(by: dx < 0 ? 1 : -1)
    }

    private func switchFace(by step: Int) {
        arrivalEdge = step > 0 ? .trailing : .leading
        withAnimation(.easeInOut(duration: 0.45)) { face = face.cycled(by: step) }
        if controlsVisible { scheduleHide() }
    }

    private func showFace(_ target: ClockFace) {
        let all = ClockFace.allCases
        arrivalEdge = all.firstIndex(of: target)! > all.firstIndex(of: face)! ? .trailing : .leading
        withAnimation(.easeInOut(duration: 0.45)) { face = target }
    }

    private func show() {
        withAnimation(.easeOut(duration: 0.25)) { controlsVisible = true }
        scheduleHide()
    }

    private func hide() {
        hideControls?.cancel()
        withAnimation(.easeIn(duration: 0.3)) { controlsVisible = false }
    }

    /// Hides the controls 5 s after the last interaction, so the dock goes
    /// back to a clean clock on its own.
    private func scheduleHide() {
        hideControls?.cancel()
        hideControls = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.4)) { controlsVisible = false }
        }
    }
}
