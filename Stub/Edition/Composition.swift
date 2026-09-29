import SwiftUI

/// An edition, composed for one copy: the poster's marks and the strip's. A pure function of the edition (its takes
/// included) and the copy, so the same film and the same seat draw the same card in the detail, in the print run and
/// in a share. Every poster mark carries the part it belongs to (ADR-016). `docs/editions/edition.js` rolls the same
/// dice in the same order; the movements were designed there.
struct Composition: Sendable, Equatable {
    let edition: Edition
    let inks: EditionInks
    let copy: Copy
    let poster: [Mark]
    let strip: [Mark]
    /// What shows between the marks: the stock under the poster, and under the strip.
    let posterField: Role
    let stripField: Role
    /// For a drawing between two takes of one part (the wheel mid-turn), where between them it is; `nil` for a take.
    let inBetween: InBetween?
    /// The remarques: which viewing this copy was, punched through the strip (brief §6.1). None for a first viewing.
    let punches: [Punch]
    /// The surface the card has earned since the night it was seen (brief §6.2).
    let patina: Patina

    struct InBetween: Equatable, Sendable {
        var part: Part.ID
        /// The take, fractional: 13.5 is halfway from take 13 to take 14.
        var position: Double
    }

    init(edition: Edition, copy: Copy) {
        self.edition = edition
        self.inks = edition.palette.inks
        self.copy = copy
        let composer = Composer(edition: edition, inks: inks, copy: copy)
        poster = composer.poster()
        posterField = edition.movement == .noir ? .dark : .ground
        stripField = edition.movement == .noir ? .dark : .ground
        strip = composer.strip(on: stripField)
        inBetween = nil
        punches = Remarque.punches(for: edition, copy: copy, strip: strip)
        patina = Patina(age: copy.age, seed: edition.seed, viewing: copy.viewing)
    }

    /// This composition with another poster: an in-between, drawn by `between`.
    init(_ c: Composition, poster: [Mark], inBetween: InBetween?) {
        edition = c.edition; inks = c.inks; copy = c.copy; strip = c.strip
        posterField = c.posterField; stripField = c.stripField
        punches = c.punches; patina = c.patina
        self.poster = poster
        self.inBetween = inBetween
    }

    var isMetallic: Bool { edition.stock == .foil || edition.stock == .holographic }

    /// The marks are a function of the edition, the copy and, mid-turn, where between two takes the wheel is, so two
    /// compositions of the same are the same.
    static func == (a: Composition, b: Composition) -> Bool {
        a.edition == b.edition && a.copy == b.copy && a.inBetween == b.inBetween
    }
}

/// Draws the marks. One method per movement, in `Movements/`, each a line-for-line port of its function in
/// `docs/editions/edition.js` so the two roll the same dice in the same order.
struct Composer {
    let edition: Edition
    let inks: EditionInks
    let copy: Copy

    var w: CGFloat { Card.width }
    var ph: CGFloat { Card.poster }
    var pad: CGFloat { Card.pad }

    /// The die for one part, at the take the edition asks for (take 0 unless a proof says otherwise). A part that
    /// is `set` rolls nothing and never asks.
    func dice(_ part: Part) -> Dice {
        edition.dice(part.id, take: edition.takes[part.id] ?? 0)
    }

    func poster() -> [Mark] {
        switch edition.movement {
        case .swiss: swiss()
        case .constructivist: constructivist()
        case .deco: deco()
        case .cutout: cutout()
        case .riso: riso()
        case .letterpress: letterpress()
        case .blueprint: blueprint()
        case .noir: noir()
        }
    }

    /// The tear-off strip: the film, the cinema, the night, the seat, the price, which viewing. The same facts on
    /// every movement, set in the movement's own face for the title.
    func strip(on field: Role) -> [Mark] {
        let x: CGFloat = 20
        let y = ph
        let text: Role = field == .dark ? .light : .ink
        let accent: Role = EditionInks.contrast(inks.primary, inks.hex(field)) >= 3 ? .primary
            : EditionInks.contrast(inks.secondary, inks.hex(field)) >= 3 ? .secondary : text
        let (face, size): (Face, CGFloat) = switch edition.movement {
        case .letterpress: (.serif, 16)
        case .noir: (.serifItalic, 16)
        case .blueprint: (.mono, 11.5)
        case .deco: (.groteskLight, 12)
        default: (.groteskMedium, 13.5)
        }
        let shouts = [Movement.blueprint, .deco, .constructivist].contains(edition.movement)
        var marks: [Mark] = [
            .words(shouts ? copy.title.uppercased() : copy.title, face, size, at: CGPoint(x, y + 32), text,
                   tracking: edition.movement == .deco ? 0.12 : 0, maxWidth: copy.price == nil ? 290 : 200),
        ]
        if let price = copy.price {
            marks.append(.words(price, .mono, 11, at: CGPoint(w - x, y + 32), text, anchor: .trailing))
        }
        if let cinema = copy.cinema {
            marks.append(.words(cinema, .groteskMedium, 11.5, at: CGPoint(x, y + 50), text, maxWidth: 290, opacity: 0.62))
        }
        if let when = copy.when {
            marks.append(.words(when, .mono, 11, at: CGPoint(x, y + 82), text))
        }
        if let place = copy.place {
            marks.append(.words(place, .mono, 11, at: CGPoint(x, y + 99), text))
        }
        marks.append(.words(copy.viewingWords, .serifItalic, 13, at: CGPoint(w - x, y + 99), accent, anchor: .trailing))
        return marks
    }
}
