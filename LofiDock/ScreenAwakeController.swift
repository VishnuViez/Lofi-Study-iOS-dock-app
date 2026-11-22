#if canImport(UIKit)
import Observation
import UIKit

/// Holds the display on while Lofi Dock is in front, overriding the phone's
/// Auto-Lock setting (optionally only while charging), and tracks charging
/// for the bolt in the controls.
///
/// iOS honours `isIdleTimerDisabled` only for the foreground app and drops it
/// when the app leaves, so it is re-applied on every activation, on every
/// charger change, and once a minute in case a system presentation reset it.
@MainActor
@Observable
final class ScreenAwakeController {
    private(set) var isCharging = false
    var onlyWhileCharging = false {
        didSet { apply() }
    }

    @ObservationIgnored private var batteryToken: NSObjectProtocol?
    @ObservationIgnored private var reassert: Timer?

    /// Safe to call on every activation; registers once, re-applies each time.
    func start() {
        if batteryToken == nil {
            UIDevice.current.isBatteryMonitoringEnabled = true
            batteryToken = NotificationCenter.default.addObserver(
                forName: UIDevice.batteryStateDidChangeNotification, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
        }
        if reassert == nil {
            reassert = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.apply() }
            }
        }
        refresh()
    }

    private func refresh() {
        let state = UIDevice.current.batteryState
        isCharging = state == .charging || state == .full
        apply()
    }

    private func apply() {
        UIApplication.shared.isIdleTimerDisabled =
            ScreenAwake.shouldStayOn(onlyWhileCharging: onlyWhileCharging, isCharging: isCharging)
    }
}
#endif 
