import SwiftUI

extension Composer {
    /// Letterpress on cotton. A double rule round the poster, a small ornament, the title in the serif centred and
    /// set generously, the cinema in italic under it, a short rule, the year. One ink; the stock does the rest,
    /// because the relief is deepest here.
    func letterpress() -> [Mark] {
        var d = dice("letterpress")
        var m: [Mark] = []
        let cx = w / 2
        m.append(Mark(.frame(CGRect(x: 16, y: 16, width: w - 32, height: ph - 16), width: 2), .ink, .first, foil: true))
        m.append(Mark(.frame(CGRect(x: 21, y: 21, width: w - 42, height: ph - 26), width: 0.75), .ink, .first))

        let oy = d.span(64, 80)
        m.append(Mark(.line(CGPoint(cx - 44, oy), CGPoint(cx - 10, oy), width: 0.75), .ink, .first))
        m.append(Mark(.line(CGPoint(cx + 10, oy), CGPoint(cx + 44, oy), width: 0.75), .ink, .first))
        m.append(Mark(.rect(CGRect(x: cx - 3.5, y: oy - 3.5, width: 7, height: 7)), inks.strong(.primary), .second, foil: true,
                      turn: Mark.Turn(degrees: 45, around: CGPoint(cx, oy))))

        let title = Setting.fit(copy.title, width: w - 80, height: 170, maxSize: 48, face: .serif, lead: 1.08, maxLines: 4)
        let block = title.size * 1.08 * CGFloat(title.lines.count)
        let top = ph * 0.46 - block / 2
        m += title.marks(x: cx, y: top + title.size * 0.82, face: .serif, anchor: .center, lead: 1.08, maxWidth: w - 80, from: .first)
        if let cinema = copy.cinema {
            m.append(.words(cinema, .serifItalic, 15, at: CGPoint(cx, top + block + 24), .ink, anchor: .center, maxWidth: w - 90))
        }
        m.append(Mark(.line(CGPoint(cx - 16, top + block + 44), CGPoint(cx + 16, top + block + 44), width: 0.75), .ink, .first))
        if let year = copy.year {
            m.append(.words(String(year), .mono, 11, at: CGPoint(cx, ph - 40), .ink, anchor: .center))
        }
        return m
    }
}
