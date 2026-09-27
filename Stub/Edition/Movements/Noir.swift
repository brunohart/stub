import SwiftUI

extension Parts {
    /// Noir's parts. No frame: the night is the whole poster and rolls nothing, the blind rolls its own slats, and the
    /// title and the time are set low on the poster by the title's own size.
    enum Noir {
        static let night = Part.set("noir/night", "the night")
        static let blind = Part.piece("noir/blind", "the blind")
        static let title = Part.set("noir/title", "the title")
        static let time = Part.set("noir/time", "the time")
        static let all = [night, blind, title, time]
    }
}

extension Composer {
    /// Night. The poster the darker of the palette's two, light falling across it through a venetian blind, and
    /// the title low in the serif's italic, in the lighter (silver when the stock is foil). The time above it,
    /// in whichever accent reads on the dark.
    ///
    /// Parts: the night (set), the blind, the title (set), the time (set).
    func noir() -> [Mark] {
        typealias P = Parts.Noir
        var m = Sheet()

        m.part = P.night
        m.append(Mark(.rect(Card.posterRect), .dark, .first))

        m.part = P.blind
        var d = dice(P.blind)
        let slats = 7 + d.index(4)
        let angle = -d.between(18, 30)
        let thick = d.span(12, 16)
        let gap = d.span(9, 13)
        let pivot = CGPoint(w * d.span(0.55, 0.85), -30)
        let turn = Mark.Turn(degrees: angle, around: pivot)
        for i in 0..<slats {
            let fade = 0.16 * (1 - Double(i) / Double(slats) * 0.75)
            m.append(Mark(.rect(CGRect(x: pivot.x - 360, y: pivot.y + 40 + CGFloat(i) * (thick + gap), width: 520, height: thick)),
                          .light, .first, opacity: fade, turn: turn))
        }

        m.part = P.title
        let title = Setting.fit(copy.title, width: w - 2 * pad, height: 150, maxSize: 60, face: .serifItalic, lead: 1, maxLines: 3)
        m += title.marks(x: pad, y: ph - 30, face: .serifItalic, role: .light, lead: 1, foil: true, maxWidth: w - 2 * pad)

        m.part = P.time
        let top = ph - 30 - title.size * CGFloat(title.lines.count - 1) - title.size * 0.9
        let dark = inks.hex(.dark)
        let accent: Role = EditionInks.contrast(inks.secondary, dark) >= 3 ? .secondary
            : EditionInks.contrast(inks.primary, dark) >= 3 ? .primary : .light
        m.append(Mark(.line(CGPoint(pad, top - 14), CGPoint(pad + 28, top - 14), width: 1), accent, .second))
        if let time = copy.time {
            m.append(.words(time, .mono, 11, at: CGPoint(pad + 36, top - 10.5), accent))
        }
        return m.marks
    }
}
