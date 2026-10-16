import SwiftUI

/// What the drawer shows of each stub (ADR-026): the ticket as it was kept, or its edition, as the person chooses.
enum DrawerFace: String, CaseIterable {
    case ticket, edition

    var name: String { self == .ticket ? "Tickets" : "Editions" }
}

/// One stub in the drawer (ADR-026). Every card in a row is the same width and its picture sits in the same mount, so the
/// drawer reads in rows and years however many stubs it holds; each ticket keeps its own shape inside the mount, standing
/// on the line its words hang from, and its own tilt. Pressed, it sits up straight and the print lifts off the photograph.
/// Turned to the other face, it turns over, a beat after the card before it, so the whole drawer turns in a wave.
struct StubCard: View {
    let stub: Stub
    let face: DrawerFace
    /// This stub's copy of its edition, counted against the drawer.
    let copy: Copy
    /// Where it stands in the drawer: the wave turns the front cards first.
    var order: Int = 0
    /// Being carried by a finger: what is left on the table is a gap with the card's outline.
    var carried = false
    var pressed = false
    /// The mount's shape for this row: as tall as the row's tallest ticket needs, so a row of wide tickets is not a row of
    /// gaps (the drawer works it out). Editions are all one shape.
    var mount: CGFloat? = nil

    @State private var shown: DrawerFace
    @State private var angle: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    /// A finger on the card, from the drawer's button.
    @Environment(\.cardPressed) private var touched

    init(stub: Stub, face: DrawerFace, copy: Copy, order: Int = 0, carried: Bool = false, pressed: Bool = false, mount: CGFloat? = nil) {
        self.mount = mount
        self.stub = stub
        self.face = face
        self.copy = copy
        self.order = order
        self.carried = carried
        self.pressed = pressed
        _shown = State(initialValue: face)
    }

    /// A ticket's own shape, width over height, as the drawer shows it: no taller than wide by half, no flatter than 2.6:1.
    @MainActor
    static func aspect(of stub: Stub) -> CGFloat {
        guard let shape = PlateAspects.shared.aspect(for: stub.id, data: stub.imageData) else { return 1.75 }
        return min(max(CGFloat(shape), 0.5), 2.6)
    }

    /// The mount for a row of tickets: the tallest ticket's shape, never taller than a little wider than square.
    @MainActor
    static func mount(for row: [Stub]) -> CGFloat {
        max(row.map(aspect(of:)).min() ?? 1.75, 1.1)
    }

    private var isPressed: Bool {
        #if DEBUG || PERF
        return pressed || touched || DebugDrive.shared.pressedID == stub.id
        #else
        return pressed || touched
        #endif
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Color.clear
                .aspectRatio(shown == .edition ? Card.width / Card.height : (mount ?? 1.75), contentMode: .fit)
                .overlay(alignment: .bottomLeading) { picture }
                .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
                .opacity(carried ? 0.18 : 1)
                // Touch-down: the stub sits up straight, overshooting once. Reduce Motion: it never tilts. Only the stub lies
                // at an angle; the words under it are set level, as a label is (DESIGN.md rule 3).
                .rotationEffect(.degrees(isPressed || reduceMotion ? 0 : stub.tilt))
            caption
        }
        // And lifts a little.
        .scaleEffect(isPressed ? 1.02 : 1)
        .animation(Motion.press(reduceMotion: reduceMotion), value: isPressed)
        .onChange(of: face) { _, next in turn(to: next) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(stub.spokenLabel)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens the stub.")
    }

    /// Over to the other face: a quarter turn away, the face swapped edge-on where nobody can see it, and a spring back to
    /// flat that overshoots once. Under Reduce Motion the face changes where it lies.
    private func turn(to next: DrawerFace) {
        guard !reduceMotion else {
            withAnimation(Motion.plain) { shown = next }
            return
        }
        let delay = Double(min(order, 16)) * 0.035
        withAnimation(.easeIn(duration: 0.15).delay(delay)) { angle = 90 } completion: {
            var still = Transaction()
            still.disablesAnimations = true
            withTransaction(still) {
                shown = next
                angle = -90
            }
            withAnimation(Motion.stamp) { angle = 0 }
        }
    }

