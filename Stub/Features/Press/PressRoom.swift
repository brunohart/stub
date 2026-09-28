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

    init(stub: Stub, copy: Copy) {
        self.stub = stub
        _session = State(initialValue: PressSession(title: stub.title, copy: copy))
    }

    var body: some View {
        ZStack {
            Paper()
            VStack(spacing: 0) {
                bed
                    .frame(maxHeight: .infinity)
                    .padding(.horizontal, 20)
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
                    .frame(height: 214)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .sensoryFeedback(.impact(weight: .heavy, intensity: 1), trigger: closings)
        .onAppear { if !reduceMotion { attitude.start() } }
        .onDisappear { attitude.stop() }
        #if DEBUG
        .task { await DebugDrive.shared.press(session, reduceMotion: reduceMotion) }
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
                    OnTheBed(session: session, position: session.position, separation: session.separation, light: light,
                             reduceMotion: reduceMotion)
                        .scaleEffect(scale, anchor: .topLeading)
                        .frame(width: size.width, height: size.height, alignment: .topLeading)
                        .shadow(color: .black.opacity(0.18 * (1 - session.separation)), radius: 14, x: 6 - tilt.x * 8, y: 12 - tilt.y * 8)
                        .shadow(color: .black.opacity(0.14), radius: 2, x: 1, y: 2)
                        .contentShape(Rectangle())
                        .gesture(SpatialTapGesture().onEnded { value in
                            let point = CGPoint(x: value.location.x / scale, y: value.location.y / scale)
                            withAnimation(reduceMotion ? Motion.plain : Motion.settle) { session.touch(at: point) }
                        })
                }
            }
            .simultaneousGesture(pinch)
            .overlay(alignment: .topLeading) { parts(scale: scale) }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("The card on the press: \(session.edition.described)")
            .accessibilityRotor("Parts") {
                ForEach(session.turnable) { part in
                    AccessibilityRotorEntry(Text(session.spoken(part)), id: part.id, in: rotor)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            VStack(spacing: 26) {
                HStack(alignment: .top, spacing: 30) {
                    Choice("Movement", session.edition.movement.rawValue.capitalized)
                    Choice("Inks", session.edition.palette.rawValue.capitalized)
                    Choice("Stock", session.edition.stock.words)
                }
                // Separations are a pinch on the card, and a button for anyone who does not pinch.
                Button { separate(session.separation == 0) } label: {
                    Text(session.separation > 0 ? "Press them together" : "See the plates")
                        .font(Type.words(15))
                        .foregroundStyle(Ink.ink)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                        .overlay(Capsule().stroke(Ink.ink.opacity(0.25), lineWidth: 0.75))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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

/// The card on the bed at a wheel position and a separation. Animatable on both, so the spring that settles the wheel
/// carries the card through the in-betweens, and the one that spreads the sheets lifts them apart.
private struct OnTheBed: View, @MainActor Animatable {
    let session: PressSession
    var position: Double
    var separation: CGFloat
    let light: Light
    let reduceMotion: Bool

    var animatableData: AnimatablePair<Double, CGFloat> {
        get { AnimatablePair(position, separation) }
        set { position = newValue.first; separation = newValue.second }
    }

    var body: some View {
        EditionFace(composition: session.drawing(at: position, reduceMotion: reduceMotion), light: light,
                    focus: session.focus?.id, separation: separation)
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

/// One of the edition's three choices, at rest on the bench: the word, and what it is now.
private struct Choice: View {
    let label: String
    let value: String
    init(_ label: String, _ value: String) { self.label = label; self.value = value }

    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(Type.words(17)).foregroundStyle(Ink.ink)
            Text(label).font(Type.words(12)).foregroundStyle(Ink.grey)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), \(value)")
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
