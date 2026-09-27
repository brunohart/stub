import SwiftUI

/// An edition, composed for one copy: the poster's marks and the strip's. A pure function of the edition and
/// the copy, so the same film and the same seat draw the same card in the detail, in the print run and in a
/// share. `docs/editions/edition.js` rolls the same dice in the same order; the movements were designed there.
struct Composition: Sendable {
    let edition: Edition
    let inks: EditionInks
    let copy: Copy
    let poster: [Mark]
    let strip: [Mark]
    /// What shows between the marks: the stock under the poster, and under the strip.
    let posterField: Role
    let stripField: Role

    init(edition: Edition, copy: Copy) {
        self.edition = edition
        self.inks = edition.palette.inks
        self.copy = copy
        let composer = Composer(edition: edition, inks: inks, copy: copy)
        poster = composer.poster()
        posterField = edition.movement == .noir ? .dark : .ground
        stripField = edition.movement == .noir ? .dark : .ground
        strip = composer.strip(on: stripField)
    }

    var isMetallic: Bool { edition.stock == .foil || edition.stock == .holographic }
}

/// Draws the marks. One method per movement, in `Movements/`.
struct Composer {
    let edition: Edition
    let inks: EditionInks
    let copy: Copy

    var w: CGFloat { Card.width }
    var ph: CGFloat { Card.poster }
    var pad: CGFloat { Card.pad }

    /// A die for one movement's drawing. See `Dice.fork`.
    func dice(_ part: String) -> Dice { edition.dice(part) }

    func poster() -> [Mark] {
        switch edition.movement {
        case .swiss: swiss()
        case .constructivist: constructivist()
        case .deco: deco()
        default: swiss()
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
