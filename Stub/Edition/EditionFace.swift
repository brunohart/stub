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
    /// How the stock shows through: a long soft fibre in cotton, a satin gloss on coated card.
    var fibre: Double { self == .cotton ? 0.045 : 0 }
    var gloss: Double {
        switch self {
        case .cotton: 0.02
        case .coated: 0.10
        case .foil: 0.08
        case .holographic: 0.10
        case .gloss: 0.30
        case .matte: 0
        case .velvet: 0.075
        case .pearl: 0.08
        }
    }
    /// How tight the coat's sheen is: a satin's soft band, a gloss's narrow highlight, a soft-touch's breath.
    var sheen: Double {
        switch self {
        case .gloss: 7.0
        case .velvet: 1.1
        default: 2.2
        }
    }
    /// How much mica is in the coat: the hues the sheen runs through as the light crosses it.
    var pearl: Double { self == .pearl ? 1 : 0 }
    /// How hard the plates were pressed into it, and how wide the walls of the impression are, in points. A soft-touch
    /// coat takes the impression deep; a gloss holds the ink proud and crisp.
    var depth: Double {
        switch self {
        case .cotton: 2.2
        case .velvet: 1.6
        case .gloss: 0.7
        default: 1.0
        }
    }
    var reach: Double { self == .cotton ? 1.2 : self == .velvet ? 1.0 : 0.8 }
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
    /// How far apart the layers are lifted, 0 (the card) to 1 (the separations, brief §5.4).
    var separation: CGFloat = 0
    /// Draw the card as its stack of sheets even when they lie flat. The press bed does, so parting the plates never
    /// changes how the card is drawn: switching from the flat card to the projected sheets re-rasterised every edge of the
    /// type at the moment they began to part, and again as they closed (2026-10-13).
    var asSheets = false

    /// The sheets "at rest" are this far apart: too little to see, but not the identity, which SwiftUI would skip and draw
    /// the flat way, putting the switch back at the first frame of parting.
    static let resting: CGFloat = 0.0001
    /// How deep the impression is, as a share of the stock's: the platen brings it up from 0 after a pull.
    var impression: Double = 1
    /// How wet the ink still is after a pull, 1 to 0.
    var wet: Double = 0

    var body: some View {
        // Printed artwork: whoever shows the card says what is on it (decision 005).
        Group { art }
            .accessibilityHidden(true)
            .accessibilityIdentifier("artwork")
    }

    @ViewBuilder private var art: some View {
        if separation > 0 || asSheets {
            // The layers, each a sheet on its own, lifted apart and seen from above. Each keeps its shaders, so the foil
            // still catches the light.
            ZStack(alignment: .topLeading) {
                ForEach(Array(Separation.layers(metallic: composition.isMetallic).enumerated()), id: \.element) { index, layer in
                    sheet(layer)
                        .projectionEffect(ProjectionTransform(Separation.transform(index: index, separation: max(separation, Self.resting))))
                }
            }
            .frame(width: Card.width, height: Card.height)
            // The flat card and the first frame of the sheets are the same picture, so one hands over to the other exactly.
            // Under an animation SwiftUI would otherwise cross-fade the two branches, and the type would ghost as the
            // plates lifted and again as they pressed together (2026-10-13).
            .transition(.identity)
        } else {
            ZStack(alignment: .topLeading) {
                ForEach(Separation.layers(metallic: composition.isMetallic), id: \.self) { layer in
                    layerArt(layer)
                    // The stub's photograph pulled through a screen: the image layer, over the plates, under the type.
                    if layer == .second { PhotoPasses(composition: composition) }
                }
            }
            .frame(width: Card.width, height: Card.height)
            .clipShape(TicketShape(punches: composition.punches))
            .transition(.identity)
        }
    }

    /// One layer of the card as a sheet of film: its own ink on a clear ground, cut to the ticket, and a hairline edge
    /// in its ink at a fifth so the film reads as film. The stock is the card itself, opaque.
    func sheet(_ layer: Separation.Layer) -> some View {
        ZStack(alignment: .topLeading) {
            layerArt(layer)
            // The stub's photograph rides on the second plate's sheet, as a screen it was pulled through would.
            if layer == .second { PhotoPasses(composition: composition) }
        }
            .frame(width: Card.width, height: Card.height)
            .clipShape(TicketShape(punches: composition.punches))
            .overlay {
                // The film's edge comes up as the sheets part, so the first frame apart is the flat card exactly.
                TicketShape(punches: composition.punches)
                    .stroke(Color(hex: edge(of: layer)).opacity((layer == .stock ? 0.35 : 0.2) * min(1, Double(separation) * 6)), lineWidth: 0.75)
            }
    }

    private func edge(of layer: Separation.Layer) -> UInt32 {
        let inks = composition.inks
        return switch layer {
        case .stock: EditionInks.mix(inks.hex(composition.stripField), 0x000000, 0.35)
        case .first: inks.primary
        case .second: inks.secondary
        case .foil: inks.foilBase
        case .type: inks.ink
        }
    }

    /// One layer's art, the size of the card: the stock under everything, a plate's inks with their impression, or
    /// the foil stamped in its metal. The print run shows each as its pass comes round.
    @ViewBuilder
    private func layerArt(_ layer: Separation.Layer) -> some View {
        let c = composition
        let stock = c.edition.stock
        // Letterpress is pressed hardest: it is the movement that is only type and stock.
        let depth = stock.depth * (c.edition.movement == .letterpress ? 1.6 : 1)
        switch layer {
        case .stock:
            Canvas { context, _ in
                context.fill(Path(Card.posterRect), with: .color(c.inks.color(c.posterField)))
                context.fill(Path(Card.stripRect), with: .color(c.inks.color(c.stripField)))
            }
            .modifier(StockEffect(light: light, stock: stock, seed: Double(c.paper % 997), patina: c.patina))
        case .first, .second, .type:
            // One canvas a plate, so each has its own impression and the print run can lay each down on its own. The
            // type lies over the foil, never under it: stamped last in time, but a title the foil covered would be a
            // title nobody could read.
            let plate = layer.plate ?? .type
            PlateArt(composition: c, plate: plate, focus: focus).equatable()
                // Each plate lands where this copy's pull put it (ADR-043).
                .offset(c.registration(plate))
                .modifier(ReliefEffect(light: light, depth: depth * impression, reach: stock.reach, wet: wet))
                .modifier(AgedEffect(patina: c.patina, foxes: true))
                .opacity(printed >= plate.rawValue ? 1 : 0)
        case .foil:
            PlateArt(composition: c, plate: nil, focus: focus).equatable()
                .offset(c.registration(nil))
                .modifier(FoilEffect(light: light, metal: c.inks.foilBase, holographic: stock == .holographic,
                                     lightGround: c.inks.groundIsLight))
                .modifier(AgedEffect(patina: c.patina, foxes: false))
                .opacity(printed >= Plate.foil ? 1 : 0)
                // The foil lands: a breath larger, then pressed flat.
                .scaleEffect(printed >= Plate.foil ? 1 : 1.04)
        }
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

// The three surfaces as modifiers, so the look stays specified at the modifier boundary (ADR-002): Metal draws
// them by default, and `-look swiftui` prints the edition flat, in its inks, with the foil in its metal.

extension EnvironmentValues {
    /// Whether the edition is lit by the one light, the phone's (DESIGN.md › Editions rule 4). The card on a real table
    /// is lit by the room instead (ADR-018), so its maps are printed unlit: the stock keeps its fibre and its age but not
    /// its sheen, the inks have no relief (the room's light reads a normal map), the foil is flat in its metal.
    @Entry var editionLit = true
}

struct StockEffect: ViewModifier {
    var light: Light
    var stock: Stock
    var seed: Double
    /// The age the stock has earned (brief §6.2). `Patina.none` changes nothing.
    var patina: Patina = .none
    @Environment(\.editionLit) private var lit

    func body(content: Content) -> some View {
        if LookEngine.current.isMetal {
            content.colorEffect(ShaderLibrary.stock(
                .boundingRect, .float2(light.vector), .float(stock.fibre), .float(lit ? stock.gloss : 0), .float(stock.sheen),
                .float(lit ? stock.pearl : 0), .float(seed),
                .float(patina.age), .float(patina.warmth), .float(patina.wear), .float(lit ? patina.burnish : 0),
                // Never an empty buffer: a spot of strength zero stands in for none.
                .floatArray(patina.spots.isEmpty ? [0, 0, 1, 0] : patina.spots)
            ))
        } else {
            content
        }
    }
}

/// The edition's shaders, compiled ahead of their first use. SwiftUI compiles a shader the first time a view uses it, and
/// a frame drawn before that, on screen or by `ImageRenderer`, is drawn without it: a first share, a first room map or a
/// test's first render could leave out the foil or the patina (2026-09-30, found by `theInkAgesWithThePaper`).
enum EditionShaders {
    static func prepare() async throws {
        let spots: [Float] = [0, 0, 1, 0]
        let colour: [(Shader, Shader.UsageType)] = [
            (ShaderLibrary.stock(.boundingRect, .float2(CGPoint.zero), .float(0), .float(0), .float(2.2), .float(0), .float(0),
                                 .float(0), .float(0), .float(0), .float(0), .floatArray(spots)), .colorEffect),
            (ShaderLibrary.aged(.boundingRect, .float2(CGPoint.zero), .float2(CGPoint.zero), .float(0), .float(0), .floatArray(spots)), .colorEffect),
            (ShaderLibrary.flood(.float2(CGPoint.zero), .float(0), .float(0), .float(0), .float(0)), .colorEffect),
            (ShaderLibrary.relief(.boundingRect, .float2(CGPoint.zero), .float(0), .float(0), .float(0)), .layerEffect),
            (ShaderLibrary.foil(.boundingRect, .float2(CGPoint.zero), .color(.white), .float(0), .float(0)), .layerEffect),
        ]
        for (shader, usage) in colour { try await shader.compile(as: usage) }
    }
}

/// The patina on what is printed over the stock: the ink worn through at the corners, foxing coming up through the ink
/// (`foxes`) but not through foil (2026-09-30). Drawn lit or unlit, like the stock's patina: age is surface, not light.
/// `origin` is where the layer sits on the card, for a layer smaller than the card. Nothing at all at age 0.
struct AgedEffect: ViewModifier {
    var patina: Patina
    var foxes: Bool
    var origin: CGPoint = .zero

    func body(content: Content) -> some View {
        if LookEngine.current.isMetal, !patina.isIdentity {
            content.colorEffect(ShaderLibrary.aged(
                .boundingRect, .float2(origin), .float2(CGPoint(x: Card.width, y: Card.height)),
                .float(patina.wear), .float(foxes ? 0.85 : 0),
                // Never an empty buffer: a spot of strength zero stands in for none.
                .floatArray(patina.spots.isEmpty ? [0, 0, 1, 0] : patina.spots)
            ))
        } else {
            content
        }
    }
}

struct ReliefEffect: ViewModifier {
    var light: Light
    var depth: Double
    var reach: Double
    var wet: Double = 0
    @Environment(\.editionLit) private var lit

    func body(content: Content) -> some View {
        if LookEngine.current.isMetal, lit {
            content.layerEffect(
                ShaderLibrary.relief(.boundingRect, .float2(light.vector), .float(depth), .float(reach), .float(wet)),
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
    @Environment(\.editionLit) private var lit

    func body(content: Content) -> some View {
        if LookEngine.current.isMetal, lit {
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

/// New inks flooding a card from `origin`, `progress` of the way to its far corner. Metal draws the wicking edge; under
/// `-look swiftui` the new card cross-fades.
struct FloodEffect: ViewModifier {
    var origin: CGPoint
    var progress: CGFloat
    var stock: Stock
    var seed: Double

    /// How far the flood's radius runs, from `origin`, for every corner to be under the ink at the end: the farthest
    /// corner, plus the edge's half-width, plus the most the stock's noise can push the edge back (`wander`).
    /// Arithmetic, so it belongs to no actor: a `ViewModifier` is main-actor by inference, and without `nonisolated`
    /// a caller off the main actor (a test) trips Swift 6's runtime isolation check inside the `map`.
    nonisolated static func reach(from origin: CGPoint, on stock: Stock) -> CGFloat {
        let corners = [CGPoint(x: 0, y: 0), CGPoint(x: Card.width, y: 0), CGPoint(x: 0, y: Card.height), CGPoint(x: Card.width, y: Card.height)]
        return (corners.map { $0.distance(to: origin) }.max() ?? Card.height) + stock.wicking.soft + stock.wicking.wander
    }

    func body(content: Content) -> some View {
        if LookEngine.current.isMetal {
            content.colorEffect(ShaderLibrary.flood(
                .float2(origin), .float(progress * Self.reach(from: origin, on: stock)), .float(stock.wicking.soft),
                .float(stock.wicking.wander), .float(seed)
            ))
        } else {
            content.opacity(progress)
        }
    }
}

extension Stock {
    /// How new ink spreads into it: the width of the edge, and how far the paper pushes it in and out. Cotton wicks wide
    /// and soft; coated card holds a crisp edge.
    var wicking: (soft: CGFloat, wander: CGFloat) {
        switch self {
        case .cotton: (16, 14)
        case .coated: (3, 8)
        case .foil: (4, 9)
        case .holographic: (4, 9)
        case .gloss: (2, 6)
        case .matte: (5, 9)
        case .velvet: (7, 10)
        case .pearl: (3, 8)
        }
    }
}
