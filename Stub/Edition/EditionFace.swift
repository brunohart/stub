import SwiftUI

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
    var fibre: Double { self == .cotton ? 0.06 : 0 }
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
/// plates, 4 the foil. The print run counts up; everywhere else it is whole.
struct EditionFace: View {
    let composition: Composition
    var light: Light = .rest
    var printed: Int = Plate.foil

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

            Canvas { context, _ in
                Printer(composition: c).inks(into: context, printed: printed)
            }
            .modifier(ReliefEffect(light: light, depth: depth, reach: stock.reach))

            if c.isMetallic, printed >= Plate.foil {
                Canvas { context, _ in
                    Printer(composition: c).foil(into: context)
                }
                .modifier(FoilEffect(light: light, metal: c.inks.foilBase, holographic: stock == .holographic,
                                     lightGround: c.inks.groundIsLight))
                .transition(.opacity)
            }
        }
        .frame(width: Card.width, height: Card.height)
        .clipShape(TicketShape())
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

/// Lays the marks onto a canvas. The inks and the foil are separate canvases so each gets its own surface;
/// a foil mark on a stock that has no foil is printed in its ink with the rest.
struct Printer {
    let composition: Composition

    func inks(into context: GraphicsContext, printed: Int) {
        let c = composition
        var poster = context
        poster.clip(to: Path(Card.posterRect))
        for mark in c.poster where mark.plate.rawValue <= printed && !(mark.foil && c.isMetallic) {
            draw(mark, into: poster, colour: c.inks.color(mark.role))
        }
        for mark in c.strip where mark.plate.rawValue <= printed {
            draw(mark, into: context, colour: c.inks.color(mark.role))
        }
    }

    /// The foil's shape, in white: the shader decides what metal it is.
    func foil(into context: GraphicsContext) {
        var poster = context
        poster.clip(to: Path(Card.posterRect))
        for mark in composition.poster where mark.foil {
            draw(Mark(mark.shape, mark.role, mark.plate, opacity: mark.opacity, turn: mark.turn), into: poster, colour: .white)
        }
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
            g.fill(Self.dots(in: rect, step: step, focus: focus, reach: reach, dot: dot), with: shading)
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
