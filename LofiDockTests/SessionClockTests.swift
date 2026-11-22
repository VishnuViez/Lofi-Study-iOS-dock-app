import Foundation
import Testing
@testable import LofiDock

struct SessionClockTests {
    let launch = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test func countsUpFromLaunch() {
        let clock = SessionClock(now: launch)
        #expect(clock.elapsed(at: launch.addingTimeInterval(125)) == 125)
    }

    @Test func neverReportsNegativeTime() {
        let clock = SessionClock(now: launch)
        #expect(clock.elapsed(at: launch.addingTimeInterval(-10)) == 0)
    }

    @Test func leavingTheAppStartsAFreshSessionOnReturn() {
        let clock = SessionClock(now: launch)
        clock.appDidEnterBackground()
        let back = launch.addingTimeInterval(3_600)
        clock.appDidBecomeActive(now: back)
        #expect(clock.startedAt == back)
        #expect(clock.elapsed(at: back.addingTimeInterval(5)) == 5)
    }

    /// Launch activation, Control Center, a notification pulled down: all
    /// become active again without ever backgrounding.
    @Test func becomingActiveWithoutLeavingKeepsTheSession() {
        let clock = SessionClock(now: launch)
        clock.appDidBecomeActive(now: launch.addingTimeInterval(30))
        #expect(clock.startedAt == launch)
    }

    @Test func eachExitResetsOnlyOnce() {
        let clock = SessionClock(now: launch)
        clock.appDidEnterBackground()
        let back = launch.addingTimeInterval(60)
        clock.appDidBecomeActive(now: back)
        clock.appDidBecomeActive(now: back.addingTimeInterval(90))
        #expect(clock.startedAt == back)
    }
} 
