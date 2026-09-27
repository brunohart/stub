import SwiftUI

extension Parts {
    /// Constructivist's parts. `diagonal` is the frame: the band's sign, angle, width and centre. The disc takes its
    /// side from the diagonal's sign and the bars are turned with it; the title is set in the band and the year sits
    /// in the corner the diagonal leaves open, so both roll nothing.
    enum Constructivist {
        static let diagonal = Part.frame("constructivist/diagonal", "the diagonal")
        static let disc = Part.piece("constructivist/disc", "the disc", hangs: true)
        static let bars = Part.piece("constructivist/bars", "the bars", hangs: true)
        static let title = Part.set("constructivist/title", "the title", hangs: true)
        static let year = Part.set("constructivist/year", "the year", hangs: true)
        static let all = [diagonal, disc, bars, title, year]
    }
}

extension Composer {
    /// After Rodchenko and Lissitzky. A band of the first plate across the poster on a diagonal, a circle in
    /// the second, three bars of black, and the title run up the band in capitals, knocked out of it.
    ///
    /// Parts: the diagonal (frame), the disc, the bars, the title (set), the year (set).
    func constructivist() -> [Mark] {
        typealias P = Parts.Constructivist
        var m = Sheet()

        m.part = P.diagonal
        var d = dice(P.diagonal)
        let s = d.sign()
        let angle = -s * d.between(20, 30)
        let band = d.span(80, 104)
        let cx = w / 2
        let cy = ph * 0.5 + d.span(-24, 24)
        let turn = Mark.Turn(degrees: angle, around: CGPoint(cx, cy))
        m.append(Mark(.rect(CGRect(x: cx - 420, y: cy - band / 2, width: 840, height: band)), .primary, .first, turn: turn))

        m.part = P.disc
        var disc = dice(P.disc)
        let r = disc.span(56, 84)
        let circleY = ph * 0.2 + disc.span(-10, 20)
        m.append(Mark(.circle(CGPoint(s > 0 ? w * 0.3 : w * 0.7, circleY), radius: r), .secondary, .second, foil: true))

        m.part = P.bars
        var bars = dice(P.bars)
        let x1 = cx - 150 + bars.span(-40, 40)
        let w1 = bars.span(200, 280)
        m.append(Mark(.rect(CGRect(x: x1, y: cy + band / 2 + 16, width: w1, height: 7)), .ink, .second, turn: turn))
        let x2 = cx - 120 + bars.span(-40, 40)
        let w2 = bars.span(90, 150)
        m.append(Mark(.rect(CGRect(x: x2, y: cy + band / 2 + 30, width: w2, height: 3)), .ink, .second, turn: turn))
        // The short bar sits on the far side of the band from the circle.
        let x3 = s > 0 ? cx + bars.span(10, 60) : cx - bars.span(110, 170)
        let w3 = bars.span(60, 100)
        m.append(Mark(.rect(CGRect(x: x3, y: cy - band / 2 - 22, width: w3, height: 12)), .ink, .second, turn: turn))

        m.part = P.title
        let title = Setting.fit(copy.title, width: 300, height: band * 0.82, maxSize: band * 0.66, face: .groteskExtraBold,
                                lead: 0.88, maxLines: 2, casing: .upper)
        let block = title.size * 0.88 * CGFloat(title.lines.count - 1)
        m += title.marks(x: cx, y: cy + title.size * 0.35 - block / 2, face: .groteskExtraBold, role: inks.on(.primary),
                         anchor: .center, lead: 0.88, tracking: -0.02, turn: turn, maxWidth: 300, from: .first)

        m.part = P.year
        if let year = copy.year {
            m.append(.words(String(year), .mono, 34, at: CGPoint(s > 0 ? w - pad : pad, ph - 24), .ink, anchor: s > 0 ? .trailing : .leading))
        }
        return m.marks
    }
}
