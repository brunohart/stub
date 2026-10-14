import SwiftUI

/// The press's dial (ADR-031): a knob you turn to choose what the press does to the part in hand. It is an object: a
/// black knob standing on the bench with its shadow under it, a knurled grip whose ridges catch the light from the upper
/// left as they turn under it, a glossy top with one highlight that stays where the light is, and an orange line cut
/// into it pointing at the move it is set to. Round it, on the bench, the moves are engraved on an arc, the chosen one
/// in ink and the rest in grey; tap a name and the knob turns to it.
///
/// Turned, it clicks into each move at the stock's sharpness and the card redraws through the in-between; let go and it
/// springs to the nearest; past the first and last it resists. Under Reduce Motion it follows the finger and the card
/// cuts from move to move. To VoiceOver it is one adjustable element; to a keyboard, the arrows.
struct Wheel: View {
    @Binding var position: Double
    let stock: Stock
    /// The dial has come to rest on a move.
    var settled: (Int) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var detents = Detents()
    @State private var lastAngle: Double?
    @State private var grabbed = false

    /// The knob's diameter, and the radius the names are engraved at.
    static let knob: CGFloat = 132
    static let scale: CGFloat = 112
    /// The arc the moves span, from the first at the lower left to the last at the lower right, like a radio's dial.
    static let sweep = 270.0
    static var degreesPerTake: Double { sweep / Double(Treatment.allCases.count - 1) }
    /// Past either end the dial gives this much of the finger's turn.
    static let resistance = 0.3
    /// Where the light comes from, in the dial's degrees (0 is up, clockwise).
    static let light = -45.0

    private var range: ClosedRange<Int> { Proof.takeRange }
    private var take: Int { min(max(Int(position.rounded()), range.lowerBound), range.upperBound) }

    /// The dial's angle for a position: 0 is straight up, clockwise positive.
    static func angle(_ position: Double) -> Double { -sweep / 2 + position * degreesPerTake }

