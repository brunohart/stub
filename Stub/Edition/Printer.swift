import SwiftUI
import Synchronization

// The card's outline and its marks laid onto a canvas: everything an edition needs to be drawn, and nothing that needs
// Metal, so the widget draws the same card the app does (ADR-027). The light, the stock and the foil are the app's
// (`EditionFace`).

/// The ticket's outline: rounded corners, a half-moon notch at each end of the perforation, the perforation itself
/// punched through, and the conductor's punches (the remarques), so whatever is under the card shows through the holes.
struct TicketShape: Shape {
    /// The remarques, in the front's card points (brief §6.1).
    var punches: [Punch] = []
    /// The card seen from the back: turned over about its long axis, so every punch is mirrored.
    var mirrored = false

    func path(in rect: CGRect) -> Path {
        let s = rect.width / Card.width
        let card = Path(roundedRect: rect, cornerRadius: Card.corner * s)
        let y = rect.minY + Card.poster * rect.height / Card.height
        var cuts = Path()
        let notch: CGFloat = 8 * s
        cuts.addEllipse(in: CGRect(x: rect.minX - notch, y: y - notch, width: notch * 2, height: notch * 2))
        cuts.addEllipse(in: CGRect(x: rect.maxX - notch, y: y - notch, width: notch * 2, height: notch * 2))
        let hole: CGFloat = 1.7 * s
        var x: CGFloat = 16
        while x < Card.width - 14 {
            cuts.addEllipse(in: CGRect(x: rect.minX + x * s - hole, y: y - hole, width: hole * 2, height: hole * 2))
            x += 7.5
        }
        for punch in punches {
            cuts.addPath(punch.path(scale: s, origin: rect.origin, mirrored: mirrored))
        }
        return card.subtracting(cuts)
    }
}

/// Lays the marks onto a canvas. Plates, foil and type are separate canvases so each gets its own surface and
/// the type lies on top; a foil mark on a stock that has no foil is printed in its ink with the rest.
struct Printer {
    let composition: Composition
    /// The part the press is holding. Every mark outside it, the strip's included, is printed as a ghost.
    var focus: Part.ID? = nil

    /// Whether lines of type are set on the canvas. The widget sets them as text instead: a widget's canvas is handed to
    /// the system to draw, and the system cannot draw the app's variable faces from one (ADR-027).
    var setsWords = true

    /// How much of its ink a knocked-back mark keeps.
    static let ghost = 0.18

    private func sets(_ mark: Mark) -> Bool {
        if setsWords { return true }
        if case .words = mark.shape { return false }
        return true
    }

    /// The marks on `plates`, less any the foil takes.
    func inks(into context: GraphicsContext, plates: ClosedRange<Plate>) {
        let c = composition
        var poster = context
        poster.clip(to: Path(Card.posterRect))
        for mark in c.poster where plates.contains(mark.plate) && !(mark.foil && c.isMetallic) && sets(mark) {
            lay(mark, on: c.posterField, into: poster)
        }
        for mark in c.strip where plates.contains(mark.plate) && sets(mark) {
            lay(mark, on: c.stripField, into: context)
        }
    }

    /// The foil's shape, in white: the shader decides what metal it is.
    func foil(into context: GraphicsContext) {
        var poster = context
        poster.clip(to: Path(Card.posterRect))
        for mark in composition.poster where mark.foil && sets(mark) {
            let opacity = isGhost(mark) ? mark.opacity * Self.ghost : mark.opacity
            draw(Mark(mark.shape, mark.role, mark.plate, opacity: opacity, turn: mark.turn), into: poster, colour: .white)
        }
    }

    private func isGhost(_ mark: Mark) -> Bool { focus != nil && mark.part != focus }

    /// A mark in its ink, or, when the press is holding another part, knocked back: a fifth of its ink, its colour
    /// drained to a grey and drawn toward the stock it lies on. No shader: the same canvas, a paler pass.
    private func lay(_ mark: Mark, on field: Role, into context: GraphicsContext) {
        let inks = composition.inks
        guard isGhost(mark) else {
            draw(mark, into: context, colour: inks.color(mark.role))
            return
        }
        let grey = EditionInks.grey(inks.hex(mark.role))
        draw(mark.faded(Self.ghost), into: context, colour: Color(hex: EditionInks.mix(grey, inks.hex(field), 0.3)))
    }

