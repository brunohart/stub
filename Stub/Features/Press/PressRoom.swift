import SwiftUI

/// The press room (ADR-016, DESIGN.md › The press). Where the person who kept a stub pulls their own proof of its
/// edition: the card on the bed, lit by the phone; the bench below it; one italic sentence between them. Touch a part
/// and everything else knocks back to a ghost; turn the wheel and that part redraws through its in-betweens while the
/// rest of the poster stands still. You choose between drawings. You never move a mark.
///
/// The room is the app's chrome, not an edition: parchment, `Ink`, the three faces.
struct PressRoom: View {
    let stub: Stub
    @State private var session: PressSession
    @State private var attitude = Attitude()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var rotor
    /// Where the separation stood when the pinch began.
    @State private var pinchedFrom: CGFloat?
    /// Counts the times the sheets were pressed back together: one heavy impact each, the press closing.
    @State private var closings = 0
    /// The fan's card on its way to the bed.
    @State private var flying: Movement?
    @Namespace private var fan
    @Environment(\.undoManager) private var undoManager
    /// When the last proof was pulled: the ink dries from then, and the timeline stops when it is dry.
    @State private var wetSince: Date?
    /// The stub as it was scanned, and its code: the back of the card.
    @State private var photo: UIImage?
    @State private var code: CGImage?
    private let signatures = Signatures.shared

    init(stub: Stub, copy: Copy) {
        self.stub = stub
        _session = State(initialValue: PressSession(title: stub.title, copy: copy))
    }

    var body: some View {
        ZStack {
            Paper()
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 4) {
                    bed
                    // The lever runs down the right of the bed.
                    Lever { pull() }
                        .padding(.top, 28)
                        .opacity(session.turned ? 0.3 : 1)
                        .disabled(session.turned)
                }
                .frame(maxHeight: .infinity)
                .padding(.leading, 20)
                .padding(.trailing, 6)
                .padding(.top, 4)

                // The status line: the only italic on the screen.
                Text(session.sentence(at: session.position))
                    .font(Type.italic(18))
                    .foregroundStyle(Ink.navy)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .padding(.horizontal, 28)
                    .contentTransition(.opacity)
                    .animation(Motion.place, value: session.focus?.id)
                    .accessibilityAddTraits(.updatesFrequently)

                bench
                    .frame(height: session.bench == .rest || session.focus != nil ? 214 : 262)
                    .animation(reduceMotion ? Motion.plain : Motion.settle, value: session.bench)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .sensoryFeedback(.impact(weight: .heavy, intensity: 1), trigger: closings)
        // A light tap for each plate of a reprint, a heavy one for the foil: the press, felt.
        .sensoryFeedback(trigger: session.printed) { old, new in
            new == Plate.foil && old < Plate.foil ? .impact(weight: .heavy, intensity: 0.8)
                : new > old && new > 0 ? .impact(weight: .light, intensity: 0.6) : nil
        }
        .onAppear {
            if !reduceMotion { attitude.start() }
            session.undoManager = undoManager
            photo = PlateImage.image(for: stub.id, in: .detail, data: stub.imageData)
            code = Aztec.mask(for: session.copy.message)
        }
        .onDisappear { attitude.stop() }
        .onChange(of: undoManager) { _, now in session.undoManager = now }
        // A pull: the ink is wet from now, and dries.
        .onChange(of: session.pulls) {
            guard !reduceMotion else { return }
            let since = Date.now
            wetSince = since
            Task {
                try? await Task.sleep(for: .seconds(Self.drying + 0.2))
                if wetSince == since { wetSince = nil }
            }
        }
        #if DEBUG
        .task { await DebugDrive.shared.press(session, reduceMotion: reduceMotion) }
        .onChange(of: session.letGo) { _, movement in
            guard let movement else { return }
            session.letGo = nil
            take(movement)
        }
        #endif
    }

    // MARK: The bed

    private var light: Light {
        #if DEBUG
        if let held = DebugDrive.shared.tilt { return Light(tilt: held) }
        #endif
        return Light(tilt: attitude.tilt)
    }