    var body: some View {
        let size = CGSize(width: Self.scale * 2 + 96, height: Self.scale * 2 + 30)
        ZStack {
            engraving
            knob
                .rotationEffect(.degrees(0))
        }
        .frame(width: size.width, height: size.height)
        .offset(y: 14)
        .onAppear { detents.prepare() }
        .onDisappear { detents.stopRatchet() }
        .accessibilityElement()
        .accessibilityLabel("The dial")
        .accessibilityValue(Treatment(rawValue: take)?.name ?? "")
        .accessibilityHint("Turn it to choose what the press does to the part.")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: step(1)
            case .decrement: step(-1)
            @unknown default: break
            }
        }
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(keys: [.upArrow, .rightArrow, .downArrow, .leftArrow]) { press in
            step(press.key == .upArrow || press.key == .rightArrow ? 1 : -1)
            return .handled
        }
    }

    // MARK: The scale

    /// The moves round the knob: a short engraved tick at each, the name beyond it. Each name is a button.
    private var engraving: some View {
        ZStack {
            ForEach(Treatment.allCases, id: \.rawValue) { move in
                let a = Self.angle(Double(move.rawValue)) * .pi / 180
                let chosen = move.rawValue == take
                let tick = CGPoint(x: sin(a) * (Self.knob / 2 + 10), y: -cos(a) * (Self.knob / 2 + 10))
                Capsule()
                    .fill(chosen ? Ink.orange : Ink.ink.opacity(0.28))
                    .frame(width: 2, height: chosen ? 9 : 6)
                    .rotationEffect(.radians(a))
                    .offset(x: tick.x, y: tick.y)
                Button {
                    turn(to: move.rawValue)
                } label: {
                    Text(move.name)
                        .font(chosen ? Type.display(13) : Type.words(12))
                        .foregroundStyle(chosen ? Ink.ink : Ink.grey)
                        .fixedSize()
                        .padding(.horizontal, 6)
                        .frame(minHeight: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .offset(x: sin(a) * (Self.scale + 22), y: -cos(a) * (Self.scale + 4))
                .accessibilityHidden(true)
            }
        }
        .animation(Motion.settle, value: take)
    }

    // MARK: The knob

    private var knob: some View {
        let turn = Self.angle(position)
        return ZStack {
            // Its shadow on the bench, away from the light, and a tight one where it stands.
            Circle().fill(Ink.ink.opacity(0.22)).blur(radius: grabbed ? 14 : 10)
                .offset(x: 6, y: grabbed ? 14 : 10)
            Circle().fill(Ink.ink.opacity(0.35)).blur(radius: 2).offset(x: 1, y: 2)
            // The grip: a knurled edge, its ridges lit by where they face.
            Knurl(rotation: turn, light: Self.light)
            // The top: a glossy black face set in from the grip.
            Circle()
                .fill(RadialGradient(colors: [Color(hex: 0x3A3836), Color(hex: 0x1A1918), Color(hex: 0x0E0D0C)],
                                     center: UnitPoint(x: 0.4, y: 0.35), startRadius: 2, endRadius: Self.knob * 0.5))
                .padding(13)
                .overlay {
                    // The lip between the grip and the top: lit on the side of the light, shaded on the other.
                    Circle().strokeBorder(LinearGradient(colors: [.white.opacity(0.35), .black.opacity(0.6)],
                                                         startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.4)
                        .padding(13)
                }
            // The pointer, cut into the top and filled orange, turning with the knob.
            Capsule()
                .fill(Ink.orange)
                .frame(width: 4, height: 26)
                .shadow(color: .black.opacity(0.6), radius: 0.5, x: 0, y: -0.5)
                .offset(y: -Self.knob / 2 + 30)
                .rotationEffect(.degrees(turn))
            // The dimple in the middle, where a finger rests.
            Circle()
                .fill(RadialGradient(colors: [Color(hex: 0x0B0A0A), Color(hex: 0x2A2826)], center: UnitPoint(x: 0.6, y: 0.65),
                                     startRadius: 1, endRadius: 18))
                .frame(width: 30, height: 30)
                .overlay(Circle().strokeBorder(LinearGradient(colors: [.black.opacity(0.5), .white.opacity(0.18)],
                                                              startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
            // The light on the gloss: it stays where the lamp is while the knob turns under it.
            Ellipse()
                .fill(RadialGradient(colors: [.white.opacity(0.28), .white.opacity(0)], center: .center, startRadius: 0, endRadius: 30))
                .frame(width: 58, height: 30)
                .rotationEffect(.degrees(-35))
                .offset(x: -22, y: -26)
                .blendMode(.screen)
                .allowsHitTesting(false)
        }
        .frame(width: Self.knob, height: Self.knob)
        .scaleEffect(grabbed ? 1.03 : 1)
        .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.7), value: grabbed)
        .contentShape(Circle().inset(by: -16))
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { value in drag(value, in: CGSize(width: Self.knob, height: Self.knob)) }
                .onEnded { _ in release() }
        )
    }

    // MARK: The hand

    private func drag(_ value: DragGesture.Value, in size: CGSize) {
        if !grabbed { grabbed = true }
        let dx = value.location.x - size.width / 2, dy = value.location.y - size.height / 2
        // Too near the middle to have an angle worth reading.
        guard dx * dx + dy * dy > 14 * 14 else { lastAngle = nil; return }
        let angle = atan2(Double(dx), Double(-dy)) * 180 / .pi
        defer { lastAngle = angle }
        guard let lastAngle else { return }
        var delta = angle - lastAngle
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        advance(by: delta)
    }

    private func release() {
        lastAngle = nil
        grabbed = false
        settle()
    }

    /// Turn by `degrees` without animation, click at every move crossed, and resist past the ends.
    private func advance(by degrees: Double) {
        var delta = degrees / Self.degreesPerTake
        if (position < Double(range.lowerBound) && delta < 0) || (position > Double(range.upperBound) && delta > 0) {
            delta *= Self.resistance
        }
        let before = position
        var still = Transaction()
        still.disablesAnimations = true
        withTransaction(still) { position += delta }
        if Int(position.rounded()) != Int(before.rounded()), (Double(range.lowerBound)...Double(range.upperBound)).contains(position) {
            detents.detent(on: stock, speed: 0)
        }
    }

    private func settle() {
        let target = take
        withAnimation(reduceMotion ? Motion.plain : .spring(response: 0.32, dampingFraction: 0.62)) { position = Double(target) }
        settled(target)
    }

    /// To a move by name: the knob turns there on its spring, clicking through the moves between.
    private func turn(to target: Int) {
        guard target != take else { return }
        detents.detent(on: stock, speed: 0)
        withAnimation(reduceMotion ? Motion.plain : .spring(response: 0.45, dampingFraction: 0.72)) { position = Double(target) }
        settled(target)
    }

    /// One move, as VoiceOver and the arrow keys ask for it.
    private func step(_ by: Int) {
        turn(to: min(max(take + by, range.lowerBound), range.upperBound))
    }
}

/// The knob's grip: a ring of fine ridges, each lit by the way it faces the light, so the edge glints where the lamp is and
/// falls into shadow opposite it as the knob turns. Animatable on its rotation, so the settling spring turns the ridges too.
private struct Knurl: View, @MainActor Animatable {
    var rotation: Double
    let light: Double

    var animatableData: Double {
        get { rotation }
        set { rotation = newValue }
    }

    var body: some View {
        Canvas { context, size in
            let r = min(size.width, size.height) / 2
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            context.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)), with: .color(Color(hex: 0x141312)))
            let ridges = 64
            for i in 0..<ridges {
                let a = Double(i) / Double(ridges) * 360 + rotation
                // How squarely this ridge faces the light: 1 facing it, -1 away.
                let facing = cos((a - light) * .pi / 180)
                let rad = (a - 90) * .pi / 180
                var ridge = Path()
                ridge.move(to: CGPoint(x: c.x + CGFloat(cos(rad)) * (r - 13), y: c.y + CGFloat(sin(rad)) * (r - 13)))
                ridge.addLine(to: CGPoint(x: c.x + CGFloat(cos(rad)) * (r - 1), y: c.y + CGFloat(sin(rad)) * (r - 1)))
                let lit = max(0, facing)
                context.stroke(ridge, with: .color(.white.opacity(0.06 + 0.42 * lit * lit)), lineWidth: 1.6)
            }
            // The rim's own edge: bright toward the light, dark away from it.
            context.stroke(Path(ellipseIn: CGRect(x: c.x - r + 0.75, y: c.y - r + 0.75, width: 2 * r - 1.5, height: 2 * r - 1.5)),
                           with: .linearGradient(Gradient(colors: [.white.opacity(0.4), .black.opacity(0.5)]),
                                                 startPoint: CGPoint(x: c.x - r, y: c.y - r), endPoint: CGPoint(x: c.x + r, y: c.y + r)),
                           lineWidth: 1.5)
        }
    }
}
