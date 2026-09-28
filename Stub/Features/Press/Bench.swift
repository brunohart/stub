import SwiftUI

// The bench's three objects (ADR-016, brief §5.5–5.6): the genome's three choices, each offered as the thing a
// printer would hold. Movement is a fan of this film in all eight; inks are twelve draw-downs; stock is a swatch book.
// Every choice is from the same lists the model chooses from, and none of them moves a mark.

/// An edition drawn to fit whatever frame it is given, keeping the card's proportions: a card in the fan, a card in
/// flight to the bed.
struct CardThumb: View {
    let composition: Composition
    var light: Light = .rest
    var printed: Int = Plate.foil

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / Card.width, proxy.size.height / Card.height)
            EditionFace(composition: composition, light: light, printed: printed)
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: Card.width * scale, height: Card.height * scale, alignment: .topLeading)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(Card.width / Card.height, contentMode: .fit)
    }
}

// MARK: The fan

/// Cards on an arc, like a hand of cards, the one under the finger lifted and larger, the way the Dock magnifies.
/// Rotation is the cards' own (`FanLayout.angle`): a layout places and sizes, it does not turn.
struct FanLayout: Layout {
    /// The finger's x, if a finger is on the fan.
    var focus: CGFloat?
    var radius: CGFloat = 520
    /// The arc the hand spans, in degrees.
    var arc: Double = 32
    var cardWidth: CGFloat = 62
    var lift: CGFloat = 28
    var magnify: CGFloat = 1.18
    /// Room under each card for its note.
    var note: CGFloat = 16

    var animatableData: CGFloat {
        get { focus ?? -1000 }
        set { focus = newValue < -999 ? nil : newValue }
    }

    static func angle(_ index: Int, of count: Int, arc: Double = 32) -> Double {
        count > 1 ? -arc / 2 + arc * Double(index) / Double(count - 1) : 0
    }

    /// Where card `index` sits across a fan `width` wide.
    func centre(_ index: Int, of count: Int, width: CGFloat) -> CGFloat {
        width / 2 + radius * CGFloat(sin(Self.angle(index, of: count, arc: arc) * .pi / 180))
    }

    /// How near the finger a card at `x` is: 1 under it, falling away over about a card's width.
    func closeness(_ x: CGFloat) -> CGFloat {
        guard let focus else { return 0 }
        let d = (x - focus) / (cardWidth * 1.1)
        return exp(-d * d)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let count = subviews.count
        let height = cardWidth * Card.height / Card.width
        for (i, subview) in subviews.enumerated() {
            let a = Self.angle(i, of: count, arc: arc) * .pi / 180
            let x = bounds.minX + centre(i, of: count, width: bounds.width)
            let near = closeness(x - bounds.minX)
            let m = 1 + (magnify - 1) * near
            let y = bounds.minY + lift + (height + note) / 2 + radius * CGFloat(1 - cos(a)) - lift * near
            subview.place(at: CGPoint(x: x, y: y), anchor: .center,
                          proposal: ProposedViewSize(width: cardWidth * m, height: height * m + note))
        }
    }
}

/// This film in all eight movements, in your inks, on your stock, with your strip. Slide along it and the card under
/// the finger lifts, with a tick as each one passes; let go on one to take it.
struct Fan: View {
    let session: PressSession
    let light: Light
    let namespace: Namespace.ID
    var chose: (Movement) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Built once when the fan opens: eight compositions, not eight a frame.
    @State private var cards: [Movement: Composition] = [:]
    @State private var risen = false
    @State private var hovered: Movement?

    private let movements = Genome.movements

    var body: some View {
        GeometryReader { proxy in
            let fan = FanLayout(focus: reduceMotion ? nil : session.fanFinger)
            fan {
                ForEach(Array(movements.enumerated()), id: \.element) { index, movement in
                    card(movement)
                        // Turned about its own centre, which sits on the arc: the hand pivots far below it.
                        .rotationEffect(.degrees(FanLayout.angle(index, of: movements.count)))
                        .zIndex(Double(fan.closeness(fan.centre(index, of: movements.count, width: proxy.size.width))))
                        .offset(y: risen ? 0 : 80)
                        .opacity(risen ? 1 : 0)
                        .animation(reduceMotion ? Motion.plain : Motion.place.delay(Double(index) * 0.025), value: risen)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        session.fanFinger = value.location.x
                        hovered = movement(at: value.location.x, fan: fan, width: proxy.size.width)
                    }
                    .onEnded { value in
                        let chosen = movement(at: value.location.x, fan: fan, width: proxy.size.width)
                        session.fanFinger = nil
                        hovered = nil
                        if let chosen { chose(chosen) }
                    }
            )
        }
        .sensoryFeedback(.selection, trigger: hovered)
        .onAppear {
            cards = Dictionary(uniqueKeysWithValues: movements.map { ($0, session.composition(session.edition(in: $0))) })
            risen = true
        }
    }

