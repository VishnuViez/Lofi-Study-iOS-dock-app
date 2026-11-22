import Foundation
import Testing
@testable import LofiDock

struct NightScheduleTests {
    var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    func at(_ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 21, hour: hour, minute: minute))!
    }

    @Test(arguments: [(22, 0, true), (23, 59, true), (0, 0, true), (6, 59, true), (7, 0, false), (12, 0, false), (21, 59, false)])
    func overnightWindow(_ check: (hour: Int, minute: Int, isNight: Bool)) {
        let night = NightSchedule(startMinute: 22 * 60, endMinute: 7 * 60)
        #expect(night.contains(at(check.hour, check.minute), calendar: calendar) == check.isNight)
    }

    @Test func sameDayWindow() {
        let nap = NightSchedule(startMinute: 13 * 60, endMinute: 15 * 60)
        #expect(nap.contains(at(14), calendar: calendar))
        #expect(!nap.contains(at(15), calendar: calendar))
        #expect(!nap.contains(at(2), calendar: calendar))
    }

    @Test func equalStartAndEndMeansNoNight() {
        let none = NightSchedule(startMinute: 600, endMinute: 600)
        #expect(!none.contains(at(10), calendar: calendar))
        #expect(!none.contains(at(3), calendar: calendar))
    }
}

struct ScreenAwakeTests {
    @Test func staysOnRegardlessOfChargingByDefault() {
        #expect(ScreenAwake.shouldStayOn(onlyWhileCharging: false, isCharging: false))
        #expect(ScreenAwake.shouldStayOn(onlyWhileCharging: false, isCharging: true))
    }

    @Test func onlyWhileChargingFollowsTheCharger() {
        #expect(ScreenAwake.shouldStayOn(onlyWhileCharging: true, isCharging: true))
        #expect(!ScreenAwake.shouldStayOn(onlyWhileCharging: true, isCharging: false))
    }
}

struct AnimationBudgetTests {
    @Test func fullRateWhenCoolOrWhenAdaptiveIsOff() {
        #expect(AnimationBudget.framesPerSecond(thermal: .nominal, lowPowerMode: false, adaptive: true) == 30)
        #expect(AnimationBudget.framesPerSecond(thermal: .critical, lowPowerMode: true, adaptive: false) == 30)
    }

    @Test func backsOffAsThePhoneWarms() {
        let rates = [ProcessInfo.ThermalState.nominal, .fair, .serious, .critical].map {
            AnimationBudget.framesPerSecond(thermal: $0, lowPowerMode: false, adaptive: true)
        }
        #expect(rates == rates.sorted(by: >))
        #expect(rates.last! >= 1)
    }

    @Test func lowPowerModeSlowsTheScene() {
        #expect(AnimationBudget.framesPerSecond(thermal: .nominal, lowPowerMode: true, adaptive: true) < 30)
    }
}

struct AnalogHandsTests {
    var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    func hands(_ h: Int, _ m: Int, _ s: Int) -> AnalogHands {
        AnalogHands(date: calendar.date(from: DateComponents(year: 2026, month: 11, day: 21, hour: h, minute: m, second: s))!,
                    calendar: calendar)
    }

    @Test func threeOClock() {
        #expect(hands(15, 0, 0) == AnalogHands(hour: 90, minute: 0, second: 0))
    }

    @Test func halfPastNineSweepsTheHourHand() {
        let h = hands(9, 30, 0)
        #expect(h.hour == 285)
        #expect(h.minute == 180)
    }

    @Test func secondsMoveTheMinuteHand() {
        let h = hands(12, 0, 30)
        #expect(abs(h.hour - 0.25) < 1e-9)
        #expect(abs(h.minute - 3) < 1e-9)
        #expect(h.second == 180)
    }
}

struct ClockFaceTests {
    @Test func cyclesBothWaysAndWraps() {
        #expect(ClockFace.room.cycled(by: 1) == .digits)
        #expect(ClockFace.room.cycled(by: -1) == .checklist)
        #expect(ClockFace.checklist.cycled(by: 1) == .room)
        #expect(ClockFace.analog.cycled(by: 9) == .checklist)
    }

    /// Raw values are persisted in UserDefaults; renaming one would silently
    /// reset everyone's chosen face.
    @Test func rawValuesAreStable() {
        #expect(ClockFace.allCases.map(\.rawValue) == ["room", "digits", "analog", "flip", "timer", "checklist"])
    }
}

extension AnalogHands {
    init(hour: Double, minute: Double, second: Double) {
        self.init(date: .distantPast)
        self.hour = hour
        self.minute = minute
        self.second = second
    }
}