    @ViewBuilder
    private var picture: some View {
        // Printed artwork: the card's spoken label says what it shows, so its own type is not read out a second time, and
        // is not judged as interface text (docs/decisions/005-accessibility.md).
        Group {
            switch shown {
            case .ticket: ticket
            case .edition: EditionThumbnail(stub: stub, copy: copy)
            }
        }
        .accessibilityHidden(true)
        .accessibilityIdentifier("artwork")
    }

    /// The ticket as it was kept, its own shape, standing at the foot of the mount. A photograph that could not be cropped
    /// is still bounded: no taller than the mount, no flatter than 2.6:1.
    @ViewBuilder
    private var ticket: some View {
        if let ui = PlateImage.image(for: stub.id, in: .card, data: stub.imageData) {
            let aspect = Self.aspect(of: stub)
            Color.clear
                .aspectRatio(aspect, contentMode: .fit)
                .overlay(Image(uiImage: ui).resizable().scaledToFill())
                .clipped()
                .silkscreened(strength: isPressed ? 0.15 : 1)
                .animation(Motion.settle, value: isPressed)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Ink.navy.opacity(0.10))
                        .offset(x: 5, y: 6)
                )
        } else {
            BlankStub(tilt: 0, title: stub.title)
                .aspectRatio(1.75, contentMode: .fit)
        }
    }

    /// Under a ticket, what it says, which its photograph may be too small or too faded to. An edition prints its own title,
    /// night and seat, so under an edition there is nothing: the drawer of editions is a gallery (ADR-048). At the
    /// accessibility sizes the words come back, at the person's own size.
    @ViewBuilder
    private var caption: some View {
        if shown == .ticket || typeSize.isAccessibilitySize { words }
    }

    private var words: some View {
        VStack(alignment: .leading, spacing: 3) {
            // Never truncated: at the large Dynamic Type sizes a title takes the lines it needs.
            Text(stub.title)
                .displayText(16)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                if let d = stub.displayDate { Text(d).numberText(12) }
                if let s = stub.seat { Text(s).numberText(12) }
            }
            // An edition prints its cinema on its strip; a ticket may be too small to read.
            if shown == .ticket, let place = stub.venue ?? stub.cinema {
                Text(place).font(Type.words(12)).foregroundStyle(Ink.grey)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 2)
    }
}

/// What a finger carries: the stub's picture alone, lifted off the table, without its words.
struct CarriedPicture: View {
    let stub: Stub
    let face: DrawerFace
    let copy: Copy

    var body: some View {
        Group {
            if face == .edition {
                EditionThumbnail(stub: stub, copy: copy).frame(width: 132)
            } else if let ui = PlateImage.image(for: stub.id, in: .card, data: stub.imageData) {
                let aspect = StubCard.aspect(of: stub)
                Image(uiImage: ui).resizable().aspectRatio(aspect, contentMode: .fill)
                    .frame(width: aspect >= 1 ? 176 : 176 * aspect)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            } else {
                BlankStub(tilt: 0, title: stub.title).frame(width: 176, height: 100)
            }
        }
        .contentShape(.dragPreview, RoundedRectangle(cornerRadius: 3))
    }
}

/// A stub's edition at the size of a card in the drawer: the whole card, still, lit from where the lamp rests. While the
/// release has no edition yet it is bare stock, and the press prints it in its turn.
struct EditionThumbnail: View {
    let stub: Stub
    let copy: Copy
    private let editions = Editions.shared

