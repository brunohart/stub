import SwiftUI

extension Composer {
    /// Risograph. A dot screen of the first plate swelling toward one point, a disc of the second overprinted,
    /// and the title with a ghost of itself a few points out of register: the house misregistration
    /// (`DisplayTitle`), in two inks instead of one. Overprints multiply on light paper and lighten on dark.
    func riso() -> [Mark] {
        var d = dice("riso")
        var m: [Mark] = []
        let light = inks.groundIsLight
        let overprint: Mark.Blend = light ? .multiply : .screen

        let focusX = d.span(60, w - 60), focusY = d.span(60, 200), reach = d.span(170, 230)
        m.append(Mark(.halftone(Card.posterRect, step: 6.5, focus: CGPoint(focusX, focusY), reach: reach, dot: 3.4),
                      .primary, .first, blend: overprint))
        let discX = d.span(70, w - 70), discY = d.span(110, 230), discR = d.span(80, 120)
        m.append(Mark(.circle(CGPoint(discX, discY), radius: discR), .secondary, .second, opacity: 0.9, foil: true, blend: overprint))

        let off = CGSize(width: d.span(2.5, 4), height: d.span(1.5, 3))
        let title = Setting.fit(copy.title, width: w - 2 * pad, height: 170, maxSize: 72, face: .groteskBold, lead: 0.92, maxLines: 4)
        m += title.marks(x: pad - 1 + off.width, y: ph - 28 + off.height, face: .groteskBold, role: light ? .secondary : .primary,
                         lead: 0.92, tracking: -0.04, plate: .second, opacity: light ? 1 : 0.85, maxWidth: w - 2 * pad,
                         blend: light ? .multiply : .normal)
        m += title.marks(x: pad - 1, y: ph - 28, face: .groteskBold, lead: 0.92, tracking: -0.04, maxWidth: w - 2 * pad,
                         blend: light ? .multiply : .normal)
        return m
    }
}
