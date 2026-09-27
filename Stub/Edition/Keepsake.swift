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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(stub: Stub, copy: Copy, turned: Binding<Bool>, pressesOnAppear: Bool = false) {
        self.stub = stub
        self.copy = copy
        _turned = turned
        self.pressesOnAppear = pressesOnAppear
        _printed = State(initialValue: pressesOnAppear ? 0 : Plate.foil)
    }

    var body: some View {
        let edition = editions.edition(for: stub.title)
        VStack(alignment: .leading, spacing: 14) {
            GeometryReader { proxy in
                let scale = proxy.size.width / Card.width
                card(edition)
                    .scaleEffect(scale, anchor: .topLeading)
                    .frame(width: proxy.size.width, height: Card.height * scale, alignment: .topLeading)
                    .contentShape(Rectangle())
                    // Alongside the scroll, never instead of it: a drag that starts on the card still scrolls the page,
                    // and the card leans with it and settles when the finger lifts.
                    .simultaneousGesture(handle(scale: scale, stock: edition?.stock ?? .coated))
            }
            .aspectRatio(Card.width / Card.height, contentMode: .fit)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(spoken(edition))
            .accessibilityHint(turned ? "Turns it back to the edition." : "Turns it over to the stub as it was scanned.")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { turned.toggle() }
            .accessibilityAction(named: "Lift the print") { hold(!holding) }

            // The one italic sentence under the card: what the press is doing, or what the card will do.
            HStack(spacing: 10) {
                if choosing { ProgressView().tint(Ink.orange) }
                Text(choosing ? "Choosing an edition for \(stub.title)…"
                     : turned ? "Hold it to lift the print." : "Turn it over for the one you were handed.")
                    .font(Type.italic(16)).foregroundStyle(Ink.navy)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)
                    .animation(Motion.place, value: turned)
            }
            .accessibilityHidden(!choosing)
        }
        .task(id: stub.id) { await press() }
        .task(id: copy.message) { code = Aztec.mask(for: copy.message) }
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
        #if DEBUG
        .onChange(of: DebugDrive.shared.holding) { _, held in if turned { hold(held) } }
        #endif
    }

    /// The finger, the gyroscope and (in Debug) the driver, as one tilt.
    private var tilt: CGPoint {
        #if DEBUG
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
                                silkscreen: holding ? 0 : 1)
                }
                // The card's edge: a sliver of darker stock showing on the side away from the light.
                .background(
                    TicketShape()
                        .fill(Color(hex: EditionInks.mix(composition.inks.hex(composition.stripField), 0x000000, 0.35)))
                        .offset(x: 1.2 - tilt.x * 1.2, y: 1.8 - tilt.y * 1.2)
                )
            } else {
                // Bare card while the edition is being chosen.
                TicketShape()
                    .fill(Ink.cream)
                    .overlay(Grain(opacity: 0.08).clipShape(TicketShape()))
            }
        }
        .frame(width: Card.width, height: Card.height)
        .rotation3DEffect(.degrees(Double(tilt.x) * lean), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
        .rotation3DEffect(.degrees(Double(-tilt.y) * lean), axis: (x: 1, y: 0, z: 0), perspective: 0.45)
        // The shadow falls away from the light, and moves with it.
        .shadow(color: .black.opacity(0.2), radius: 16, x: 8 - tilt.x * 10, y: 14 - tilt.y * 10)
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
                    if turned { hold(true) }
                }
                finger = CGPoint(x: max(-1, min(1, value.translation.width / 180)),
                                 y: max(-1, min(1, value.translation.height / 180)))
                let v = value.velocity
                texture.stroke(speed: (v.width * v.width + v.height * v.height).squareRoot())
                let y = value.location.y / scale
                if let lastY, Texture.crossesPerforation(from: lastY, to: y) { texture.perforation() }
                lastY = y
            }
            .onEnded { value in
                texture.end()
                hold(false)
                let t = value.translation
                let moved = (t.width * t.width + t.height * t.height).squareRoot()
                let quick = touchedAt.map { Date.now.timeIntervalSince($0) < 0.35 } ?? false
                touchedAt = nil
                lastY = nil
                withAnimation(reduceMotion ? Motion.plain : Motion.stamp) { finger = .zero }
                if moved < 8, quick { turned.toggle() }
            }
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
        if turned { return "The stub for \(stub.title) as it was scanned, on the back of its edition." }
        return "The edition of \(stub.title): \(edition.described). \(copy.viewingWords)."
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
