import Foundation
import Observation
import UserNotifications

/// Runs the countdown: fires the alert at the end while the app is open, and
/// schedules a notification so the end is still announced if you've left.
@MainActor
@Observable
final class TimerController {
    private(set) var timer: CountdownTimer
    /// The length on the wheels, remembered between launches.
    var pickedLength: TimeInterval {
        didSet { UserDefaults.standard.set(pickedLength, forKey: Pref.timerLength) }
    }

    /// Called when the countdown ends while the app is open, and when the
    /// alert is stopped. RootView wires these to the chime.
    @ObservationIgnored var onAlertStart: (() -> Void)?
    @ObservationIgnored var onAlertStop: (() -> Void)?
    @ObservationIgnored private var finishWork: DispatchWorkItem?
    private static let notificationID = "lofidock.timer"

    init(timer: CountdownTimer = CountdownTimer()) {
        self.timer = timer
        let stored = UserDefaults.standard.double(forKey: Pref.timerLength)
        pickedLength = stored >= 1 ? stored : Pref.Default.timerLength
    }

    func start(muted: Bool) {
        timer.start(length: pickedLength, now: .now)
        armFinish()
        scheduleNotification(muted: muted)
    }

    func pause() {
        timer.pause(now: .now)
        disarm()
    }

    func resume(muted: Bool) {
        timer.resume(now: .now)
        armFinish()
        scheduleNotification(muted: muted)
    }

    /// Back to idle from any phase, silencing a ringing alert.
    func cancel() {
        let wasRinging = timer.isFinished
        timer.cancel()
        disarm()
        if wasRinging { onAlertStop?() }
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [Self.notificationID])
    }

    /// Catches up after time in the background. A timer that ended while the
    /// app was away is marked finished quietly; its notification already rang.
    func refresh() {
        if !timer.update(now: .now) { armFinish() }
    }

    private func armFinish() {
        finishWork?.cancel()
        guard case .running(let end) = timer.phase else { return }
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.fire() }
        }
        finishWork = work
        DispatchQueue.main.asyncAfter(wallDeadline: .now() + max(0, end.timeIntervalSinceNow), execute: work)
    }

    private func fire() {
        guard case .running(let end) = timer.phase else { return }
        guard timer.update(now: .now) else { return armFinish() }  // woke a hair early
        // A work item that was overdue because the app was suspended shouldn't
        // start ringing on return; the notification covered it.
        if Date.now.timeIntervalSince(end) < 5 { onAlertStart?() }
    }

    private func disarm() {
        finishWork?.cancel()
        finishWork = nil
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
    }

    private func scheduleNotification(muted: Bool) {
        guard case .running(let end) = timer.phase else { return }
        let content = UNMutableNotificationContent()
        content.title = "Time's up"
        content.body = "Your \(TimeFormatting.countdown(timer.length)) timer has finished."
        if !muted {
            content.sound = UNNotificationSound(named: UNNotificationSoundName(ChimeFile.name))
        }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, end.timeIntervalSinceNow), repeats: false)
        let request = UNNotificationRequest(identifier: Self.notificationID, content: content, trigger: trigger)
        let center = UNUserNotificationCenter.current()
        // Asks once (the first Start); later calls return the stored answer.
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            if granted { center.add(request) }
        }
    }
}
