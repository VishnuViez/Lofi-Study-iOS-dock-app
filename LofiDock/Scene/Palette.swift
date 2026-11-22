import SwiftUI

enum Palette {
    static let cream = Color(hex: 0xF6E7D0)
    static let lamp = Color(hex: 0xFFB45E)
    static let wallTop = Color(hex: 0x17122B)
    static let wallBottom = Color(hex: 0x2B1E3A)
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
} 