    private func movement(at x: CGFloat, fan: FanLayout, width: CGFloat) -> Movement? {
        movements.indices.min { abs(fan.centre($0, of: movements.count, width: width) - x) < abs(fan.centre($1, of: movements.count, width: width) - x) }
            .map { movements[$0] }
    }

    private func card(_ movement: Movement) -> some View {
        VStack(spacing: 3) {
            if let composition = cards[movement] {
                CardThumb(composition: composition, light: light)
                    .shadow(color: .black.opacity(0.16), radius: 5, x: 2, y: 4)
                    .matchedGeometryEffect(id: movement, in: namespace, isSource: true)
            }
            // Honest machinery: which card the title drew, and which the model chose.
            Text(movement == session.modelsMovement ? "the model's" : movement == session.titlesMovement ? "drawn from the title" : " ")
                .font(Type.words(9))
                .foregroundStyle(Ink.grey)
                .lineLimit(1)
                .fixedSize()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(movement.rawValue.capitalized). \(movement.spoken)")
        .accessibilityAddTraits(movement == session.edition.movement ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { chose(movement) }
    }
}

extension Movement {
    /// A movement in a few words, as VoiceOver reads the fan: the glossary's first clause.
    var spoken: String {
        switch self {
        case .swiss: "A huge flush-left title on a strict grid."
        case .constructivist: "Diagonals, a band, a circle."
        case .deco: "Symmetry, a sunburst, stepped frames."
        case .cutout: "Cut and torn paper on one bold field."
        case .riso: "A halftone, two inks a little out of register."
        case .letterpress: "Deep serif type, one ink, generous margins."
        case .blueprint: "A technical drawing in a monospaced face."
        case .noir: "A dark field, light through a venetian blind."
        }
    }
}

// MARK: The draw-downs

/// Twelve palettes as twelve draw-downs, a test smear of each ink pulled across its own ground with a knife, in a rail
/// that snaps to one at a time. Drag one onto the card and its inks flood from where it lands; tap one and they flood
/// from the middle.
struct DrawDowns: View {
    let session: PressSession
    var tapped: (Palette) -> Void
    /// The draw-down in the middle of the rail; it opens on the card's own inks.
    @State private var centred: Palette?

    static let size = CGSize(width: 78, height: 96)

    var body: some View {
        GeometryReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    ForEach(Genome.palettes, id: \.self) { palette in
                        VStack(spacing: 6) {
                            DrawDown(palette: palette)
                                .frame(width: Self.size.width, height: Self.size.height)
                                .draggable(palette.rawValue) {
                                    DrawDown(palette: palette).frame(width: Self.size.width, height: Self.size.height)
                                }
                            Text(palette.rawValue.capitalized)
                                .font(Type.words(12))
                                .foregroundStyle(palette == session.edition.palette ? Ink.ink : Ink.grey)
                        }
                        .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                            content.scaleEffect(phase.isIdentity ? 1.06 : 0.9)
                        }
                        .onTapGesture { tapped(palette) }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(palette.rawValue.capitalized) inks")
                        .accessibilityAddTraits(palette == session.edition.palette ? [.isButton, .isSelected] : .isButton)
                        .accessibilityAction { tapped(palette) }
                        .id(palette)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .contentMargins(.horizontal, max((proxy.size.width - Self.size.width) / 2, 0), for: .scrollContent)
            .scrollPosition(id: $centred, anchor: .center)
        }
        .onAppear { centred = session.edition.palette }
    }
}

/// One palette pulled across its own ground: the two plates, the black and the metal, each a smear that starts square
/// where the knife met the paper and thins out ragged where it lifted.
struct DrawDown: View {
    let palette: Palette

