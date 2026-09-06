import SwiftUI

/// The inks. Three transparent colours over parchment, and the paper itself.
/// Source of truth: designedbybruno/digital-design-taste.md.
enum Ink {
    static let paper = Color(hex: 0xF0EDE6)
    static let cream = Color(hex: 0xF5F0E1)
    static let ink = Color(hex: 0x1A1A1A)
    static let orange = Color(hex: 0xD4622B)
    static let navy = Color(hex: 0x1B2D4F)
    static let rust = Color(hex: 0xC4391D)
    static let grey = Color(hex: 0x8A8578)
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

/// Spring constants, tuned by feel. One overshoot, then settle. Like a stamp pressed too hard.
enum Motion {
    static let stamp = Animation.spring(response: 0.42, dampingFraction: 0.62)
    static let settle = Animation.spring(response: 0.55, dampingFraction: 0.8)
    static let place = Animation.spring(response: 0.6, dampingFraction: 0.72)
}
