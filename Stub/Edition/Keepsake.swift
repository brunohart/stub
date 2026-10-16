import SwiftUI

/// An edition you can hold (ADR-015). The edition in front, the stub as scanned on the back. It tilts with the
/// phone and under a finger, lit from one light that moves with it; a finger dragged across it feels the stock; a
/// tap turns it over; a hold on the back lifts the silkscreen off the photograph, as in the drawer. The first
/// time a release is seen its edition is chosen and printed here, pass by pass, the foil last.
struct Keepsake: View {
    let stub: Stub
    let copy: Copy
    /// The back is showing.
    @Binding var turned: Bool
    /// Run the press even when the release has been printed before: a stub just kept gets its copy printed.
    var pressesOnAppear: Bool
    /// Hold the front and the card lifts and goes to the press room (ADR-016). `nil` where there is no press to go to.
    var takeToPress: (() -> Void)?
    /// Where the press room's zoom grows from.
    var pressSource: Namespace.ID?
    /// The angle the card lay at in the drawer, in degrees: the card wears it, the words under it stay level (DESIGN.md
    /// rule 3).
    var restingTilt: Double = 0

    private let editions = Editions.shared
    @State private var attitude = Attitude()
    @State private var texture = Texture()
    @State private var memo = CompositionMemo()
    @State private var photo: UIImage?
    @State private var code: CGImage?
    /// Whole from the first frame unless a press is coming: a detail that opened on bare stock and filled in a frame
    /// later would flash.
    @State private var printed: Int
    @State private var pass = 0
    @State private var choosing = false
    @State private var finger: CGPoint = .zero
    @State private var holding = false
    @State private var angle: Double = 0
    @State private var touchedAt: Date?
    @State private var lastY: CGFloat?
    /// Held long enough on the front: the card has lifted off the table and is on its way to the press.
    @State private var lifted = false
    /// A finger is holding the front: an orange line runs round the card's edge until it lifts (ADR-030).
    @State private var charging = false
    @State private var holdTimer: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(stub: Stub, copy: Copy, turned: Binding<Bool>, pressesOnAppear: Bool = false,
         takeToPress: (() -> Void)? = nil, pressSource: Namespace.ID? = nil, restingTilt: Double = 0) {
        self.stub = stub
        self.copy = copy
        _turned = turned
        self.pressesOnAppear = pressesOnAppear
        self.takeToPress = takeToPress
        self.pressSource = pressSource
        self.restingTilt = restingTilt
        _printed = State(initialValue: pressesOnAppear ? 0 : Plate.foil)
    }