    func draw(_ mark: Mark, into context: GraphicsContext, colour: Color) {
        var g = context
        g.opacity = mark.opacity
        g.blendMode = switch mark.blend {
        case .normal: .normal
        case .multiply: .multiply
        case .screen: .screen
        }
        if let turn = mark.turn {
            g.translateBy(x: turn.around.x, y: turn.around.y)
            g.rotate(by: .degrees(turn.degrees))
            g.translateBy(x: -turn.around.x, y: -turn.around.y)
        }
        let shading = GraphicsContext.Shading.color(colour)
        switch mark.shape {
        case .rect(let rect):
            g.fill(Path(rect), with: shading)
        case .frame(let rect, let width):
            g.stroke(Path(rect), with: shading, lineWidth: width)
        case .circle(let centre, let radius):
            g.fill(Path(ellipseIn: CGRect(x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2)), with: shading)
        case .ring(let centre, let radius, let width, let dash):
            g.stroke(Path(ellipseIn: CGRect(x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2)),
                     with: shading, style: StrokeStyle(lineWidth: width, dash: dash))
        case .polygon(let points):
            g.fill(Self.closed(points), with: shading)
        case .outline(let points, let width):
            g.stroke(Self.closed(points), with: shading, style: StrokeStyle(lineWidth: width, lineJoin: .miter))
        case .line(let a, let b, let width, let dash):
            var path = Path()
            path.move(to: a)
            path.addLine(to: b)
            g.stroke(path, with: shading, style: StrokeStyle(lineWidth: width, dash: dash))
        case .words(let words):
            Self.set(words, colour: colour, into: g)
        case .halftone(let rect, let step, let focus, let reach, let dot):
            g.fill(Self.screen(in: rect, step: step, focus: focus, reach: reach, dot: dot), with: shading)
        }
    }

    static func closed(_ points: [CGPoint]) -> Path {
        var path = Path()
        path.addLines(points)
        path.closeSubpath()
        return path
    }

    /// A line of type on its baseline, shrunk (never wrapped) to its `maxWidth`.
    static func set(_ words: Mark.Words, colour: Color, into g: GraphicsContext) {
        func resolve(_ size: CGFloat) -> GraphicsContext.ResolvedText {
            g.resolve(Text(words.text).font(words.face.font(size)).tracking(words.tracking * size).foregroundStyle(colour))
        }
        let unbounded = CGSize(width: CGFloat.infinity, height: .infinity)
        var text = resolve(words.size)
        var size = text.measure(in: unbounded)
        if let maxWidth = words.maxWidth, size.width > maxWidth, size.width > 0 {
            text = resolve(words.size * maxWidth / size.width)
            size = text.measure(in: unbounded)
        }
        let baseline = text.firstBaseline(in: size)
        let x: CGFloat = switch words.anchor {
        case .leading: words.at.x
        case .center: words.at.x - size.width / 2
        case .trailing: words.at.x - size.width
        }
        g.draw(text, in: CGRect(x: x, y: words.at.y - baseline, width: size.width, height: size.height))
    }

    /// The dot screen, from the cache when it was drawn lately. A card tilting in the light redraws its canvases and
    /// the wheel cross-fades between two screens; neither should rebuild a few thousand dots every frame.
    static func screen(in rect: CGRect, step: CGFloat, focus: CGPoint, reach: CGFloat, dot: CGFloat) -> Path {
        let key = [rect.minX, rect.minY, rect.width, rect.height, step, focus.x, focus.y, reach, dot]
        if let path = screens.withLock({ $0.first { $0.key == key }?.path }) { return path }
        let path = dots(in: rect, step: step, focus: focus, reach: reach, dot: dot)
        screens.withLock { cache in
            cache.insert((key, path), at: 0)
            if cache.count > 6 { cache.removeLast() }
        }
        return path
    }

    /// The last few screens drawn. Canvases draw off the main actor's books, so the cache keeps its own lock.
    private static let screens = Mutex<[(key: [CGFloat], path: Path)]>([])

    /// The dot screen as one path: rows offset by half a step, each dot's area falling off with distance from
    /// `focus` and gone before `reach`. Mirrors the specimen's loop dot for dot.
    static func dots(in rect: CGRect, step: CGFloat, focus: CGPoint, reach: CGFloat, dot: CGFloat) -> Path {
        var path = Path()
        var y = rect.minY + step / 2
        while y < rect.maxY {
            let row = Int((y / step).rounded())
            var x = rect.minX + step / 2 + (row % 2 == 0 ? 0 : step / 2)
            while x < rect.maxX {
                let dx = x - focus.x, dy = y - focus.y
                let t = 1 - (dx * dx + dy * dy).squareRoot() / reach
                if t > 0.04 {
                    let r = dot * t.squareRoot()
                    path.addEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
                }
                x += step
            }
            y += step
        }
        return path
    }
}
