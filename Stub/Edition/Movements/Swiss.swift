import SwiftUI

extension Composer {
    /// International Typographic Style. One hero shape in the first plate (a bar, a circle off the corner, or a
    /// block across the top), a hairline and three columns of the night, and the title in lower case, huge,
    /// flush left, sitting on the perforation.
    func swiss() -> [Mark] {
        var d = dice("swiss")
        var m: [Mark] = []
        let variant = d.index(3)
        var infoY: CGFloat
        switch variant {
        case 0:
            let h = d.span(176, 230)
            let width = d.span(22, 38)
            m.append(Mark(.rect(CGRect(x: pad, y: 0, width: width, height: h)), .primary, .first, foil: true))
            infoY = h + 26
        case 1:
            let r = d.span(100, 140)
            let cy = d.span(34, 84)
            let cx = w - d.span(24, 70)
            m.append(Mark(.circle(CGPoint(cx, cy), radius: r), .primary, .first, foil: true))
            infoY = cy + r + 26
        default:
            let h = d.span(132, 172)
            m.append(Mark(.rect(CGRect(x: 0, y: 0, width: w, height: h)), .primary, .first, foil: true))
            infoY = h + 26
        }
        infoY = min(infoY, 238)

        // The grid: a hairline, then three columns of what the night was.
        m.append(Mark(.line(CGPoint(pad, infoY - 14), CGPoint(w - pad, infoY - 14), width: 0.75), .ink, .second))
        let columns = [copy.year.map { String($0) }, copy.time, copy.seat].compactMap { $0 }
        for (i, text) in columns.enumerated() {
            m.append(.words(text, .mono, 11, at: CGPoint(pad + CGFloat(i) * ((w - 2 * pad) / 3), infoY), .ink))
        }
        let square: CGFloat = 11
        m.append(Mark(.rect(CGRect(x: w - pad - square, y: infoY - 9, width: square, height: square)), .secondary, .second))

        let title = Setting.fit(copy.title, width: w - 2 * pad, height: ph - infoY - 50, maxSize: 88, face: .groteskBold,
                                lead: 0.9, maxLines: 4, casing: .lower)
        m += title.marks(x: pad - 2, y: ph - 26, face: .groteskBold, lead: 0.9, tracking: -0.045, maxWidth: w - 2 * pad)
        return m
    }
}