    var body: some View {
        let edition = editions.edition(for: stub.title)
        VStack(alignment: .leading, spacing: 14) {
            GeometryReader { proxy in
                let scale = proxy.size.width / Card.width
                // Printed artwork: the card's spoken label (below) says what it shows (decision 005).
                card(edition)
                    .accessibilityHidden(true)
                    .accessibilityIdentifier("artwork")
                    .scaleEffect(scale, anchor: .topLeading)
                    .frame(width: proxy.size.width, height: Card.height * scale, alignment: .topLeading)
                    .modifier(PressSource(namespace: pressSource))
                    .contentShape(Rectangle())
                    // Alongside the scroll, never instead of it: a drag that starts on the card still scrolls the page,
                    // and the card leans with it and settles when the finger lifts.
                    .simultaneousGesture(handle(scale: scale, stock: edition?.stock ?? .coated))
            }
            .aspectRatio(Card.width / Card.height, contentMode: .fit)
            .rotationEffect(.degrees(restingTilt))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(spoken(edition))
            .accessibilityHint(turned ? "Turns it back to the edition." : "Turns it over to the stub as it was scanned.")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { turned.toggle() }
            .accessibilityAction(named: "Lift the print") { hold(!holding) }
            .accessibilityAction(named: "Take it to the press") { if edition != nil, !choosing { takeToPress?() } }

            // What the card does under a finger, said plainly under it every time (ADR-030): a tap turns it over, a hold
            // takes it to the press; on the back, a hold lifts the print. While the press is choosing, that is said instead.
            Group {
                if choosing {
                    HStack(spacing: 10) {
                        ProgressView().tint(Ink.orange)
                        Text("Choosing an edition for \(stub.title)…")
                            .font(Type.words(14)).foregroundStyle(Ink.soft(0.75))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    GestureLegend(items: turned
                        ? [("hand.tap", "Tap to turn back"), ("hand.point.up.braille", "Hold the photo to lift the print")]
                        : takeToPress == nil ? [("hand.tap", "Tap to turn over")]
                        : [("hand.tap", "Tap to turn over"), ("hand.point.up.braille", "Hold for the press")])
                }
            }
            .frame(maxWidth: .infinity)
            .animation(Motion.place, value: turned)
        }
        .task(id: stub.id) { await press() }
        #if DEBUG || PERF
        .task { if Stage.tilts { await Stage.sweep() } }
        #endif
        .task(id: copy.message) { code = await Aztec.made(for: copy.message) }
        .onAppear {
            // A card asked to open turned over (`-turned`) is already turned: no turn to watch, no onChange to fire.
            angle = turned ? 180 : 0
            if !reduceMotion { attitude.start() }
        }
        .onDisappear {
            attitude.stop()
            texture.end()
        }
        .onChange(of: turned) { _, now in
            withAnimation(reduceMotion ? Motion.plain : Motion.settle) { angle = now ? 180 : 0 }
            if !now { hold(false) }
        }
        // A light tap for each plate as it lands, a heavy one for the foil: the press, felt.
        .sensoryFeedback(trigger: pass) { _, new in
            new == Plate.foil ? .impact(weight: .heavy, intensity: 0.9) : new > 0 ? .impact(weight: .light, intensity: 0.7) : nil
        }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.5), trigger: turned)
        // The card lifting off the table on its way to the press.
        .sensoryFeedback(.impact(weight: .light, intensity: 0.8), trigger: lifted) { _, now in now }
        .onAppear {
            lifted = false
            charging = false
        }
        #if DEBUG || PERF
        .onChange(of: DebugDrive.shared.holding) { _, held in if turned { hold(held) } }
        #endif
    }

    /// The finger, the gyroscope and (in Debug) the driver, as one tilt.
    private var tilt: CGPoint {
        #if DEBUG || PERF
        if let held = DebugDrive.shared.tilt { return held }
        #endif
        return CGPoint(x: max(-1, min(1, attitude.tilt.x + finger.x)), y: max(-1, min(1, attitude.tilt.y + finger.y)))
    }

    @ViewBuilder
    private func card(_ edition: Edition?) -> some View {
        let tilt = self.tilt
        let light = Light(tilt: tilt)
        // Under Reduce Motion the light still moves under a finger; the card itself does not.
        let lean = reduceMotion ? 0 : 11.0
        Group {
            if let edition {
                let composition = memo.composition(edition, copy)
                Turnover(angle: angle, flat: reduceMotion) {
                    EditionFace(composition: composition, light: light, printed: printed)
                } back: {
                    EditionBack(composition: composition, photo: photo, tilt: stub.tilt, code: code, light: light,
                                silkscreen: holding ? 0 : 1, pencil: Pencil(edition: edition),
                                signature: Signatures.shared.image)
                }
                // The card's edge: a sliver of darker stock showing on the side away from the light.
                .background(
                    // Punched too, and mirrored when the back is showing: through a hole, the cut wall shows on one side.
                    TicketShape(punches: composition.punches, mirrored: angle > 90)
                        .fill(Color(hex: EditionInks.mix(composition.inks.hex(composition.stripField), 0x000000, 0.35)))
                        .offset(x: 1.2 - tilt.x * 1.2, y: 1.8 - tilt.y * 1.2)
                )
                // Each punch as a hole cut through card, not a mark printed on it (ADR-032).
                .overlay { PunchWalls(punches: composition.punches, mirrored: angle > 90, tilt: tilt).allowsHitTesting(false) }
            } else {
                // Bare card while the edition is being chosen.
                TicketShape()
                    .fill(Ink.cream)
            }
        }
        .frame(width: Card.width, height: Card.height)
        // The hold, shown: a line of the marks' orange drawn round the edge while the finger stays, so holding is seen to
        // be doing something; the card lifts for the press when it closes.
        .overlay {
            if takeToPress != nil, angle < 90 {
                TicketOutline()
                    .trim(from: 0, to: charging ? 1 : 0)
                    .stroke(Ink.orange, style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
                    .opacity(charging || lifted ? 1 : 0)
                    .allowsHitTesting(false)
            }
        }
        .rotation3DEffect(.degrees(Double(tilt.x) * lean), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
        .rotation3DEffect(.degrees(Double(-tilt.y) * lean), axis: (x: 1, y: 0, z: 0), perspective: 0.45)
        // Lifted off the table on its way to the press: a little larger, its shadow deeper and further away.
        .scaleEffect(lifted ? 1.03 : 1)
        // The shadow falls away from the light, and moves with it.
        .shadow(color: .black.opacity(lifted ? 0.26 : 0.2), radius: lifted ? 26 : 16,
                x: 8 - tilt.x * 10, y: (lifted ? 24 : 14) - tilt.y * 10)
        .shadow(color: .black.opacity(0.16), radius: 2, x: 1, y: 2)
    }

    /// One gesture for everything the finger does: touch-down starts the texture (and on the back, the lift), a
    /// drag tilts the card and plays the stock, crossing the perforation clicks, and a quick tap turns it over.
    private func handle(scale: CGFloat, stock: Stock) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if touchedAt == nil {
                    touchedAt = .now
                    lastY = value.startLocation.y / scale
                    texture.begin(on: stock)
                    if turned { hold(true) } else { waitForHold() }
                }
                let t = value.translation
                if (t.width * t.width + t.height * t.height).squareRoot() > 8 { cancelHold() }
                finger = CGPoint(x: max(-1, min(1, value.translation.width / 180)),
                                 y: max(-1, min(1, value.translation.height / 180)))
                let v = value.velocity
                texture.stroke(speed: (v.width * v.width + v.height * v.height).squareRoot())
                let y = value.location.y / scale
                if let lastY, Texture.crossesPerforation(from: lastY, to: y) { texture.perforation() }
                lastY = y
            }
            .onEnded { value in
                cancelHold()
                texture.end()
                hold(false)
                if lifted {
                    // The press has it; the finger lifting is not a tap.
                    touchedAt = nil
                    lastY = nil
                    finger = .zero
                    return
                }
                let t = value.translation
                let moved = (t.width * t.width + t.height * t.height).squareRoot()
                let quick = touchedAt.map { Date.now.timeIntervalSince($0) < 0.35 } ?? false
                touchedAt = nil
                lastY = nil
                withAnimation(reduceMotion ? Motion.plain : Motion.stamp) { finger = .zero }
                if moved < 8, quick { turned.toggle() }
            }
    }

    /// How long the line takes to run round the card: the hold that takes it to the press.
    static let hold = 0.55

    /// A finger held still on the front for a moment lifts the card and takes it to the press.
    private func waitForHold() {
        // Only a printed card goes to the press: not a blank one while its edition is being chosen, nor mid-run.
        guard takeToPress != nil, !choosing, printed == Plate.foil, editions.edition(for: stub.title) != nil else { return }
        holdTimer?.cancel()
        holdTimer = Task {
            // A beat before the line starts, so a tap never shows it.
            do { try await Task.sleep(for: .milliseconds(120)) } catch { return }
            withAnimation(.linear(duration: Self.hold)) { charging = true }
            do { try await Task.sleep(for: .seconds(Self.hold)) } catch { return }
            withAnimation(reduceMotion ? Motion.plain : Motion.stamp) { lifted = true }
            texture.end()
            do { try await Task.sleep(for: .milliseconds(reduceMotion ? 60 : 200)) } catch { return }
            takeToPress?()
        }
    }

    /// The finger moved or lifted before the line closed: it runs back.
    private func cancelHold() {
        holdTimer?.cancel()
        guard charging, !lifted else { return }
        withAnimation(.easeOut(duration: 0.2)) { charging = false }
    }

    private func hold(_ pressing: Bool) {
        guard pressing != holding else { return }
        withAnimation(reduceMotion ? Motion.plain : Motion.settle) { holding = pressing }
    }

    /// The press. A release printed before shows whole, unless this copy has just been kept; a release never seen
    /// is chosen first (the model, or the floor after its patience), then printed a plate at a time.
    private func press() async {
        // Decoded once, at the size the back draws it, and kept (PlateImage): never `UIImage(data:)` in a body.
        photo = PlateImage.image(for: stub.id, in: .detail, data: stub.imageData)
        let known = editions.edition(for: stub.title) != nil
        if known, !pressesOnAppear {
            printed = Plate.foil
            return
        }
        printed = 0
        if !known { withAnimation(Motion.place) { choosing = true } }
        let edition = await editions.decide(title: stub.title, year: copy.year, screen: copy.screen)
        withAnimation(Motion.place) { choosing = false }
        let metallic = edition.stock == .foil || edition.stock == .holographic
        if reduceMotion {
            printed = Plate.foil
            pass = Plate.foil
            return
        }
        do {
            try await Task.sleep(for: .milliseconds(350))
            for p in 1...Plate.foil {
                if p == Plate.foil, !metallic { break }
                withAnimation(p == Plate.foil ? Motion.stamp : Motion.settle) { printed = p }
                pass = p
                try await Task.sleep(for: .milliseconds(p == Plate.type.rawValue ? 520 : 420))
            }
        } catch {
            // Left mid-run: whatever is left of the card is printed at once.
        }
        printed = Plate.foil
    }

    private func spoken(_ edition: Edition?) -> String {
        guard let edition else { return "A blank card. The edition for \(stub.title) is being chosen." }
        if turned {
            let pencil = Pencil(edition: edition).map { " " + $0.spoken(signed: Signatures.shared.isSigned) } ?? ""
            return "The stub for \(stub.title) as it was scanned, on the back of its edition.\(pencil)"
        }
        let composition = memo.composition(edition, copy)
        let punched = Remarque.spoken(composition.punches).map { ", \($0)" } ?? ""
        return "The \(composition.edition.kind) of \(stub.title): \(composition.edition.colophon) \(copy.viewingWords)\(punched)."
    }
}

