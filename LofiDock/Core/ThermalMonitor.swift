import Foundation
import Observation

/// Tracks the phone's thermal state and Low Power Mode for AnimationBudget.
@MainActor
@Observable
final class ThermalMonitor {
    private(set) var state = ProcessInfo.processInfo.thermalState
    private(set) var lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
    @ObservationIgnored private var tokens: [NSObjectProtocol] = []

    /// Safe to call on every activation; registers once, refreshes each time.
    func start() {
        if tokens.isEmpty {
            let center = NotificationCenter.default
            for name in [ProcessInfo.thermalStateDidChangeNotification, .NSProcessInfoPowerStateDidChange] {
                tokens.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.refresh() }
                })
            }
        }
        refresh()
    }

    private func refresh() {
        state = ProcessInfo.processInfo.thermalState
        lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
    }
}
