import SwiftUI

/// The press's wheel (ADR-016): a knurled ring you turn to pull another take of the part in hand. A detent every 30°,
/// felt at the stock's sharpness. Flick it and it coasts with friction, then settles on the nearest take on a spring;
/// past take 0 (or 99) it resists. Under Reduce Motion it follows the finger but never coasts, and the card cuts from
/// take to take. To VoiceOver it is one adjustable element; to a keyboard, the arrows.
struct Wheel: View {
    @Binding var position: Double
    let stock: Stock
    /// The wheel has come to rest on a take.
    var settled: (Int) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var detents = Detents()
    @State private var lastAngle: Double?
    @State private var lastTime: ContinuousClock.Instant?
    /// Degrees a millisecond, smoothed.
    @State private var velocity: Double = 0
    @State private var coasting: Task<Void, Never>?

    static let diameter: CGFloat = 172
    static let degreesPerTake = 30.0
    /// A release faster than this, in degrees a millisecond, coasts.
    static let coastsAbove = 0.25
    /// What is left of the speed after each 16 ms of coasting.
    static let friction = 0.93
    /// Past either end the wheel gives this much of the finger's turn.
    static let resistance = 0.3

    private var range: ClosedRange<Int> { Proof.takeRange }
    private var take: Int { min(max(Int(position.rounded()), range.lowerBound), range.upperBound) }

    var body: some View {
        ZStack {
            Knurl(rotation: position * Self.degreesPerTake)
                .frame(width: Self.diameter, height: Self.diameter)
            // The notch: the one fixed mark, at twelve o'clock, the reading line.
            Notch()
                .fill(Ink.orange)
                .frame(width: 12, height: 9)
                .offset(y: -Self.diameter / 2 - 9)
            VStack(spacing: 2) {
                Text(String(take))
                    .font(Type.numbers(34))
                    .foregroundStyle(Ink.ink)
                    .contentTransition(.numericText(value: Double(take)))
                    .monospacedDigit()
                Text("of \(range.upperBound)")
                    .font(Type.numbers(11))
                    .foregroundStyle(Ink.grey)
            }
            .allowsHitTesting(false)
        }
        .frame(width: Self.diameter + 24, height: Self.diameter + 24)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged(turn)
                .onEnded { _ in release() }
        )
        .onAppear { detents.prepare() }
        .onDisappear {
            coasting?.cancel()
            detents.stopRatchet()
        }
        .accessibilityElement()
        .accessibilityLabel("The wheel")
        .accessibilityValue("Take \(PressSession.spelled(take)), of \(PressSession.spelled(range.upperBound))")
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

    // MARK: The hand

    private func turn(_ value: DragGesture.Value) {
        coasting?.cancel()
        let centre = CGPoint(x: (Self.diameter + 24) / 2, y: (Self.diameter + 24) / 2)
        let dx = value.location.x - centre.x, dy = value.location.y - centre.y
        let now = ContinuousClock.now
        // Too near the hub to have an angle worth reading.
        guard dx * dx + dy * dy > 18 * 18 else { lastAngle = nil; return }
        let angle = atan2(Double(dy), Double(dx)) * 180 / .pi
        defer { lastAngle = angle; lastTime = now }
        guard let lastAngle, let lastTime else { velocity = 0; return }
        var delta = angle - lastAngle
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        let ms = max(Double(lastTime.duration(to: now) / .microseconds(1)) / 1000, 1)
        velocity = velocity * 0.5 + (delta / ms) * 0.5
        advance(by: delta)
    }

    private func release() {
        lastAngle = nil
        lastTime = nil
        let inside = position >= Double(range.lowerBound) && position <= Double(range.upperBound)
        if !reduceMotion, inside, abs(velocity) > Self.coastsAbove {
            let start = velocity
            coasting = Task { await coast(from: start) }
        } else {
            settle()
        }
    }

    /// Turn by `degrees` without animation, click at every take crossed, and resist past the ends.
    private func advance(by degrees: Double) {
        var delta = degrees / Self.degreesPerTake
        if (position < Double(range.lowerBound) && delta < 0) || (position > Double(range.upperBound) && delta > 0) {
            delta *= Self.resistance
        }
        let before = position
        var still = Transaction()
        still.disablesAnimations = true
        withTransaction(still) { position += delta }
        let crossed = Int(position.rounded(.down)) - Int(before.rounded(.down))
        if crossed != 0, (Double(range.lowerBound)...Double(range.upperBound)).contains(position) {
            detents.detent(on: stock, speed: velocity)
        }
    }

    /// Friction, frame by frame, until the wheel is nearly still or runs into an end; then the spring.
    private func coast(from speed: Double) async {
        var v = speed
        var last = ContinuousClock.now
        while abs(v) > 0.02, !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(8))
            guard !Task.isCancelled else { return }
            let now = ContinuousClock.now
            let ms = Double(last.duration(to: now) / .microseconds(1)) / 1000
            last = now
            v *= pow(Self.friction, ms / 16)
            velocity = v
            advance(by: v * ms)
            if position < Double(range.lowerBound) - 0.3 || position > Double(range.upperBound) + 0.3 { break }
        }
        guard !Task.isCancelled else { return }
        settle()
    }

    private func settle() {
        velocity = 0
        let target = take
        withAnimation(reduceMotion ? Motion.plain : Motion.settle) { position = Double(target) }
        settled(target)
    }

    /// One take, as VoiceOver and the arrow keys ask for it.
    private func step(_ by: Int) {
        let target = min(max(take + by, range.lowerBound), range.upperBound)
        guard target != take else { return }
        detents.detent(on: stock, speed: 0)
        withAnimation(reduceMotion ? Motion.plain : Motion.settle) { position = Double(target) }
        settled(target)
    }
}

/// The ring: sixty ticks, every fifth long (one a take), turned with the wheel. Animatable on its rotation, so the
/// settle spring turns the ring with the card.
private struct Knurl: View, @MainActor Animatable {
    var rotation: Double

    var animatableData: Double {
        get { rotation }
        set { rotation = newValue }
    }

    var body: some View {
        Canvas { context, size in
            let r = min(size.width, size.height) / 2
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            context.stroke(Path(ellipseIn: CGRect(x: c.x - r + 0.6, y: c.y - r + 0.6, width: 2 * r - 1.2, height: 2 * r - 1.2)),
                           with: .color(Ink.ink.opacity(0.85)), lineWidth: 1.2)
            context.stroke(Path(ellipseIn: CGRect(x: c.x - r + 26, y: c.y - r + 26, width: 2 * r - 52, height: 2 * r - 52)),
                           with: .color(Ink.ink.opacity(0.18)), lineWidth: 0.75)
            for i in 0..<60 {
                let long = i % 5 == 0
                let a = (Double(i) * 6 + rotation - 90) * .pi / 180
                let outer = r - 5, inner = r - (long ? 19 : 11)
                var tick = Path()
                tick.move(to: CGPoint(x: c.x + CGFloat(cos(a)) * inner, y: c.y + CGFloat(sin(a)) * inner))
                tick.addLine(to: CGPoint(x: c.x + CGFloat(cos(a)) * outer, y: c.y + CGFloat(sin(a)) * outer))
                context.stroke(tick, with: .color(Ink.ink.opacity(long ? 0.8 : 0.38)), lineWidth: long ? 1.4 : 1)
            }
        }
    }
}

/// A small triangle pointing down at the ring.
private struct Notch: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
