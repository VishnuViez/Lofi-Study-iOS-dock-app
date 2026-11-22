import Foundation

/// The hours during which the dock dims itself, as minutes after midnight.
/// A window that crosses midnight (22:00 to 07:00) is the usual case.
struct NightSchedule: Equatable {
    var startMinute: Int
    var endMinute: Int

    /// Start is inclusive, end exclusive. Equal start and end means no night.
    func contains(_ date: Date, calendar: Calendar = .autoupdatingCurrent) -> Bool {
        guard startMinute != endMinute else { return false }
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let minute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        if startMinute < endMinute {
            return minute >= startMinute && minute < endMinute
        }
        return minute >= startMinute || minute < endMinute
    }
} 
