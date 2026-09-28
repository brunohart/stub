import SwiftUI
import Synchronization

/// Where the light is. The card's tilt, from the phone's attitude or a finger: (0, 0) is the card held square,
/// ±1 as far as it turns. The light comes from the upper left at rest, the way the house's offset shadows fall.
struct Light: Equatable, Sendable {
    var tilt: CGPoint = .zero

    /// The light's direction across the card for the shaders, x right and y down, z taken as 1.
    var vector: CGPoint { CGPoint(x: -0.45 + tilt.x * 0.9, y: -0.6 + tilt.y * 0.9) }

    static let rest = Light()
}

extension Stock {
    /// How the stock shows through: grain on all of them, a long fibre in cotton, a satin gloss on coated card.
    var grain: Double { self == .cotton ? 0.05 : 0.025 }
    var fibre: Double { self == .cotton ? 0.045 : 0 }
    var gloss: Double {
        switch self {
        case .cotton: 0.02
        case .coated: 0.10
        case .foil: 0.08
        case .holographic: 0.10
        }
    }
    /// How hard the plates were pressed into it, and how wide the walls of the impression are, in points.
    var depth: Double { self == .cotton ? 2.2 : 1.0 }
    var reach: Double { self == .cotton ? 1.2 : 0.8 }
}

/// An edition, printed. The stock, the inks pressed into it, the foil stamped on it, all lit from one light.
/// Drawn at `Card.size`; whoever shows it scales it. `printed` counts the passes: 0 is bare stock, 1 to 3 the
/// plates, 4 the foil. The print run counts up, and each pass fades in with its own impression; everywhere else
/// the card is whole.
struct EditionFace: View {
    let composition: Composition
    var light: Light = .rest
    var printed: Int = Plate.foil
    /// The part the press is holding: every other mark is knocked back to a ghost (ADR-016).
    var focus: Part.ID? = nil

    var body: some View {
        let c = composition
        let stock = c.edition.stock
        // Letterpress is pressed hardest: it is the movement that is only type and stock.
        let depth = stock.depth * (c.edition.movement == .letterpress ? 1.6 : 1)
        ZStack(alignment: .topLeading) {
            Canvas { context, _ in
                context.fill(Path(Card.posterRect), with: .color(c.inks.color(c.posterField)))
                context.fill(Path(Card.stripRect), with: .color(c.inks.color(c.stripField)))
            }
            .modifier(StockEffect(light: light, stock: stock, seed: Double(c.edition.seed % 997)))

            // One canvas a plate, so each has its own impression and the print run can lay each down on its own.
            plate(.first, depth: depth)
            plate(.second, depth: depth)

            if c.isMetallic {
                PlateArt(composition: c, plate: nil, focus: focus).equatable()
                .modifier(FoilEffect(light: light, metal: c.inks.foilBase, holographic: stock == .holographic,
                                     lightGround: c.inks.groundIsLight))
                .opacity(printed >= Plate.foil ? 1 : 0)
                // The foil lands: a breath larger, then pressed flat.
                .scaleEffect(printed >= Plate.foil ? 1 : 1.04)
            }

            // The type lies over the foil, never under it: stamped last in time, but a title the foil covered would
            // be a title nobody could read.
            plate(.type, depth: depth)
        }
        .frame(width: Card.width, height: Card.height)
        .clipShape(TicketShape())
    }
}

extension EditionFace {
    fileprivate func plate(_ plate: Plate, depth: Double) -> some View {
        PlateArt(composition: composition, plate: plate, focus: focus).equatable()
            .modifier(ReliefEffect(light: light, depth: depth, reach: composition.edition.stock.reach))
            .opacity(printed >= plate.rawValue ? 1 : 0)
    }
}

/// One plate's marks, or the foil's (`plate` nil). Equatable on the composition, so a card that tilts sixty
/// times a second redraws its light, not its artwork: the shaders take the new light, the canvas is left alone.
private struct PlateArt: View, Equatable {
    let composition: Composition
    let plate: Plate?
    let focus: Part.ID?

    var body: some View {
        let printer = Printer(composition: composition, focus: focus)
        let plate = plate
        Canvas { context, _ in
            if let plate {
                printer.inks(into: context, plates: plate ... plate)
            } else {
                printer.foil(into: context)
            }
        }
    }
}

/// The ticket's outline: rounded corners, a half-moon notch at each end of the perforation, and the
/// perforation itself punched through, so whatever is under the card shows through the holes.
struct TicketShape: Shape {
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
        return card.subtracting(cuts)
    }
}

/// Lays the marks onto a canvas. Plates, foil and type are separate canvases so each gets its own surface and
/// the type lies on top; a foil mark on a stock that has no foil is printed in its ink with the rest.
struct Printer {
    let composition: Composition
    /// The part the press is holding. Every mark outside it, the strip's included, is printed as a ghost.
    var focus: Part.ID? = nil

    /// How much of its ink a knocked-back mark keeps.
    static let ghost = 0.18

    /// The marks on `plates`, less any the foil takes.
    func inks(into context: GraphicsContext, plates: ClosedRange<Plate>) {
        let c = composition
        var poster = context
        poster.clip(to: Path(Card.posterRect))
        for mark in c.poster where plates.contains(mark.plate) && !(mark.foil && c.isMetallic) {
            lay(mark, on: c.posterField, into: poster)
        }
        for mark in c.strip where plates.contains(mark.plate) {
            lay(mark, on: c.stripField, into: context)
        }
    }

    /// The foil's shape, in white: the shader decides what metal it is.
    func foil(into context: GraphicsContext) {
        var poster = context
        poster.clip(to: Path(Card.posterRect))
        for mark in composition.poster where mark.foil {
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

// The three surfaces as modifiers, so the look stays specified at the modifier boundary (ADR-002): Metal draws
// them by default, and `-look swiftui` prints the edition flat, in its inks, with the foil in its metal.

struct StockEffect: ViewModifier {
    var light: Light
    var stock: Stock
    var seed: Double

    func body(content: Content) -> some View {
        if LookEngine.current.isMetal {
            content.colorEffect(ShaderLibrary.stock(
                .boundingRect, .float2(light.vector), .float(stock.grain), .float(stock.fibre), .float(stock.gloss), .float(seed)
            ))
        } else {
            content.overlay { Grain(opacity: stock.grain * 2) }
        }
    }
}

struct ReliefEffect: ViewModifier {
    var light: Light
    var depth: Double
    var reach: Double

    func body(content: Content) -> some View {
        if LookEngine.current.isMetal {
            content.layerEffect(
                ShaderLibrary.relief(.float2(light.vector), .float(depth), .float(reach)),
                maxSampleOffset: CGSize(width: 2, height: 2)
            )
        } else {
            content
        }
    }
}

struct FoilEffect: ViewModifier {
    var light: Light
    var metal: UInt32
    var holographic: Bool
    var lightGround: Bool

    func body(content: Content) -> some View {
        if LookEngine.current.isMetal {
            content.layerEffect(
                ShaderLibrary.foil(.boundingRect, .float2(light.vector), .color(Color(hex: metal)),
                                   .float(holographic ? 1 : 0), .float(lightGround ? 1 : 0)),
                maxSampleOffset: CGSize(width: 1, height: 1)
            )
        } else {
            content.colorMultiply(Color(hex: metal))
        }
    }
}
