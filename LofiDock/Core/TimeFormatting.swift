import Foundation

enum TimeFormatting {
    /// Session length as H:MM:SS. Hours keep counting past 24 instead of wrapping.
    static func session(_ interval: TimeInterval) -> String {
        let total = interval.isFinite ? Int(max(0, interval)) : 0
        return String(format: "%d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }

    /// Countdown display: "25:00" under an hour, "1:05:00" from an hour up.
    /// Rounds up, so a fresh 25-minute timer reads 25:00 and its last second 0:01.
    static func countdown(_ remaining: TimeInterval) -> String {
        let total = remaining.isFinite ? Int(max(0, remaining).rounded(.up)) : 0
        let hours = total / 3600, minutes = (total % 3600) / 60, seconds = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds)
            : String(format: "%d:%02d", minutes, seconds)
    }

    struct Clock: Equatable {
        var time: String
        /// Localized AM/PM marker when the clock is 12-hour; nil for 24-hour.
        var period: String?
    }

    /// The time split in two so the AM/PM marker can be set smaller.
    /// `.autoupdatingCurrent` carries the iOS "24-Hour Time" switch, so the
    /// hour cycle follows the phone's setting, not just its region.
    static func clock(
        _ date: Date,
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> Clock {
        let hourPattern = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: locale) ?? "h a"
        let twelveHour = hourPattern.contains("h") || hourPattern.contains("K")

        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        guard twelveHour else {
            formatter.dateFormat = "HH:mm"
            return Clock(time: formatter.string(from: date), period: nil)
        }
        formatter.dateFormat = "h:mm"
        let time = formatter.string(from: date)
        formatter.dateFormat = "a"
        return Clock(time: time, period: formatter.string(from: date))
    }

    /// "Saturday, November 21", in the phone's language.
    static func dateLine(
        _ date: Date,
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> String {
        var style = Date.FormatStyle.dateTime.weekday(.wide).month(.wide).day()
        style.locale = locale
        style.timeZone = timeZone
        return date.formatted(style)
    }
} 
