import Foundation
import Observation

/// How long the current study session has run.
///
/// A session lasts while the app stays in front. Leaving it (home gesture,
/// app switcher, lock button) ends the session, and the next return starts a
/// fresh one at zero. Being only partly covered (Control Center, a pulled-down
/// notification) makes the app inactive without backgrounding it, so those
/// leave the session running.
@Observable
final class SessionClock {
    private(set) var startedAt: Date
    @ObservationIgnored private var leftApp = false

    init(now: Date = .now) {
        startedAt = now
    }

    func elapsed(at date: Date) -> TimeInterval {
        max(0, date.timeIntervalSince(startedAt))
    }

    func appDidEnterBackground() {
        leftApp = true
    }

    func appDidBecomeActive(now: Date = .now) {
        guard leftApp else { return }
        leftApp = false
        startedAt = now
    }
} 
