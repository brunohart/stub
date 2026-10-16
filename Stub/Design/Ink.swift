import SwiftUI
import UIKit

/// The inks. Three transparent colours over parchment, and the paper itself.
/// Source of truth: designedbybruno/digital-design-taste.md, with one change for words (docs/decisions/005-accessibility.md).
enum Ink {
    static let paper = Color(hex: 0xF0EDE6)
    static let cream = Color(hex: 0xF5F0E1)
    static let ink = Color(hex: 0x1A1A1A)
    static let orange = Color(hex: 0xD4622B)
    static let navy = Color(hex: 0x1B2D4F)
    static let rust = Color(hex: 0xC4391D)
    /// Secondary words. The taste doc's warm grey, #8A8578, is 3.2:1 on parchment, under the 4.5:1 Apple asks of small
    /// text. The same hue at #5A574E is 6.2:1, enough that thin type at 11 and 13 points still measures above 4.5:1 once its
    /// edges are smoothed; under Increase Contrast #48463F is 8.5:1 (decision 005).
    static let grey = Color(uiColor: UIColor { traits in
        traits.accessibilityContrast == .high ? UIColor(hex: 0x48463F) : UIColor(hex: 0x5A574E)
    })
    /// The taste doc's warm grey, for marks that are not words: dots, hairlines, the drawn.
    static let greyMark = Color(hex: 0x8A8578)

    /// Ink a step back, for words that should not shout: `strength` of full ink, and full ink under Increase Contrast.
    static func soft(_ strength: Double) -> Color {
        Color(uiColor: UIColor { traits in
            traits.accessibilityContrast == .high ? UIColor(hex: 0x1A1A1A) : UIColor(hex: 0x1A1A1A).withAlphaComponent(strength)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
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
    /// A finger landing on a stamp: down onto the plate inside two frames, no bounce. The bounce is the release's.
    static let touchDown = Animation.spring(response: 0.1, dampingFraction: 1)
    /// A card dropped onto the table: it falls a little turned, lands, skids a degree past its tilt and settles (ADR-022).
    static let drop = Animation.spring(response: 0.5, dampingFraction: 0.62)
    /// A folder closing on its stubs, or opening: heavier than a card, one small bounce as the front meets the back (ADR-026).
    static let file = Animation.spring(response: 0.46, dampingFraction: 0.78)

    /// The press spring for this user: the stamp, or the plain settle when Reduce Motion is on.
    static func press(reduceMotion: Bool) -> Animation { reduceMotion ? plain : stamp }
}
