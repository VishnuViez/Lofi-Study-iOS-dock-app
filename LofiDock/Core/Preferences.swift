import Foundation

/// UserDefaults keys and defaults, shared by every @AppStorage that reads them
/// so the views can't disagree about a default.
enum Pref {
    static let face = "clock.face"
    static let nightDimming = "night.enabled"
    static let nightStart = "night.startMinute"
    static let nightEnd = "night.endMinute"
    static let burnInShift = "display.burnInShift"
    static let adaptiveMotion = "display.adaptiveMotion"
    static let rain = "ambience.rain"
    static let vinyl = "ambience.vinyl"
    static let muted = "ambience.muted"
    static let rainVisual = "display.rainVisual"
    static let timerLength = "timer.lengthSeconds"
    static let checklist = "checklist.items"
    static let awakeOnlyWhileCharging = "display.awakeOnlyWhileCharging"

    enum Default {
        static let awakeOnlyWhileCharging = false
        static let muted = false
        static let rainVisual = true
        static let timerLength: TimeInterval = 25 * 60
        static let face = ClockFace.room
        static let nightDimming = true
        static let nightStart = 22 * 60
        static let nightEnd = 7 * 60
        static let burnInShift = true
        static let adaptiveMotion = true
        static let rain = true
        static let vinyl = true
    }
}