    var body: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / Card.width
            Group {
                if let edition = editions.edition(for: stub.title) {
                    let composition = Compositions.of(edition, copy)
                    EditionFace(composition: composition)
                        // A pass pulled through the stub's own photograph needs it; nothing else on the card does.
                        .environment(\.stubPhoto, composition.edition.acts.contains { $0.screen == .stub }
                            ? PlateImage.image(for: stub.id, in: .card, data: stub.imageData) : nil)
                        // The card's edge: a sliver of darker stock on the side away from the lamp.
                        .background(
                            TicketShape(punches: composition.punches)
                                .fill(Color(hex: EditionInks.mix(composition.inks.hex(composition.stripField), 0x000000, 0.35)))
                                .offset(x: 1.2, y: 1.8)
                        )
                        .transition(.opacity.animation(Motion.settle))
                } else {
                    TicketShape().fill(Ink.cream)
                        .overlay { TicketShape().stroke(Ink.ink.opacity(0.08), lineWidth: 1) }
                }
            }
            .frame(width: Card.width, height: Card.height)
            .shadow(color: .black.opacity(0.14), radius: 9, x: 4, y: 7)
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: proxy.size.width, height: Card.height * scale, alignment: .topLeading)
        }
        .aspectRatio(Card.width / Card.height, contentMode: .fit)
    }
}

/// The compositions the drawer has set lately. A drawer of editions redraws its cards whenever anything on the table moves;
/// none of them should be set again for it.
@MainActor
enum Compositions {
    private static var recent: [Composition] = []

    static func of(_ edition: Edition, _ copy: Copy) -> Composition {
        if let found = recent.first(where: { $0.edition == edition && $0.copy == copy }) { return found }
        let composition = Composition(edition: edition, copy: copy)
        recent.insert(composition, at: 0)
        if recent.count > 80 { recent.removeLast() }
        return composition
    }
}

/// The stub with no photograph. A perforated parchment card, printed with what we know.
struct BlankStub: View {
    var tilt: Double
    var title: String? = nil
    /// An unissued ticket: its fields printed and waiting to be filled, as a booking office's blank stock is. The empty
    /// drawer's, so the first thing a new person sees says what the drawer is for (ADR-048).
    var unissued = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Ink.cream)
                .overlay(perforation, alignment: .trailing)
                .background(RoundedRectangle(cornerRadius: 3).fill(Ink.orange.opacity(0.12)).offset(x: 5, y: 6))
            VStack(alignment: .leading, spacing: 6) {
                Text("ADMIT ONE").font(Type.numbers(10)).foregroundStyle(Ink.grey)
                    .accessibilityHidden(true)
                if let title {
                    Text(title).displayText(15).fixedSize(horizontal: false, vertical: true)
                }
                if unissued { fields.padding(.top, 8) }
            }
            .padding(12)
            .padding(.trailing, 28)
        }
        .rotationEffect(.degrees(tilt))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title.map { "A blank stub for \($0)." } ?? "A blank stub. The drawer is empty.")
        // A drawing of a ticket, said in words (decision 005).
        .accessibilityAddTraits(.isImage)
        .accessibilityIdentifier("artwork")
    }

    /// The blank fields of an unissued ticket: a label in the mono over a ruled line, the film's line the longest.
    private var fields: some View {
        VStack(alignment: .leading, spacing: 22) {
            field("FILM")
            HStack(alignment: .bottom, spacing: 16) { field("CINEMA"); field("SEAT", width: 58) }
            HStack(alignment: .bottom, spacing: 16) { field("DATE"); field("PRICE", width: 58) }
        }
        // Printed on the drawing of a ticket, which is spoken as one picture (decision 005).
        .accessibilityHidden(true)
        .accessibilityIdentifier("artwork")
    }

    private func field(_ label: String, width: CGFloat? = nil) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(Type.numbers(9)).foregroundStyle(Ink.greyMark)
            Rectangle().fill(Ink.ink.opacity(0.16)).frame(height: 0.75)
        }
        .frame(width: width)
        .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
    }

    private var perforation: some View {
        VStack(spacing: 5) {
            ForEach(0..<14, id: \.self) { _ in
                Circle().fill(Ink.greyMark.opacity(0.55)).frame(width: 4, height: 4)
            }
        }
        .padding(.trailing, 22)
    }
}
