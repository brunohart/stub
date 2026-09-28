import SwiftUI

/// An ink's job on the card. Resolved against the edition's palette only when it is drawn, so a composition
/// is written once and printed in any of the twelve.
enum Role: Sendable {
    case ground, primary, secondary, ink
    /// The lighter and the darker of ground and ink: a noir field is `dark` whichever way round the palette is.
    case light, dark
}

/// The five inks of a palette, as hex so they can be measured. Every palette keeps its words at better than
/// 11:1 on its ground; a test says so (`PaletteTests`).
struct EditionInks: Equatable, Sendable {
    let ground: UInt32
    let primary: UInt32
    let secondary: UInt32
    let ink: UInt32
    /// The foil's colour: gold, silver or copper.
    let metal: UInt32

    var groundIsLight: Bool { Self.luminance(ground) > Self.luminance(ink) }

    func hex(_ role: Role) -> UInt32 {
        switch role {
        case .ground: ground
        case .primary: primary
        case .secondary: secondary
        case .ink: ink
        case .light: groundIsLight ? ground : ink
        case .dark: groundIsLight ? ink : ground
        }
    }

    func color(_ role: Role) -> Color { Color(hex: hex(role)) }

    /// Ground or ink, whichever reads better on `role`: the words on a band of colour.
    func on(_ role: Role) -> Role {
        Self.contrast(hex(role), ground) >= Self.contrast(hex(role), ink) ? .ground : .ink
    }

    /// `role` when it reads on `field` at 3:1 (large marks and fine lines), otherwise the ink.
    func strong(_ role: Role, on field: Role = .ground) -> Role {
        Self.contrast(hex(role), hex(field)) >= 3 ? role : (field == .ground ? .ink : .light)
    }

    /// The foil's colour against this ground. Foil must read as well as ink does: on light card it is pulled a
    /// third of the way toward the ink, on dark card it is left as it is.
    var foilBase: UInt32 { groundIsLight ? Self.mix(metal, ink, 0.38) : metal }

    /// WCAG relative luminance.
    static func luminance(_ hex: UInt32) -> Double {
        func channel(_ shift: UInt32) -> Double {
            let v = Double((hex >> shift) & 0xFF) / 255
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0)
    }

    static func contrast(_ a: UInt32, _ b: UInt32) -> Double {
        let (x, y) = (luminance(a), luminance(b))
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }

    /// The grey with `hex`'s luminance: its colour drained, its weight kept.
    static func grey(_ hex: UInt32) -> UInt32 {
        let l = luminance(hex)
        let v = l <= 0.0031308 ? l * 12.92 : 1.055 * pow(l, 1 / 2.4) - 0.055
        let c = UInt32((min(max(v, 0), 1) * 255).rounded())
        return c << 16 | c << 8 | c
    }

    static func mix(_ a: UInt32, _ b: UInt32, _ t: Double) -> UInt32 {
        func channel(_ shift: UInt32) -> UInt32 {
            let x = Double((a >> shift) & 0xFF), y = Double((b >> shift) & 0xFF)
            return UInt32((x + (y - x) * t).rounded()) << shift
        }
        return channel(16) | channel(8) | channel(0)
    }
}

extension Palette {
    /// Ground, first plate, second plate, words, metal. Print inks, not screen colours: two plates and a black.
    var inks: EditionInks {
        switch self {
        case .sand: EditionInks(ground: 0xEDE0C4, primary: 0xB5451B, secondary: 0xD99A2B, ink: 0x2A1D14, metal: 0xC9A45C)
        case .night: EditionInks(ground: 0x15171D, primary: 0x3C5DA8, secondary: 0xC9B98F, ink: 0xEDE6D6, metal: 0xB9BEC6)
        case .ember: EditionInks(ground: 0x1D1512, primary: 0xC4391D, secondary: 0xE9A23B, ink: 0xF3E7D3, metal: 0xC08457)
        case .tide: EditionInks(ground: 0xE3ECEA, primary: 0x1F5E73, secondary: 0xE07A5F, ink: 0x0F2A33, metal: 0xB9BEC6)
        case .moss: EditionInks(ground: 0xE5E3D1, primary: 0x4F6B3A, secondary: 0xB89B5E, ink: 0x1F2A1A, metal: 0xC9A45C)
        case .chalk: EditionInks(ground: 0xF4F1EA, primary: 0x1A1A1A, secondary: 0xD4622B, ink: 0x1A1A1A, metal: 0xB9BEC6)
        case .bruise: EditionInks(ground: 0xE8E0E9, primary: 0x5B2A6E, secondary: 0xD9577A, ink: 0x24122B, metal: 0xB9BEC6)
        case .oxide: EditionInks(ground: 0xDAD2C2, primary: 0x7A2E1F, secondary: 0x3E4F5C, ink: 0x1E1B18, metal: 0xC08457)
        case .cobalt: EditionInks(ground: 0x0F2B5C, primary: 0xE9EEF5, secondary: 0xF2C14E, ink: 0xF4F1EA, metal: 0xB9BEC6)
        case .citrus: EditionInks(ground: 0xF6EFD9, primary: 0xEFA92F, secondary: 0x2F7F6F, ink: 0x22302B, metal: 0xC9A45C)
        case .blush: EditionInks(ground: 0xF3E3DA, primary: 0xE2725B, secondary: 0x2F3E75, ink: 0x2A1F2E, metal: 0xC9A45C)
        case .smoke: EditionInks(ground: 0xD8D8D3, primary: 0x2B2B2B, secondary: 0x9E1B1B, ink: 0x121212, metal: 0xB9BEC6)
        }
    }
}
