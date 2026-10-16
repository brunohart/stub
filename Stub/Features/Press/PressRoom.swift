import SwiftUI

/// The press room (ADR-016, DESIGN.md › The press). Where the person who kept a stub pulls their own proof of its
/// edition: the card on the bed, lit by the phone; the bench below it; one line of words between them. Touch a part
/// and everything else knocks back to a ghost; turn the wheel and that part redraws through its in-betweens while the
/// rest of the poster stands still. You choose between drawings. You never move a mark.
///
/// The room is the app's chrome, not an edition: parchment, `Ink`, the three faces.
struct PressRoom: View {
    let stub: Stub
    @State private var session: PressSession
    @State private var attitude = Attitude()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    /// A stroke being drawn across the card with the screens out: where it began and where the finger is, in card points.
    @State private var stroke: (from: CGPoint, to: CGPoint)?
    @Namespace private var rotor
    /// Where the separation stood when the pinch began.
    @State private var pinchedFrom: CGFloat?
    /// Counts the times the sheets were pressed back together: one heavy impact each, the press closing.
    @State private var closings = 0
    /// The fan's card on its way to the bed.
    @State private var flying: Movement?
    /// The flying card's turn, from its place in the hand to square on the bed.
    @State private var flightTurn: Double = 0
    /// How much of the flying card is still printed: it leaves the fan whole and lands as the bare sheet the bed prints.
    @State private var flightPrinted = Plate.foil
    /// The flying card has let go of its place in the fan. Matched to the fan card, it would follow that card while the
    /// fan fades out rather than fly, so on take-off it is matched in `air`, where nothing is, and flies to its own frame,
    /// the bed's. The same id in another namespace: an id wrapped differently would not have matched the fan card at all.
    @State private var inFlight = false
    @Namespace private var fan
    /// Where the flying card is matched once it has taken off: nothing is a source here, so it flies to its own frame.
    @Namespace private var air
    @Environment(\.undoManager) private var undoManager
    /// When the last proof was pulled: the ink dries from then, and the timeline stops when it is dry.
    @State private var wetSince: Date?
    /// The stub as it was scanned, and its code: the back of the card.
    @State private var photo: UIImage?
    @State private var code: CGImage?
    /// Leaving with a proof on the press that is not kept: asked once (ADR-030).
    @State private var leaving = false
    @Environment(\.dismiss) private var dismiss
    private let signatures = Signatures.shared

    init(stub: Stub, copy: Copy) {
        self.stub = stub
        _session = State(initialValue: PressSession(title: stub.title, copy: copy))
    }

