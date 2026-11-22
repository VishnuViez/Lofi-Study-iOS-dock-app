import Foundation

/// Hand angles in degrees, clockwise from 12. Each hand includes the fraction
/// of the smaller unit, so hands sweep instead of jumping.
struct AnalogHands: Equatable {
    var hour: Double
    var minute: Double
    var second: Double

    init(date: Date, calendar: Calendar = .autoupdatingCurrent) {
        let parts = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: date)
        let seconds = Double(parts.second ?? 0) + Double(parts.nanosecond ?? 0) / 1e9
        let minutes = Double(parts.minute ?? 0) + seconds / 60
        let hours = Double((parts.hour ?? 0) % 12) + minutes / 60
        second = seconds * 6
        minute = minutes * 6
        hour = hours * 30
    }
} 
