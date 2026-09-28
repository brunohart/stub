import SwiftUI

extension Parts {
    /// Riso's parts. No frame: the screen, the disc and the register are three passes through the machine, each
    /// with its own die. The register is how far the ghost of the title sits out of register, so the house
    /// misregistration is chosen by take, never by drag. The title itself is set on the perforation.
    enum Riso {
        static let screen = Part.piece("riso/screen", "the screen")
        static let disc = Part.piece("riso/disc", "the disc")
        static let register = Part.piece("riso/register", "the register")
        static let title = Part.set("riso/title", "the title", note: "The title is the key plate. Turn the register.")
        static let all = [screen, disc, register, title]
    }
}

extension Composer {
    /// Risograph. A dot screen of the first plate swelling toward one point, a disc of the second overprinted,
    /// and the title with a ghost of itself a few points out of register: the house misregistration
    /// (`DisplayTitle`), in two inks instead of one. Overprints multiply on light paper and lighten on dark.
    ///
    /// Parts: the screen, the disc, the register (the ghost title), the title (set).
    func riso() -> [Mark] {
        typealias P = Parts.Riso
        var m = Sheet()
        let light = inks.groundIsLight
        let overprint: Mark.Blend = light ? .multiply : .screen

        m.part = P.screen
        var screen = dice(P.screen)
        let focusX = screen.span(60, w - 60), focusY = screen.span(60, 200), reach = screen.span(170, 230)
        m.append(Mark(.halftone(Card.posterRect, step: 6.5, focus: CGPoint(focusX, focusY), reach: reach, dot: 3.4),
                      .primary, .first, blend: overprint))

        m.part = P.disc
        var disc = dice(P.disc)
        let discX = disc.span(70, w - 70), discY = disc.span(110, 230), discR = disc.span(80, 120)
        m.append(Mark(.circle(CGPoint(discX, discY), radius: discR), .secondary, .second, opacity: 0.9, foil: true, blend: overprint))

        let title = Setting.fit(copy.title, width: w - 2 * pad, height: 170, maxSize: 72, face: .groteskBold, lead: 0.92, maxLines: 4)

        m.part = P.register
        var register = dice(P.register)
        let off = CGSize(width: register.span(2.5, 4), height: register.span(1.5, 3))
        m += title.marks(x: pad - 1 + off.width, y: ph - 28 + off.height, face: .groteskBold, role: light ? .secondary : .primary,
                         lead: 0.92, tracking: -0.04, plate: .second, opacity: light ? 1 : 0.85, maxWidth: w - 2 * pad,
                         blend: light ? .multiply : .normal)

        m.part = P.title
        m += title.marks(x: pad - 1, y: ph - 28, face: .groteskBold, lead: 0.92, tracking: -0.04, maxWidth: w - 2 * pad,
                         blend: light ? .multiply : .normal)
        return m.marks
    }
}