/// Two faces of one card, turned about its long axis. Animatable on the angle, so the face that shows is the one
/// facing the viewer at every frame of the turn, not only at its ends. Under Reduce Motion (`flat`) the faces
/// cross-fade and nothing turns.
struct Turnover<Front: View, Back: View>: View, @MainActor Animatable {
    var angle: Double
    var flat: Bool
    let front: Front
    let back: Back

    init(angle: Double, flat: Bool, @ViewBuilder front: () -> Front, @ViewBuilder back: () -> Back) {
        self.angle = angle
        self.flat = flat
        self.front = front()
        self.back = back()
    }

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    var body: some View {
        let showsBack = angle > 90
        ZStack {
            front.opacity(flat ? 1 - angle / 180 : (showsBack ? 0 : 1))
            // Drawn mirrored, so that turned through half a circle it reads the right way round.
            back.scaleEffect(x: flat ? 1 : -1, y: 1).opacity(flat ? angle / 180 : (showsBack ? 1 : 0))
        }
        .rotation3DEffect(.degrees(flat ? 0 : angle), axis: (x: 0, y: 1, z: 0), perspective: 0.35)
    }
}

/// The keepsake's card as the source of the press room's zoom, when there is a press room.
private struct PressSource: ViewModifier {
    let namespace: Namespace.ID?

