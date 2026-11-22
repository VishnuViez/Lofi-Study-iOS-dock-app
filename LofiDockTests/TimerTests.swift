import Foundation
import Testing
@testable import LofiDock

struct CountdownTimerTests {
    let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test func runsDownFromItsLength() {
        var timer = CountdownTimer()
        timer.start(length: 1_500, now: t0)
        #expect(timer.remaining(at: t0.addingTimeInterval(600)) == 900)
        #expect(timer.fractionRemaining(at: t0.addingTimeInterval(750)) == 0.5)
    }

    @Test func pauseFreezesAndResumeContinues() {
        var timer = CountdownTimer()
        timer.start(length: 300, now: t0)
        timer.pause(now: t0.addingTimeInterval(100))
        #expect(timer.remaining(at: t0.addingTimeInterval(5_000)) == 200)
        timer.resume(now: t0.addingTimeInterval(1_000))
        #expect(timer.remaining(at: t0.addingTimeInterval(1_050)) == 150)
    }

    @Test func finishesOnceItsEndPasses() {
        var timer = CountdownTimer()
        timer.start(length: 60, now: t0)
        let early = timer.update(now: t0.addingTimeInterval(59))
        let onTime = timer.update(now: t0.addingTimeInterval(61))
        #expect(!early && onTime)
        #expect(timer.phase == .finished(at: t0.addingTimeInterval(60)))
        let again = timer.update(now: t0.addingTimeInterval(62))
        #expect(!again)  // reports the transition only once
        #expect(timer.remaining(at: t0.addingTimeInterval(62)) == 0)
    }

    @Test func pausedTimerNeverFinishes() {
        var timer = CountdownTimer()
        timer.start(length: 60, now: t0)
        timer.pause(now: t0.addingTimeInterval(10))
        let finished = timer.update(now: t0.addingTimeInterval(3_600))
        #expect(!finished)
        #expect(timer.isPaused)
    }

    @Test func zeroLengthDoesNotStart() {
        var timer = CountdownTimer()
        timer.start(length: 0, now: t0)
        #expect(timer.phase == .idle)
    }

    @Test func cancelReturnsToIdleAndIgnoresStrayCalls() {
        var timer = CountdownTimer()
        timer.resume(now: t0)  // nothing to resume
        timer.pause(now: t0)   // nothing to pause
        #expect(timer.phase == .idle)
        timer.start(length: 60, now: t0)
        timer.cancel()
        #expect(timer.phase == .idle)
    }

    @Test(arguments: zip(
        [1_500, 0.2, 0, 3_900, 59.4, -3],
        ["25:00", "0:01", "0:00", "1:05:00", "1:00", "0:00"]
    ))
    func countdownText(_ remaining: TimeInterval, _ expected: String) {
        #expect(TimeFormatting.countdown(remaining) == expected)
    }
}

struct ChimeTests {
    let rate = 44_100.0

    @Test func isThreeSecondsAtTheIntendedPeak() {
        let samples = Chime.samples(sampleRate: rate)
        #expect(samples.count == Int(3 * rate))
        #expect(abs((samples.map(abs).max() ?? 0) - Chime.peak) < 1e-4)
    }

    @Test func startsAndEndsWithoutAClick() {
        let samples = Chime.samples(sampleRate: rate)
        #expect(abs(samples[0]) < 0.01)
        #expect(abs(samples[samples.count - 1]) < 0.001)
    }
}

struct WAVFileTests {
    @Test func headerDescribesTheSamples() {
        let data = WAVFile.data(channels: [[0, 0.5, -0.5], [1, -1, 0]], sampleRate: 48_000)
        #expect(data.count == 44 + 3 * 2 * 2)
        #expect(Array(data[0..<4]) == Array("RIFF".utf8))
        #expect(Array(data[8..<12]) == Array("WAVE".utf8))
        func u16(_ at: Int) -> Int { Int(data[at]) | Int(data[at + 1]) << 8 }
        #expect(u16(22) == 2)                          // channels
        #expect(u16(44 + 2) == 32_767)                 // first frame, right channel, full scale
    }
} 
