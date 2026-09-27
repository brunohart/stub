import SwiftUI

extension Composer {
    /// A technical drawing. A fine grid with every fifth line heavier; a circle drawn with its centre lines and
    /// an inner dashed ring; a radius to the seat, labelled with it; a dimension line under the circle, labelled
    /// with the time; and a title block, as on any drawing, that says which viewing of how many and which screen.
    /// Everything in the mono.
    func blueprint() -> [Mark] {
        var d = dice("blueprint")
        var m: [Mark] = []
        let line = inks.strong(.primary)

        var x: CGFloat = 11, i = 1
        while x < w {
            let major = i % 5 == 0
            m.append(Mark(.line(CGPoint(x, 0), CGPoint(x, ph), width: major ? 0.6 : 0.35), line, .first, opacity: major ? 0.3 : 0.14))
            x += 11; i += 1
        }
        var y: CGFloat = 11
        i = 1
        while y < ph {
            let major = i % 5 == 0
            m.append(Mark(.line(CGPoint(0, y), CGPoint(w, y), width: major ? 0.6 : 0.35), line, .first, opacity: major ? 0.3 : 0.14))
            y += 11; i += 1
        }

        let r = d.span(84, 112)
        let cx = w / 2 + d.span(-36, 36)
        let cy = ph * 0.38 + d.span(-20, 16)
        let centre = CGPoint(cx, cy)
        m.append(Mark(.ring(centre, radius: r, width: 1.6), line, .second, foil: true))
        m.append(Mark(.ring(centre, radius: r * 0.62, width: 0.75, dash: [4, 3]), line, .second))
        m.append(Mark(.line(CGPoint(cx - r - 16, cy), CGPoint(cx + r + 16, cy), width: 0.75, dash: [10, 3, 2, 3]), line, .second))
        m.append(Mark(.line(CGPoint(cx, cy - r - 16), CGPoint(cx, cy + r + 16), width: 0.75, dash: [10, 3, 2, 3]), line, .second))

        let a = d.between(-2.4, -0.7)
        let tip = CGPoint(cx + CGFloat(cos(a)) * r, cy + CGFloat(sin(a)) * r)
        m.append(Mark(.line(centre, tip, width: 1), .secondary, .second))
        m.append(Mark(.circle(tip, radius: 3), .secondary, .second, foil: true))
        if let seat = copy.seat {
            let right = cos(a) > 0
            m.append(.words("SEAT \(seat)", .mono, 9.5, at: CGPoint(tip.x + (right ? 8 : -8), tip.y - 6), line,
                            anchor: right ? .leading : .trailing))
        }

        let dy = cy + r + 26
        m.append(Mark(.line(CGPoint(cx - r, dy), CGPoint(cx + r, dy), width: 0.75), line, .second))
        for (end, s) in [(cx - r, CGFloat(1)), (cx + r, CGFloat(-1))] {
            m.append(Mark(.line(CGPoint(end, dy - 8), CGPoint(end, dy + 4), width: 0.75), line, .second))
            m.append(Mark(.line(CGPoint(end, dy), CGPoint(end + 6 * s, dy - 3), width: 0.75), line, .second))
            m.append(Mark(.line(CGPoint(end, dy), CGPoint(end + 6 * s, dy + 3), width: 0.75), line, .second))
        }
        if let label = copy.time ?? copy.year.map({ String($0) }) {
            m.append(Mark(.rect(CGRect(x: cx - 22, y: dy - 7, width: 44, height: 14)), .ground, .second))
            m.append(.words(label, .mono, 9.5, at: CGPoint(cx, dy + 3.5), line, anchor: .center))
        }

        // The title block.
        let block = CGRect(x: pad, y: ph - 92, width: w - 2 * pad, height: 70)
        m.append(Mark(.rect(block), .ground, .second))
        m.append(Mark(.frame(block, width: 1), line, .second))
        m.append(Mark(.line(CGPoint(block.minX, block.maxY - 20), CGPoint(block.maxX, block.maxY - 20), width: 0.75), line, .second))
        m.append(Mark(.line(CGPoint(block.midX, block.maxY - 20), CGPoint(block.midX, block.maxY), width: 0.75), line, .second))
        let title = Setting.fit(copy.title, width: block.width - 20, height: 40, maxSize: 22, face: .mono, lead: 1, maxLines: 2, casing: .upper)
        m += title.marks(x: block.minX + 10, y: block.maxY - 28, face: .mono, lead: 1, maxWidth: block.width - 20)
        m.append(.words("VIEWING \(copy.viewing) OF \(copy.viewings)", .mono, 8.5, at: CGPoint(block.minX + 8, block.maxY - 6.5), line))
        if let screen = copy.screen {
            let words = screen.allSatisfy(\.isNumber) ? "SCREEN \(screen)" : screen.uppercased()
            m.append(.words(words, .mono, 8.5, at: CGPoint(block.midX + 8, block.maxY - 6.5), line))
        }
        return m
    }
}
