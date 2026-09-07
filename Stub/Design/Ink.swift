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

/// Spring constants, tuned by feel. One family, three feelings. Nothing here loops.
enum Motion {
    /// Touch-down and release. Under-damped enough to overshoot once (about a fifth of the travel past the
    /// target, the second swing is under a hundredth) and settle: a stamp pressed too hard, bouncing back.
    static let stamp = Animation.spring(response: 0.34, dampingFraction: 0.55)
    /// The print lifting and settling, the stub sitting up straight, the plate sliding into register.
    static let settle = Animation.spring(response: 0.55, dampingFraction: 0.8)
    /// Objects placed on the table.
    static let place = Animation.spring(response: 0.6, dampingFraction: 0.72)
    /// One inhale. The blank stub on the empty drawer breathes once when it appears, then holds still.
    static let breath = Animation.spring(response: 0.9, dampingFraction: 0.7)
    /// Reduce Motion: critically damped, no overshoot. Callers also drop the rotation.
    static let plain = Animation.spring(response: 0.26, dampingFraction: 1)

    /// The press spring for this user: the stamp, or the plain settle when Reduce Motion is on.
    static func press(reduceMotion: Bool) -> Animation { reduceMotion ? plain : stamp }
}