    /// The card lies flat at the largest size that fits. It does not lean in here; the light still moves with the
    /// phone. The bed is where you point.
    private var bed: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / Card.width, proxy.size.height / Card.height)
            let size = CGSize(width: Card.width * scale, height: Card.height * scale)
            let tilt = light.tilt
            Group {
                if reduceMotion, session.separation > 0 {
                    FlatSheets(session: session, light: light, height: size.height)
                } else {
                    // The timeline runs only while the ink is wet; at rest nothing moves on its own.
                    TimelineView(.animation(paused: wetSince == nil)) { timeline in
                        let wet = wetness(at: timeline.date)
                        // The platen: the card pressed a breath smaller, and the impression rising into the stock.
                        KeyframeAnimator(initialValue: Platen(), trigger: session.pulls) { platen in
                            Turnover(angle: session.turned ? 180 : 0, flat: reduceMotion) {
                                ZStack(alignment: .topLeading) {
                                    OnTheBed(session: session, position: session.position, separation: session.separation,
                                             light: light, reduceMotion: reduceMotion, impression: platen.impression, wet: wet)
                                    if let flood = session.flood {
                                        Flooding(session: session, flood: flood, progress: flood.progress, light: light,
                                                 reduceMotion: reduceMotion)
                                    }
                                }
                            } back: {
                                EditionBack(composition: session.composition, photo: photo, tilt: stub.tilt, code: code,
                                            light: light, pencil: Pencil(edition: session.edition), signature: signatures.image)
                            }
                            .frame(width: Card.width, height: Card.height)
                            .scaleEffect(platen.scale)
                        } keyframes: { _ in
                            KeyframeTrack(\.scale) {
                                CubicKeyframe(0.985, duration: 0.07)
                                SpringKeyframe(1, duration: 0.45, spring: Spring(response: 0.3, dampingRatio: 0.55))
                            }
                            KeyframeTrack(\.impression) {
                                MoveKeyframe(0)
                                LinearKeyframe(0, duration: 0.06)
                                CubicKeyframe(1, duration: 0.6)
                            }
                        }
                    }
                    .scaleEffect(scale, anchor: .topLeading)
                    .frame(width: size.width, height: size.height, alignment: .topLeading)
                    .shadow(color: .black.opacity(0.18 * (1 - session.separation)), radius: 14, x: 6 - tilt.x * 8, y: 12 - tilt.y * 8)
                    .shadow(color: .black.opacity(0.14), radius: 2, x: 1, y: 2)
                    .contentShape(Rectangle())
                    .gesture(SpatialTapGesture().onEnded { value in
                        let point = CGPoint(x: value.location.x / scale, y: value.location.y / scale)
                        withAnimation(reduceMotion ? Motion.plain : Motion.settle) { session.touch(at: point) }
                    })
                    // A draw-down dropped on the card floods it from where it landed.
                    .dropDestination(for: String.self) { items, location in
                        guard let palette = items.first.flatMap(Palette.init(rawValue:)) else { return false }
                        flood(palette, from: CGPoint(x: location.x / scale, y: location.y / scale))
                        return true
                    }
                    // The fan's card, flying to the bed.
                    .overlay(alignment: .topLeading) {
                        if let flying {
                            CardThumb(composition: session.composition(session.edition(in: flying)), light: light)
                                .matchedGeometryEffect(id: flying, in: fan, isSource: false)
                                .frame(width: size.width, height: size.height)
                        }
                    }
                    // The margin on the back: sign it once, and hold the signature to sign again.
                    .overlay(alignment: .topLeading) { margin(scale: scale) }
                }
            }
            .simultaneousGesture(pinch)
            .overlay(alignment: .topLeading) { parts(scale: scale) }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(session.turned
                ? "The back of the card: the stub as it was scanned. " + (Pencil(edition: session.edition)?.spoken(signed: signatures.isSigned) ?? "")
                : "The card on the press: \(session.edition.colophon)")
            .accessibilityRotor("Parts") {
                ForEach(session.turnable) { part in
                    AccessibilityRotorEntry(Text(session.spoken(part)), id: part.id, in: rotor)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// How wet the ink still is, `drying` seconds after a pull: 1 at the pull, then falling away exponentially.
    private func wetness(at date: Date) -> Double {
        #if DEBUG
        if let held = session.heldWet { return held }
        #endif
        guard !reduceMotion, let wetSince else { return 0 }
        let t = date.timeIntervalSince(wetSince)
        return t < 0 ? 1 : max(0, exp(-t / (Self.drying / 4)) - 0.018)
    }

    /// How long wet ink takes to dry, in seconds.
    static let drying = 2.4

    /// The margin on the back of the card: a pad to sign in until there is a signature, then the signature, held to redo.
    @ViewBuilder
    private func margin(scale: CGFloat) -> some View {
        if session.turned {
            let r = EditionBack.signatureMargin
            Group {
                if signatures.isSigned {
                    Color.clear
                        .contentShape(Rectangle())
                        .onLongPressGesture { withAnimation(Motion.settle) { signatures.redo() } }
                        .accessibilityElement()
                        .accessibilityLabel("Your signature")
                        .accessibilityAction(named: "Sign again") { signatures.redo() }
                } else {
                    SignaturePad(scale: scale) { drawing in withAnimation(Motion.place) { signatures.keep(drawing) } }
                }
            }
            .frame(width: r.width * scale, height: r.height * scale)
            .offset(x: r.minX * scale, y: r.minY * scale)
            .transition(.opacity.animation(Motion.settle.delay(0.35)))
        }
    }

    /// The lever has given: the proof on the press is pulled.
    private func pull() {
        if session.separation > 0 { separate(false) }
        withAnimation(reduceMotion ? Motion.plain : Motion.settle) {
            session.putDown()
            session.bench = .rest
        }
        session.pull()
    }

    /// The card over on the bed, to its back and the margin an owner signs, or back to its front.
    private func turn() {
        if session.separation > 0 { separate(false) }
        withAnimation(reduceMotion ? Motion.plain : Motion.settle) {
            session.putDown()
            session.bench = .rest
            session.turned.toggle()
        }
    }

    /// One VoiceOver element over each part the press can turn, where it lies on the card, so the rotor can reach it.
    private func parts(scale: CGFloat) -> some View {
        ForEach(session.turnable) { part in
            if let r = session.composition.bounds(of: part.id) {
                Color.clear
                    .frame(width: r.width * scale, height: r.height * scale)
                    .offset(x: r.minX * scale, y: r.minY * scale)
                    .accessibilityElement()
                    .accessibilityLabel(session.spoken(part))
                    .accessibilityHint("Picks it up, so the wheel turns it.")
                    .accessibilityAddTraits(session.focus?.id == part.id ? [.isButton, .isSelected] : .isButton)
                    .accessibilityAction { session.pickUp(part) }
                    .accessibilityRotorEntry(id: part.id, in: rotor)
            }
        }
    }

    /// Pinch outward and the card comes apart into its sheets; pinch in and they press back together.
    private var pinch: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let from = pinchedFrom ?? session.separation
                pinchedFrom = from
                var still = Transaction()
                still.disablesAnimations = true
                withTransaction(still) { session.separation = min(max(from + (value.magnification - 1) * 1.25, 0), 1) }
            }
            .onEnded { value in
                pinchedFrom = nil
                let apart = value.velocity > 0.5 || (value.velocity > -0.5 && session.separation > 0.5)
                separate(apart)
            }
    }

    private func benchButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Type.words(15))
                .foregroundStyle(Ink.ink)
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .overlay(Capsule().stroke(Ink.ink.opacity(0.25), lineWidth: 0.75))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    /// New inks spreading across the card from `origin`, about half a second to its far corner (a fifth of a second's
    /// cross-fade under Reduce Motion); when they have covered it, they are the card's.
    private func flood(_ palette: Palette, from origin: CGPoint) {
        guard palette != session.edition.palette, session.flood == nil else { return }
        if session.separation > 0 { separate(false) }
        session.flood = PressSession.Flood(palette: palette, origin: origin)
        withAnimation(reduceMotion ? .linear(duration: 0.2) : .easeOut(duration: 0.55)) {
            session.flood?.progress = 1
        } completion: {
            session.choose(palette)
            session.flood = nil
        }
    }

    /// The fan's card flies to the bed, lands, and the bed prints it, a pass at a time.
    private func take(_ movement: Movement) {
        guard movement != session.edition.movement else {
            withAnimation(Motion.settle) { session.bench = .rest }
            return
        }
        if reduceMotion {
            session.choose(movement)
            session.bench = .rest
            Task { await session.reprint(reduceMotion: true) }
            return
        }
        withAnimation(Motion.place) {
            session.bench = .rest
            flying = movement
        }
        Task {
            try? await Task.sleep(for: .milliseconds(480))
            var still = Transaction()
            still.disablesAnimations = true
            withTransaction(still) {
                session.choose(movement)
                flying = nil
            }
            await session.reprint(reduceMotion: false)
        }
    }

    /// A new stock: the card is printed again on it.
    private func printAgain(on stock: Stock) {
        guard stock != session.edition.stock else { return }
        session.choose(stock)
        Task { await session.reprint(reduceMotion: reduceMotion) }
    }

    /// Spread the sheets, or press them back together with one heavy impact.
    private func separate(_ apart: Bool) {
        let wasApart = session.separation > 0
        withAnimation(reduceMotion ? Motion.plain : Motion.settle) { session.separation = apart ? 1 : 0 }
        if !apart, wasApart { closings += 1 }
    }

    // MARK: The bench

    /// What you are holding decides the bench: the wheel for a part, the edition's three choices at rest.
    @ViewBuilder
    private var bench: some View {
        if let focus = session.focus {
            Wheel(position: $session.position, stock: session.edition.stock) { take in session.settle(on: take) }
                .id(focus.id)
                .transition(Self.benchChange)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 18) {
                // The genome's three choices are the front's; on the back there is only the margin.
                if !session.turned {
                    HStack(alignment: .top, spacing: 30) {
                        choice(.movement, "Movement", session.edition.movement.rawValue.capitalized)
                        choice(.inks, "Inks", session.edition.palette.rawValue.capitalized)
                        choice(.stock, "Stock", session.edition.stock.words)
                    }
                }
                switch session.bench {
                case .movement:
                    Fan(session: session, light: light, namespace: fan) { take($0) }
                        .frame(height: 176)
                        .transition(Self.benchChange)
                case .inks:
                    DrawDowns(session: session) { palette in flood(palette, from: CGPoint(x: Card.width / 2, y: Card.height / 2)) }
                        .frame(height: 130)
                        .transition(Self.benchChange)
                case .stock:
                    SwatchBook(session: session, light: light) { printAgain(on: $0) }
                        .frame(height: 130)
                        .transition(Self.benchChange)
                case .rest:
                    HStack(spacing: 12) {
                        // Separations are a pinch on the card, and a button for anyone who does not pinch.
                        if !session.turned {
                            benchButton(session.separation > 0 ? "Press them together" : "See the plates") {
                                separate(session.separation == 0)
                            }
                        }
                        benchButton(session.turned ? "Turn it back" : "Turn it over") { turn() }
                    }
                    .padding(.top, 12)
                    .transition(Self.benchChange)
                }
            }
            // The three words stay where they are whatever is open, so opening and closing moves nothing but the object.
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 22)
            .transition(Self.benchChange)
        }
    }

    /// The bench changes hands: what was on it leaves quickly, then what replaces it arrives, so the words and the
    /// wheel are never on the bench at once.
    private static let benchChange: AnyTransition = .asymmetric(
        insertion: .opacity.animation(Motion.settle.delay(0.1)),
        removal: .opacity.animation(.easeOut(duration: 0.1))
    )
}

