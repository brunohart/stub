import SwiftUI

extension Parts {
    /// Cutout's parts. No frame: every scrap of paper is cut on its own and laid on the field wherever it fell. The
    /// field is the whole poster and rolls nothing; the title is set on the label and turns with it.
    enum Cutout {
        static let field = Part.set("cutout/field", "the field", note: "The field is the whole poster. Turn a scrap of paper on it.")
        static let strip = Part.piece("cutout/strip", "the torn strip")
        static let block = Part.piece("cutout/block", "the block")
        static let scrap = Part.piece("cutout/scrap", "the scrap")
        static let label = Part.piece("cutout/label", "the label")
        static let all = [field, strip, block, scrap, label]
    }
}

extension Composer {
    /// Cut paper, after Saul Bass. The whole poster one bold field of the first plate; a strip torn down it, a
    /// hand-cut block and a scrap of the second plate; the title in lower case on a paper label stuck on a little
    /// crooked.
    ///
    /// Parts: the field (set), the torn strip, the block, the scrap, the label (the title rides on it).
    func cutout() -> [Mark] {
        typealias P = Parts.Cutout
        var m = Sheet()

        m.part = P.field
        m.append(Mark(.rect(Card.posterRect), .primary, .first))

        m.part = P.strip
        var strip = dice(P.strip)
        let x0 = strip.span(40, w - 60)
        let x1 = x0 + strip.span(-70, 70)
        let width = strip.span(34, 58)
        m.append(Mark(.polygon(torn(&strip, from: CGPoint(x0, -20), to: CGPoint(x1, ph + 20), width: width, jag: 4)), .ink, .second))

        m.part = P.block
        var d = dice(P.block)
        let bx = d.span(30, 140), by = d.span(40, 140)
        let corners = [
            CGPoint(bx, by),
            CGPoint(bx + d.span(120, 190), by + d.span(-20, 30)),
            CGPoint(bx + d.span(90, 170), by + d.span(70, 120)),
            CGPoint(bx + d.span(-10, 30), by + d.span(60, 110)),
        ]
        // Cut by hand: every corner a few points off where the ruler would have put it.
        let cut = corners.map { p in
            let dx = d.span(-3, 3)
            let dy = d.span(-3, 3)
            return CGPoint(p.x + dx, p.y + dy)
        }
        m.append(Mark(.polygon(cut), .ink, .second, foil: true))

        m.part = P.scrap
        var s = dice(P.scrap)
        let scrapX = s.span(60, w - 60), scrapY = s.span(180, 250), scrapR = s.span(24, 40)
        m.append(Mark(.polygon(scrap(&s, center: CGPoint(scrapX, scrapY), radius: scrapR, corners: 9, jag: 0.18)), .secondary, .second))

        m.part = P.label
        var label = dice(P.label)
        let title = Setting.fit(copy.title, width: w - 2 * pad - 28, height: 120, maxSize: 44, face: .groteskBold, lead: 0.95,
                                maxLines: 3, casing: .lower)
        let block = title.size * 0.95 * CGFloat(title.lines.count)
        let labelY = ph - 34 - block
        let turn = Mark.Turn(degrees: label.between(-3, 3), around: CGPoint(w / 2, labelY + block / 2))
        m.append(Mark(.rect(CGRect(x: pad, y: labelY - 12, width: w - 2 * pad, height: block + 24)), .ground, .second, turn: turn))
        m += title.marks(x: pad + 14, y: labelY + title.size * 0.8, face: .groteskBold, lead: 0.95, tracking: -0.03,
                         turn: turn, maxWidth: w - 2 * pad - 28, from: .first)
        return m.marks
    }

    /// A strip torn along both long edges, from `a` to `b`. Each edge point is jittered in x and then in y,
    /// the near edge before the far one, twelve steps down.
    private func torn(_ d: inout Dice, from a: CGPoint, to b: CGPoint, width: CGFloat, jag: CGFloat) -> [CGPoint] {
        let steps = 12
        let dx = b.x - a.x, dy = b.y - a.y
        let length = max((dx * dx + dy * dy).squareRoot(), 0.001)
        let nx = -dy / length, ny = dx / length
        var near: [CGPoint] = [], far: [CGPoint] = []
        for i in 0...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let px = a.x + dx * t, py = a.y + dy * t
            let j1 = d.span(-jag, jag), j2 = d.span(-jag, jag)
            near.append(CGPoint(px + nx * (width / 2 + j1), py + ny * (width / 2 + j2)))
            let j3 = d.span(-jag, jag), j4 = d.span(-jag, jag)
            far.append(CGPoint(px - nx * (width / 2 + j3), py - ny * (width / 2 + j4)))
        }
        return near + far.reversed()
    }

    /// A scrap cut with scissors: `corners` points round a circle, each at a slightly different reach.
    private func scrap(_ d: inout Dice, center: CGPoint, radius: CGFloat, corners: Int, jag: Double) -> [CGPoint] {
        let start = d.between(0, 2 * .pi)
        return (0..<corners).map { i in
            let a = start + Double(i) / Double(corners) * 2 * .pi
            let reach = radius * CGFloat(d.between(1 - jag, 1 + jag))
            return CGPoint(center.x + CGFloat(cos(a)) * reach, center.y + CGFloat(sin(a)) * reach)
        }
    }
}