    func body(content: Content) -> some View {
        if let namespace {
            content.matchedTransitionSource(id: "press", in: namespace)
        } else {
            content
        }
    }
}

/// The last composition drawn, kept, so a card tilting at sixty frames a second is not re-set sixty times.
@MainActor
final class CompositionMemo {
    private var last: Composition?

    func composition(_ edition: Edition, _ copy: Copy) -> Composition {
        if let last, last.edition == edition, last.copy == copy { return last }
        let composition = Composition(edition: edition, copy: copy)
        last = composition
        return composition
    }
}

/// What a card does under a finger, as small marks and words under it: two at most, the gesture's symbol and what it does.
struct GestureLegend: View {
    let items: [(symbol: String, words: String)]

    var body: some View {
        // Side by side where they fit, one above the other where the type is large: never shrunk to fit (decision 005).
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 18) { lines }
            VStack(alignment: .leading, spacing: 8) { lines }
        }
        .accessibilityElement(children: .combine)
    }

    private var lines: some View {
        ForEach(items, id: \.words) { item in
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                // The symbol in the words' own face, so it grows with them.
                Image(systemName: item.symbol).font(Type.words(13))
                Text(item.words).font(Type.words(13)).fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(Ink.soft(0.7))
        }
    }
}

/// The card's edge alone, one stroke from the top left round to where it started: the rounded corners and the two notches at
/// the perforation, none of the holes. What the hold traces.
struct TicketOutline: Shape {
    func path(in rect: CGRect) -> Path {
        let s = rect.width / Card.width
        let r = Card.corner * s, notch: CGFloat = 8 * s
        let y = rect.minY + Card.poster * rect.height / Card.height
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        p.addArc(center: CGPoint(x: rect.maxX - r, y: rect.minY + r), radius: r, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: rect.maxX, y: y - notch))
        p.addArc(center: CGPoint(x: rect.maxX, y: y), radius: notch, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: true)
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addArc(center: CGPoint(x: rect.maxX - r, y: rect.maxY - r), radius: r, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        p.addArc(center: CGPoint(x: rect.minX + r, y: rect.maxY - r), radius: r, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        p.addLine(to: CGPoint(x: rect.minX, y: y + notch))
        p.addArc(center: CGPoint(x: rect.minX, y: y), radius: notch, startAngle: .degrees(90), endAngle: .degrees(-90), clockwise: true)
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        p.addArc(center: CGPoint(x: rect.minX + r, y: rect.minY + r), radius: r, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        return p
    }
}

/// What a punch looks like from above (ADR-032): a hole with the card's own shadow falling into it from the side the light
/// comes from, and the cut edge of the stock catching the light on the other side, so it reads as cut through rather than
/// printed on. The shadow moves as the card tilts.
struct PunchWalls: View {
    let punches: [Punch]
    let mirrored: Bool
    var tilt: CGPoint = .zero

    var body: some View {
        Canvas { context, _ in
            for punch in punches {
                let hole = punch.path(scale: 1, origin: .zero, mirrored: mirrored)
                var inside = context
                inside.clip(to: hole)
                // The rim's shadow on whatever is under the card, toward the far side from the light.
                var shade = inside
                shade.addFilter(.blur(radius: 1.4))
                shade.stroke(hole.offsetBy(dx: 2.2 - tilt.x * 1.5, dy: 2.8 - tilt.y * 1.5), with: .color(.black.opacity(0.42)), lineWidth: 4.5)
                // The cut wall where the light reaches it: a hairline of bare fibre.
                inside.stroke(hole.offsetBy(dx: -1.1, dy: -1.3), with: .color(Color(hex: 0xF4EEDF).opacity(0.55)), lineWidth: 1)
            }
        }
        .frame(width: Card.width, height: Card.height)
    }
}
