import CoreGraphics
import Foundation
import Testing
@testable import LofiDock

struct BurnInDriftTests {
    /// A date exactly on a minute boundary.
    let minuteStart = Date(timeIntervalSinceReferenceDate: 60 * 13_000_000)

    @Test func holdsStillWithinAMinute() {
        let start = BurnInDrift.offset(at: minuteStart)
        #expect(BurnInDrift.offset(at: minuteStart.addingTimeInterval(59)) == start)
    }

    @Test func staysWithinTheAmplitude() {
        for minute in 0..<120 {
            let o = BurnInDrift.offset(at: minuteStart.addingTimeInterval(Double(minute) * 60), amplitude: 6)
            #expect(abs(o.width) <= 6 && abs(o.height) <= 6)
        }
    }

    @Test func visitsManyPositionsPerLoop() {
        let positions = Set((0..<BurnInDrift.stepsPerLoop).map { minute -> String in
            let o = BurnInDrift.offset(at: minuteStart.addingTimeInterval(Double(minute) * 60))
            return "\(Int((o.width * 100).rounded())),\(Int((o.height * 100).rounded()))"
        })
        #expect(positions.count >= 10)
    }

    @Test func handlesDatesBeforeTheReferenceDate() {
        let o = BurnInDrift.offset(at: Date(timeIntervalSinceReferenceDate: -90), amplitude: 6)
        #expect(abs(o.width) <= 6 && abs(o.height) <= 6)
    }
} 
