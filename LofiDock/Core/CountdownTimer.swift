import Foundation

/// A kitchen-timer countdown: pick a length, start, pause, resume, cancel.
/// A pure value; TimerController adds scheduling, notifications and sound.
struct CountdownTimer: Equatable {
    enum Phase: Equatable {
        case idle
        case running(endsAt: Date)
        case paused(remaining: TimeInterval)
        case finished(at: Date)
    }

    /// Total length of the current (or last) run.
    private(set) var length: TimeInterval
    private(set) var phase: Phase

    init(length: TimeInterval = 0, phase: Phase = .idle) {
        self.length = length
        self.phase = phase
    }

    var isRunning: Bool {
        if case .running = phase { return true }
        return false
    }

    var isPaused: Bool {
        if case .paused = phase { return true }
        return false
    }

    var isFinished: Bool {
        if case .finished = phase { return true }
        return false
    }

    mutating func start(length: TimeInterval, now: Date) {
        guard length >= 1 else { return }
        self.length = length
        phase = .running(endsAt: now.addingTimeInterval(length))
    }

    mutating func pause(now: Date) {
        guard case .running(let end) = phase else { return }
        phase = .paused(remaining: max(0, end.timeIntervalSince(now)))
    }

    mutating func resume(now: Date) {
        guard case .paused(let remaining) = phase else { return }
        phase = .running(endsAt: now.addingTimeInterval(remaining))
    }

    mutating func cancel() {
        phase = .idle
    }

    /// Moves a running timer to finished once its end has passed.
    /// Returns true only on that transition.
    @discardableResult
    mutating func update(now: Date) -> Bool {
        guard case .running(let end) = phase, now >= end else { return false }
        phase = .finished(at: end)
        return true
    }

    func remaining(at now: Date) -> TimeInterval {
        switch phase {
        case .idle: length
        case .running(let end): max(0, end.timeIntervalSince(now))
        case .paused(let remaining): remaining
        case .finished: 0
        }
    }

    /// Share of the run still to go, from 1 down to 0.
    func fractionRemaining(at now: Date) -> Double {
        guard length > 0 else { return 0 }
        return min(1, max(0, remaining(at: now) / length))
    }
}
