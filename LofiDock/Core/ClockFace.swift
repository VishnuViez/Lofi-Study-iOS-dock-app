import Foundation

/// The selectable dock faces, in swipe order.
enum ClockFace: String, CaseIterable, Identifiable {
    case room
    case digits
    case analog
    case flip
    case timer
    case checklist

    var id: String { rawValue }

    var title: String {
        switch self {
        case .room: "Lofi Room"
        case .digits: "Big Digits"
        case .analog: "Analog"
        case .flip: "Flip"
        case .timer: "Timer"
        case .checklist: "Checklist"
        }
    }

    /// The face `step` places along, wrapping at both ends.
    func cycled(by step: Int) -> ClockFace {
        let all = Self.allCases
        let index = all.firstIndex(of: self)!
        let count = all.count
        return all[((index + step) % count + count) % count]
    }
} 
