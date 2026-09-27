import SwiftUI

extension Composer {
    /// Art Deco. A sunburst from low on the poster, alternate wedges in a wash of the first plate and fine rays
    /// between them, a sun ringed twice, a stepped double frame, and the title in light capitals, widely spaced,
    /// on a panel of the ground between two rules. Rays, rings, rules, frame and title are the foil.
    func deco() -> [Mark] {
        var d = dice("deco")
        var m: [Mark] = []
        let cx = w / 2
        let cy = ph * d.pick([0.66, 0.72])
        let n = d.pick([24, 28, 32, 36])
        let reach: CGFloat = 700
        func ray(_ i: Int) -> CGPoint {
            let a = Double(i) / Double(n) * 2 * .pi
            return CGPoint(cx + CGFloat(cos(a)) * reach, cy + CGFloat(sin(a)) * reach)
        }
        for i in stride(from: 0, to: n, by: 2) {
            m.append(Mark(.polygon([CGPoint(cx, cy), ray(i), ray(i + 1)]), .primary, .first, opacity: 0.2))
        }
        for i in stride(from: 1, to: n, by: 2) {
            let a = Double(i) / Double(n) * 2 * .pi
            let inner = CGPoint(cx + CGFloat(cos(a)) * 58, cy + CGFloat(sin(a)) * 58)
            m.append(Mark(.line(inner, ray(i), width: 1), .primary, .first, opacity: 0.55, foil: true))
        }
        let sun = d.span(40, 52)
        m.append(Mark(.circle(CGPoint(cx, cy), radius: sun), .ground, .first))
        m.append(Mark(.ring(CGPoint(cx, cy), radius: sun, width: 2), .primary, .first, foil: true))
        m.append(Mark(.ring(CGPoint(cx, cy), radius: sun - 6, width: 0.75), .primary, .first, foil: true))

        m.append(Mark(.outline(steppedFrame(inset: 12, step: 10), width: 1.5), .primary, .first, foil: true))
        m.append(Mark(.outline(steppedFrame(inset: 18, step: 10), width: 0.75), .primary, .first, foil: true))

        let title = Setting.fit(copy.title, width: w - 90, height: 120, maxSize: 40, face: .groteskLight, lead: 1.08,
                                maxLines: 3, casing: .upper, tracking: 0.16)
        let block = title.size * 1.08 * CGFloat(title.lines.count)
        let top: CGFloat = 60
        // A panel of the ground behind the title, so it reads over the rays.
        m.append(Mark(.rect(CGRect(x: 34, y: top - 16, width: w - 68, height: block + 30)), .ground, .first))
        m.append(Mark(.line(CGPoint(44, top - 8), CGPoint(w - 44, top - 8), width: 0.75), .primary, .first, foil: true))
        m.append(Mark(.line(CGPoint(44, top + block + 6), CGPoint(w - 44, top + block + 6), width: 0.75), .primary, .first, foil: true))
        m += title.marks(x: cx, y: top + title.size * 0.86, face: .groteskLight, anchor: .center, lead: 1.08, tracking: 0.16,
                         foil: true, maxWidth: w - 90, from: .first)
        if let year = copy.year {
            m.append(.words(String(year), .mono, 12, at: CGPoint(cx, cy + 4), .ink, anchor: .center))
        }
        return m
    }

    /// A rectangle `inset` from the poster's edges with each corner stepped in by `step`.
    private func steppedFrame(inset i: CGFloat, step: CGFloat) -> [CGPoint] {
        [CGPoint(i + step, i), CGPoint(w - i - step, i), CGPoint(w - i - step, i + step), CGPoint(w - i, i + step),
         CGPoint(w - i, ph - i - step), CGPoint(w - i - step, ph - i - step), CGPoint(w - i - step, ph - i),
         CGPoint(i + step, ph - i), CGPoint(i + step, ph - i - step), CGPoint(i, ph - i - step), CGPoint(i, i + step),
         CGPoint(i + step, i + step)]
    }
}
