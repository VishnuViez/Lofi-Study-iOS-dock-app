import Foundation
import Testing
@testable import LofiDock

struct TimeFormattingTests {
    let utc = TimeZone(identifier: "UTC")!

    func date(_ hour: Int, _ minute: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        return calendar.date(from: DateComponents(year: 2026, month: 11, day: 21, hour: hour, minute: minute))!
    }

    @Test(arguments: zip(
        [0, 59.9, 3_725, -4, 360_000, .nan],
        ["0:00:00", "0:00:59", "1:02:05", "0:00:00", "100:00:00", "0:00:00"]
    ))
    func sessionLength(_ interval: TimeInterval, _ expected: String) {
        #expect(TimeFormatting.session(interval) == expected)
    }

    @Test func twelveHourLocaleSplitsOutThePeriod() {
        let clock = TimeFormatting.clock(date(21, 41), locale: Locale(identifier: "en_US"), timeZone: utc)
        #expect(clock == TimeFormatting.Clock(time: "9:41", period: "PM"))
    }

    @Test func midnightReadsTwelveOnATwelveHourClock() {
        let clock = TimeFormatting.clock(date(0, 5), locale: Locale(identifier: "en_US"), timeZone: utc)
        #expect(clock == TimeFormatting.Clock(time: "12:05", period: "AM"))
    }

    @Test func twentyFourHourLocaleHasNoPeriod() {
        let clock = TimeFormatting.clock(date(21, 41), locale: Locale(identifier: "en_GB"), timeZone: utc)
        #expect(clock == TimeFormatting.Clock(time: "21:41", period: nil))
    }

    @Test func dateLineNamesTheDay() {
        let line = TimeFormatting.dateLine(date(9, 0), locale: Locale(identifier: "en_US"), timeZone: utc)
        #expect(line == "Saturday, November 21")
    }
} 
