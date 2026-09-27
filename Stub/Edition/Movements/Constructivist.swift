import SwiftUI

extension Composer {
    /// After Rodchenko and Lissitzky. A band of the first plate across the poster on a diagonal, a circle in
    /// the second, three bars of black, and the title run up the band in capitals, knocked out of it.
    func constructivist() -> [Mark] {
        var d = dice("constructivist")
        var m: [Mark] = []
        let s = d.sign()
        let angle = -s * d.between(20, 30)
        let band = d.span(80, 104)
        let cx = w / 2
        let cy = ph * 0.5 + d.span(-24, 24)
        let turn = Mark.Turn(degrees: angle, around: CGPoint(cx, cy))
        m.append(Mark(.rect(CGRect(x: cx - 420, y: cy - band / 2, width: 840, height: band)), .primary, .first, turn: turn))

        let r = d.span(56, 84)
        let circleY = ph * 0.2 + d.span(-10, 20)
        m.append(Mark(.circle(CGPoint(s > 0 ? w * 0.3 : w * 0.7, circleY), radius: r), .secondary, .second, foil: true))

        let x1 = cx - 150 + d.span(-40, 40)
        let w1 = d.span(200, 280)
        m.append(Mark(.rect(CGRect(x: x1, y: cy + band / 2 + 16, width: w1, height: 7)), .ink, .second, turn: turn))
        let x2 = cx - 120 + d.span(-40, 40)
        let w2 = d.span(90, 150)
        m.append(Mark(.rect(CGRect(x: x2, y: cy + band / 2 + 30, width: w2, height: 3)), .ink, .second, turn: turn))
        // The short bar sits on the far side of the band from the circle.
        let x3 = s > 0 ? cx + d.span(10, 60) : cx - d.span(110, 170)
        let w3 = d.span(60, 100)
        m.append(Mark(.rect(CGRect(x: x3, y: cy - band / 2 - 22, width: w3, height: 12)), .ink, .second, turn: turn))

        let title = Setting.fit(copy.title, width: 300, height: band * 0.82, maxSize: band * 0.66, face: .groteskExtraBold,
                                lead: 0.88, maxLines: 2, casing: .upper)
        let block = title.size * 0.88 * CGFloat(title.lines.count - 1)
        m += title.marks(x: cx, y: cy + title.size * 0.35 - block / 2, face: .groteskExtraBold, role: inks.on(.primary),
                         anchor: .center, lead: 0.88, tracking: -0.02, turn: turn, maxWidth: 300, from: .first)
        if let year = copy.year {
            m.append(.words(String(year), .mono, 34, at: CGPoint(s > 0 ? w - pad : pad, ph - 24), .ink, anchor: s > 0 ? .trailing : .leading))
        }
        return m
    }
}