    var body: some View {
        let inks = palette.inks
        Canvas { context, size in
            context.fill(Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 3), with: .color(Color(hex: inks.ground)))
            var dice = Dice(seed: Release.fnv("draw-down " + palette.rawValue))
            let rows = [inks.primary, inks.secondary, inks.ink, inks.foilBase]
            let band = size.height / CGFloat(rows.count + 1)
            for (i, ink) in rows.enumerated() {
                let top = band * (CGFloat(i) + 0.55)
                let height = band * 0.62
                let start: CGFloat = 8
                let end = size.width * CGFloat(dice.between(0.72, 0.9))
                // The full-strength smear: square where the knife started, a ragged lip where it lifted.
                var smear = Path()
                smear.move(to: CGPoint(x: start, y: top))
                smear.addLine(to: CGPoint(x: end, y: top + CGFloat(dice.between(-0.6, 0.6))))
                for step in 1...5 {
                    let t = CGFloat(step) / 5
                    smear.addLine(to: CGPoint(x: end + CGFloat(dice.between(-4, 3)), y: top + height * t))
                }
                smear.addLine(to: CGPoint(x: start, y: top + height))
                smear.closeSubpath()
                context.fill(smear, with: .color(Color(hex: ink)))
                // The thin film the knife leaves behind the lip.
                let tail = CGRect(x: end - 2, y: top + height * 0.2, width: size.width - end - 4, height: height * 0.6)
                context.fill(Path(tail), with: .linearGradient(Gradient(colors: [Color(hex: ink).opacity(0.45), Color(hex: ink).opacity(0)]),
                                                              startPoint: CGPoint(x: tail.minX, y: 0), endPoint: CGPoint(x: tail.maxX, y: 0)))
            }
        }
        .shadow(color: .black.opacity(0.14), radius: 3, x: 1, y: 2)
    }
}

// MARK: The swatch book

/// Four swatches of card, lit by the same light as the bed. Hold one and rub it to feel it before you choose: the
/// texture under the finger is that stock's. Tap to choose, and the card is printed again on it.
struct SwatchBook: View {
    let session: PressSession
    let light: Light
    var chose: (Stock) -> Void

    var body: some View {
        HStack(spacing: 16) {
            ForEach(Genome.stocks, id: \.self) { stock in
                Swatch(stock: stock, inks: session.edition.palette.inks, light: light, chosen: stock == session.edition.stock) {
                    chose(stock)
                }
            }
        }
    }
}

private struct Swatch: View {
    let stock: Stock
    let inks: EditionInks
    let light: Light
    let chosen: Bool
    var choose: () -> Void

    @State private var texture = Texture()
    @State private var touchedAt: Date?
    @State private var moved: CGFloat = 0

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Rectangle()
                    .fill(Color(hex: inks.groundIsLight ? inks.ground : inks.hex(.light)))
                    .modifier(StockEffect(light: light, stock: stock, seed: Double((Genome.stocks.firstIndex(of: stock) ?? 0) * 37)))
                if stock == .foil || stock == .holographic {
                    // The stamp the stock carries.
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white)
                        .frame(width: 30, height: 30)
                        .modifier(FoilEffect(light: light, metal: inks.foilBase, holographic: stock == .holographic,
                                             lightGround: inks.groundIsLight))
                }
            }
            .frame(width: 66, height: 84)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .shadow(color: .black.opacity(0.16), radius: 3, x: 1, y: 2)
            Text(stock.words)
                .font(Type.words(12))
                .foregroundStyle(chosen ? Ink.ink : Ink.grey)
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if touchedAt == nil {
                        touchedAt = .now
                        moved = 0
                        texture.begin(on: stock)
                    }
                    let v = value.velocity
                    texture.stroke(speed: (v.width * v.width + v.height * v.height).squareRoot())
                    moved = max(moved, (value.translation.width * value.translation.width + value.translation.height * value.translation.height).squareRoot())
                }
                .onEnded { _ in
                    texture.end()
                    let quick = touchedAt.map { Date.now.timeIntervalSince($0) < 0.35 } ?? false
                    touchedAt = nil
                    if quick, moved < 8 { choose() }
                }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(stock.words). \(stock.feel)")
        .accessibilityHint("Double-tap to print on it. Double-tap and hold, then rub, to feel it.")
        .accessibilityAddTraits(chosen ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { choose() }
    }
}

extension Stock {
    /// What the stock is, as VoiceOver reads the swatch book: the first sentence of its description.
    var feel: String {
        switch self {
        case .cotton: "Thick, soft, uncoated."
        case .coated: "Smooth satin card."
        case .foil: "Coated card with a metal foil stamp."
        case .holographic: "Coated card with a holographic film stamp that changes colour as it turns."
        }
    }
}
