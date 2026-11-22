import Foundation

/// Whether to hold the display on. While Lofi Dock is in front it overrides
/// the phone's Auto-Lock setting; "Only while charging" narrows that to when
/// the phone is on a charger.
enum ScreenAwake {
    static func shouldStayOn(onlyWhileCharging: Bool, isCharging: Bool) -> Bool {
        !onlyWhileCharging || isCharging
    }
}