    var body: some View {
        ZStack {
            Paper()
            // At the accessibility sizes the room scrolls, the card at a height of its own, rather than squeezing the card
            // to a stamp or cutting a word (decision 005).
            if typeSize.isAccessibilitySize {
                ScrollView { room(scrolls: true) }
            } else {
                room(scrolls: false)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { topActs }
        // With a tool out, a stroke across the card is the tool's, never a swipe that closes the room.
        .interactiveDismissDisabled(session.bench == .pull || session.bench == .stamp)
        .toolbarBackground(.hidden, for: .navigationBar)
        // Back asks once when the proof on the press is not kept: it would stay on the press, not on the card.
        .modifier(LeaveCheck(asking: $leaving, back: leave, keep: {
            pull()
            Task {
                try? await Task.sleep(for: .milliseconds(reduceMotion ? 100 : 700))
                dismiss()
            }
        }, leave: { dismiss() }))
        .sensoryFeedback(.impact(weight: .heavy, intensity: 1), trigger: closings)
        // A light tap for each plate of a reprint, a heavy one for the foil: the press, felt.
        .sensoryFeedback(trigger: session.printed) { old, new in
            new == Plate.foil && old < Plate.foil ? .impact(weight: .heavy, intensity: 0.8)
                : new > old && new > 0 ? .impact(weight: .light, intensity: 0.6) : nil
        }
        .onAppear {
            Posters.shared.want(title: stub.title, year: session.copy.year)
            if !reduceMotion { attitude.start() }
            session.undoManager = undoManager
            photo = PlateImage.image(for: stub.id, in: .detail, data: stub.imageData)
        }
        .task(id: session.copy.message) { code = await Aztec.made(for: session.copy.message) }
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
        #if DEBUG || PERF
        .task { await DebugDrive.shared.press(session, reduceMotion: reduceMotion) }
        .onChange(of: session.letGo) { _, movement in
            guard let movement else { return }
            session.letGo = nil
            take(movement)
        }
        #endif
    }

    /// The press: the line that says whether it is kept, the bed and its lever, the status line and the bench.
    private func room(scrolls: Bool) -> some View {
        VStack(spacing: 0) {
            // Whether what is on the press is kept: pulling is the only way it becomes the card (ADR-030).
            KeepLine(unkept: session.somethingToPull && !session.turned, justPulled: session.justPulled)
                .padding(.horizontal, 20)
                .padding(.bottom, 6)
            HStack(alignment: .top, spacing: 4) {
                bed
                // The lever runs down the right of the bed.
                Lever(ready: session.somethingToPull) { pull() }
                    .padding(.top, 28)
                    .opacity(session.turned ? 0.3 : 1)
                    .disabled(session.turned)
            }
            .frame(maxHeight: scrolls ? nil : .infinity)
            .frame(height: scrolls ? 440 : nil)
            .padding(.leading, 20)
            .padding(.trailing, 6)
            .padding(.top, 4)

            // The status line: what is in hand and which take, or what to do next. Words, and the take in the mono:
            // an instruction is not the app's voice, so it is not the italic (ADR-022).
            status
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 44)
                // Clear of the lever's words, which hang below the bed on the right; centred all the same.
                .padding(.horizontal, scrolls ? 28 : 62)

            bench
                .animation(reduceMotion ? Motion.plain : Motion.settle, value: session.bench)
        }
    }

    /// What the press is doing, or what to do next, in words (ADR-022).
    private var status: some View {
        // The words change the moment the press does, never cross-fading under the plates' spring.
        Text(session.sentence(at: session.position))
            .font(Type.words(16))
            .foregroundStyle(Ink.soft(0.75))
            .contentTransition(.identity)
            .transaction { $0.animation = nil }
            .modifier(Spoken(sentence: session.sentence(at: session.position)))
    }

    /// The status line as VoiceOver hears it: the session's whole sentence, which changes as the dial turns.
    private struct Spoken: ViewModifier {
        let sentence: String
        func body(content: Content) -> some View {
            content
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(sentence)
                .accessibilityAddTraits(.updatesFrequently)
        }
    }

    // MARK: The bed

    private var light: Light {
        #if DEBUG || PERF
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
                                        .environment(\.stubPhoto, photo)
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
                    // The studio (ADR-046): with the stamps out, a tap stamps; with the screens out, a stroke overprints.
                    .gesture(SpatialTapGesture().onEnded { value in
                        let point = CGPoint(x: value.location.x / scale, y: value.location.y / scale)
                        switch session.bench {
                        case .stamp:
                            withAnimation(reduceMotion ? Motion.plain : Motion.place) { session.stamp(at: point) }
                        case .pull:
                            // A tap is a pass straight across the card where the finger came down, a little rising, as a
                            // squeegee is drawn: the overprint for anyone who taps rather than drags.
                            withAnimation(reduceMotion ? Motion.plain : Motion.place) {
                                session.pull(from: CGPoint(x: 22, y: point.y + 18), to: CGPoint(x: Card.width - 22, y: point.y - 18))
                            }
                        default: return
                        }
                        wetSince = .now
                    })
                    // With the screens out the stroke is the tool's, ahead of every other gesture on the screen; otherwise
                    // the card's own gestures (the pinch to part the plates) have it.
                    .highPriorityGesture(DragGesture(minimumDistance: 6).onChanged { value in
                        stroke = (CGPoint(x: value.startLocation.x / scale, y: value.startLocation.y / scale),
                                  CGPoint(x: value.location.x / scale, y: value.location.y / scale))
                    }.onEnded { value in
                        stroke = nil
                        // From where the finger came down to where it lifted, however quickly it went.
                        let from = CGPoint(x: value.startLocation.x / scale, y: value.startLocation.y / scale)
                        let to = CGPoint(x: value.location.x / scale, y: value.location.y / scale)
                        withAnimation(reduceMotion ? Motion.plain : Motion.place) { session.pull(from: from, to: to) }
                        wetSince = .now
                    }, including: session.bench == .pull ? .all : .subviews)
                    .overlay(alignment: .topLeading) {
                        if let stroke {
                            StrokePreview(composition: session.composition,
                                          act: .pull(session.screen, in: session.inking, from: stroke.from, to: stroke.to))
                                .frame(width: Card.width, height: Card.height)
                                .scaleEffect(scale, anchor: .topLeading)
                                .frame(width: size.width, height: size.height, alignment: .topLeading)
                        }
                    }
                    // A draw-down dropped on the card floods it from where it landed.
                    .dropDestination(for: String.self) { items, location in
                        guard let palette = items.first.flatMap(Palette.init(rawValue:)) else { return false }
                        flood(palette, from: CGPoint(x: location.x / scale, y: location.y / scale))
                        return true
                    }
                    // The fan's card, flying to the bed.
                    .overlay(alignment: .topLeading) {
                        if let flying {
                            CardThumb(composition: session.composition(session.edition(in: flying)), light: light, printed: flightPrinted)
                                .rotationEffect(.degrees(flightTurn))
                                .matchedGeometryEffect(id: flying, in: inFlight ? air : fan, isSource: false)
                                .frame(width: size.width, height: size.height)
                        }
                    }
                    // The margin on the back: sign it once, and hold the signature to sign again.
                    .overlay(alignment: .topLeading) { margin(scale: scale) }
                }
            }
            .simultaneousGesture(pinch)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(session.turned
                ? "The back of the card: the stub as it was scanned. " + (Pencil(edition: session.edition)?.spoken(signed: signatures.isSigned) ?? "")
                : "The card on the press: \(session.edition.colophon)")
            // The studio's acts without a finger: a pass across the middle, a stamp in the corner.
            .accessibilityActions {
                if session.bench == .pull {
                    Button("Overprint across the card") {
                        session.pull(from: CGPoint(x: 44, y: 150), to: CGPoint(x: Card.width - 44, y: 250))
                    }
                }
                if session.bench == .stamp {
                    Button("Stamp the card") { session.stamp(at: CGPoint(x: Card.width - 92, y: 96)) }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// How wet the ink still is, `drying` seconds after a pull: 1 at the pull, then falling away exponentially.
    private func wetness(at date: Date) -> Double {
        #if DEBUG || PERF
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
                        .onLongPressGesture { withAnimation(Motion.settle) { signatures.change(to: nil, undoManager: undoManager) } }
                        .accessibilityElement()
                        .accessibilityLabel("Your signature")
                        .accessibilityAction(named: "Sign again") { signatures.change(to: nil, undoManager: undoManager) }
                } else {
                    SignaturePad(scale: scale) { drawing in
                        withAnimation(Motion.place) { signatures.change(to: drawing, undoManager: undoManager) }
                    }
                }
            }
            .frame(width: r.width * scale, height: r.height * scale)
            .offset(x: r.minX * scale, y: r.minY * scale)
            .transition(.opacity.animation(Motion.settle.delay(0.35)))
        }
    }

    /// Back to the card, asking first when the proof on the press is not the card.
    private func leave() {
        if session.somethingToPull { leaving = true } else { dismiss() }
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
                // The fingers' speed goes on into the spring: the sheets keep the momentum the pinch gave them.
                separate(apart, velocity: value.velocity * 1.25)
            }
    }

    /// New inks spreading across the card from `origin`, about half a second to its far corner (a fifth of a second's
    /// cross-fade under Reduce Motion); when they have covered it, they are the card's.
    private func flood(_ palette: Palette, from origin: CGPoint) {
        guard palette != session.inks, session.flood == nil else { return }
        if session.separation > 0 { separate(false) }
        session.flood = PressSession.Flood(palette: palette, origin: origin)
        withAnimation(reduceMotion ? .linear(duration: 0.2) : .easeOut(duration: 0.55)) {
            session.flood?.progress = 1
        } completion: {
            session.choose(palette)
            session.flood = nil
        }
    }

    /// The fan's card flies to the bed, lands, and the bed prints it, a pass at a time. The fan stays in the hand, so
    /// another movement can be tried straight after; closing it is the inked Movement stamp (2026-10-13: the fan used to
    /// close on every choice, which made comparing movements a chore).
    private func take(_ movement: Movement) {
        // One flight at a time: a second choice while a card is in the air waits for the hand.
        guard flying == nil, movement != session.edition.movement else { return }
        if reduceMotion {
            session.choose(movement)
            Task { await session.reprint(reduceMotion: true) }
            return
        }
        // Lifted off the fan as it lies in the hand, turned with it; nothing moves yet. Matched geometry carries the card's
        // frame and not its turn, so a card that took off straight used to snap square as it left (Day 26's note).
        var lift = Transaction()
        lift.disablesAnimations = true
        withTransaction(lift) {
            flying = movement
            inFlight = false
            flightTurn = FanLayout.angle(of: movement)
            flightPrinted = Plate.foil
        }
        Task {
            // One frame in the hand, so the flight starts from the card where it was.
            try? await Task.sleep(for: .milliseconds(16))
            // It turns square as it flies and its ink lifts, so it lands as the bare sheet the bed prints: the print run
            // starts from what landed, with no whole card between the flight and the first pass.
            withAnimation(Motion.place) {
                inFlight = true
                flightTurn = 0
                flightPrinted = 0
            }
            try? await Task.sleep(for: .milliseconds(480))
            var still = Transaction()
            still.disablesAnimations = true
            withTransaction(still) {
                session.choose(movement)
                session.bare()
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

    /// Spread the sheets, or press them back together with one heavy impact. `velocity` is how fast a pinch was moving
    /// them, in separations a second: the spring starts at that speed, so a flick carries on and a slow pinch settles.
    private func separate(_ apart: Bool, velocity: CGFloat = 0) {
        let wasApart = session.separation > 0
        let target: CGFloat = apart ? 1 : 0
        let distance = target - session.separation
        let carried = abs(distance) > 0.02 ? Double(velocity / distance) : 0
        let spring: Animation = reduceMotion ? Motion.plain
            : .interpolatingSpring(mass: 1, stiffness: 210, damping: 21, initialVelocity: min(max(carried, -12), 12))
        withAnimation(spring) { session.separation = target }
        if !apart, wasApart { closings += 1 }
    }

    // MARK: The bench

    /// The bench: the tool in hand's tray over the strip of tools (ADR-048).
    @ViewBuilder
    private var bench: some View {
        VStack(spacing: 14) {
            // The tool in hand's tray, rising above the strip; nothing when no tool is in hand, so the card keeps the room.
            Group {
                switch session.bench {
                case .movement:
                    Fan(session: session, light: light, namespace: fan) { take($0) }
                        .frame(height: 176)
                case .inks:
                    DrawDowns(session: session) { palette in flood(palette, from: CGPoint(x: Card.width / 2, y: Card.height / 2)) }
                        .frame(height: 130)
                case .stock:
                    SwatchBook(session: session, light: light) { printAgain(on: $0) }
                        .frame(height: 130)
                case .pull, .stamp:
                    StudioTray(session: session, photo: photo)
                case .rest:
                    EmptyView()
                }
            }
            .transition(Self.benchChange)
            .id(session.bench)

            // The back has only the margin to sign; its one way back is in the top bar.
            if !session.turned {
                ToolStrip(session: session) { tool in
                    if session.separation > 0 { separate(false) }
                    withAnimation(reduceMotion ? Motion.plain : Motion.settle) { session.bench = tool }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
        // A stamp lands with a thud; a pass, with the softer drag of a blade.
        .sensoryFeedback(trigger: session.acted) { _, _ in
            session.acts.last?.kind == .stamp ? .impact(weight: .heavy, intensity: 0.85) : .impact(weight: .light, intensity: 0.6)
        }
    }

    /// The top bar's two quiet acts: the plates parted, and the card turned over. Marks, named for VoiceOver.
    @ToolbarContentBuilder private var topActs: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            if !session.turned {
                Button { separate(session.separation == 0) } label: {
                    Image(systemName: session.separation > 0 ? "square.stack.3d.down.forward" : "square.stack.3d.up")
                        .font(.system(size: 16, weight: .medium))
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(session.separation > 0 ? "Press the plates together" : "See the plates")
            }
            Button { turn() } label: {
                Image(systemName: "rectangle.portrait.rotate")
                    .font(.system(size: 16, weight: .medium))
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(session.turned ? "Turn it back" : "Turn it over")
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
                    printed: session.printed, focus: session.focus?.id, separation: separation, asSheets: true,
                    impression: impression, wet: wet)
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
        case .gloss: "Gloss card"
        case .matte: "Matte card"
        case .velvet: "Soft-touch"
        case .pearl: "Pearl card"
        }
    }
}

/// The line over the bed that says whether the card on the press is kept (ADR-030). Not kept: an orange dot and the one way
/// to keep it. Just pulled: a tick and that this is the card now. Otherwise nothing, so it never nags.
private struct KeepLine: View {
    let unkept: Bool
    let justPulled: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let saying = unkept || justPulled
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if unkept {
                Circle().fill(Ink.orange).frame(width: 7, height: 7)
                Text("Not kept yet").font(Type.display(14)).foregroundStyle(Ink.ink)
                Text("Pull the lever to keep it").font(Type.words(14)).foregroundStyle(Ink.grey)
                Image(systemName: "arrow.right").font(Type.display(12)).foregroundStyle(Ink.orange)
            } else if justPulled {
                Image(systemName: "checkmark").font(Type.display(13)).foregroundStyle(Ink.ink)
                Text("Kept. This is the card now.").font(Type.display(14)).foregroundStyle(Ink.ink)
            }
        }
        // Wraps rather than shrinks at the large sizes (decision 005).
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, saying ? 14 : 0)
        .padding(.vertical, saying ? 8 : 0)
        .frame(minHeight: 34)
        .background {
            if saying {
                RoundedRectangle(cornerRadius: 17, style: .continuous).fill(Ink.cream)
                    .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .strokeBorder(unkept ? Ink.orange.opacity(0.45) : Ink.ink.opacity(0.1), lineWidth: 0.75))
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .animation(reduceMotion ? Motion.plain : Motion.settle, value: unkept)
        .animation(reduceMotion ? Motion.plain : Motion.settle, value: justPulled)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
        // Nothing to say, nothing for VoiceOver to land on.
        .accessibilityHidden(!saying)
    }
}

/// The press room's own back: it asks once when the proof on the press is not kept (ADR-030).
private struct LeaveCheck: ViewModifier {
    @Binding var asking: Bool
    let back: () -> Void
    let keep: () -> Void
    let leave: () -> Void

    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: back) {
                        Image(systemName: "chevron.left").font(.system(size: 17, weight: .semibold))
                            // A whole 44-point target at every text size (decision 005; flagged in CI at the largest).
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Back")
                }
            }
            .confirmationDialog("This proof is not kept yet", isPresented: $asking, titleVisibility: .visible) {
                Button("Pull it and keep it", action: keep)
                Button("Leave it on the press", action: leave)
                Button("Stay", role: .cancel) {}
            } message: {
                Text("Only a pulled proof becomes the card. Left on the press, it waits here and the card stays as it was.")
            }
    }
}