/// The platen's two motions after a pull: the card pressed a breath smaller, and the impression's depth rising from
/// nothing to the stock's own.
private struct Platen {
    var scale: CGFloat = 1
    var impression: Double = 1
}

/// The card on the bed at a wheel position and a separation. Animatable on both, so the spring that settles the wheel
/// carries the card through the in-betweens, and the one that spreads the sheets lifts them apart.
private struct OnTheBed: View, @MainActor Animatable {
    let session: PressSession
    var position: Double
    var separation: CGFloat
    let light: Light
    let reduceMotion: Bool
    var impression: Double = 1
    var wet: Double = 0

    var animatableData: AnimatablePair<Double, CGFloat> {
        get { AnimatablePair(position, separation) }
        set { position = newValue.first; separation = newValue.second }
    }

    var body: some View {
        EditionFace(composition: session.drawing(at: position, reduceMotion: reduceMotion), light: light,
                    printed: session.printed, focus: session.focus?.id, separation: separation, impression: impression, wet: wet)
            .accessibilityHidden(true)
    }
}

/// Separations under Reduce Motion: the sheets laid side by side in a flat row, each touched on its own.
private struct FlatSheets: View {
    let session: PressSession
    let light: Light
    let height: CGFloat

    var body: some View {
        let composition = session.drawing(at: session.position, reduceMotion: true)
        let scale = height * 0.5 / Card.height
        let face = EditionFace(composition: composition, light: light, focus: session.focus?.id)
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(Separation.layers(metallic: composition.isMetallic), id: \.self) { layer in
                    VStack(spacing: 8) {
                        face.sheet(layer)
                            .scaleEffect(scale, anchor: .topLeading)
                            .frame(width: Card.width * scale, height: Card.height * scale, alignment: .topLeading)
                            .contentShape(Rectangle())
                            .gesture(SpatialTapGesture().onEnded { value in
                                session.touch(at: CGPoint(x: value.location.x / scale, y: value.location.y / scale), on: layer)
                            })
                        Text(PressSession.capitalised(layer.name)).font(Type.words(12)).foregroundStyle(Ink.grey)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(PressSession.capitalised(layer.name))
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(height: height)
    }
}

extension PressRoom {
    /// One of the edition's three choices on the bench: what it is now, and the word for it. Tapped, it opens its
    /// object; tapped again, it closes.
    fileprivate func choice(_ bench: PressSession.Bench, _ label: String, _ value: String) -> some View {
        let open = session.bench == bench
        let other = session.bench != .rest && !open
        return Button {
            if session.separation > 0 { separate(false) }
            withAnimation(reduceMotion ? Motion.plain : Motion.settle) {
                session.putDown()
                session.bench = open ? .rest : bench
            }
        } label: {
            VStack(spacing: 4) {
                Text(value).font(Type.words(17)).foregroundStyle(other ? Ink.grey : Ink.ink)
                Text(label).font(Type.words(12)).foregroundStyle(Ink.grey)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label), \(value)")
        .accessibilityHint(open ? "Closes it." : "Opens the choices.")
        .accessibilityAddTraits(open ? .isSelected : [])
    }
}

/// The card in new inks, revealed where the flood has reached: the stock's own noise pushes the edge in and out.
private struct Flooding: View, @MainActor Animatable {
    let session: PressSession
    let flood: PressSession.Flood
    var progress: CGFloat
    let light: Light
    let reduceMotion: Bool

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        let edition = session.edition(in: flood.palette)
        let face = EditionFace(composition: session.composition(edition), light: light)
        if reduceMotion {
            face.opacity(progress)
        } else {
            face.modifier(FloodEffect(origin: flood.origin, progress: progress, stock: edition.stock,
                                      seed: Double(edition.seed % 101)))
        }
    }
}

extension Stock {
    /// The stock in a word or two, as the bench names it.
    var words: String {
        switch self {
        case .cotton: "Cotton"
        case .coated: "Coated card"
        case .foil: "Foil"
        case .holographic: "Holographic"
        }
    }
}
