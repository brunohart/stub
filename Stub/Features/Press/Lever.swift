import SwiftUI

/// The press's lever (ADR-016, brief §5.7): a short rail down the right of the bed with a handle on it. Pull the handle
/// down and it pushes back harder the further it goes; near the bottom it gives, the platen comes down and the proof is
/// pulled. Let go before that and it springs back and nothing is pulled. There is no Save button because nothing here is
/// a document: committing is physical and deliberate.
struct Lever: View {
    /// The proof is pulled.
    var pulled: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var travel: CGFloat = 0
    @State private var gave = false
    @State private var feel = LeverFeel()

    /// How far the handle goes, in points.
    static let length: CGFloat = 150
    /// The share of the way down at which it gives.
    static let gives: CGFloat = 0.92

    /// Where the handle is for a finger `drag` points down: a little behind the finger, more so the deeper it goes, so
    /// the resistance you feel is also one you see. It takes about 166 points of drag to reach the point where it gives.
    /// The curve x(1 − 0.15x) meets the bottom at x ≈ 1.23 and would turn back up after 3.33, so a finger dragged on
    /// past the bottom leaves the handle at the bottom.
    static func handle(for drag: CGFloat) -> CGFloat {
        let bottom = (1 - (1 - 0.6).squareRoot()) / 0.3
        let x = min(max(drag, 0) / length, bottom)
        return min(length * x * (1 - 0.15 * x), length)
    }

    var body: some View {
        ZStack(alignment: .top) {
            // The rail.
            Capsule()
                .fill(Ink.ink.opacity(0.16))
                .frame(width: 3, height: Self.length + 28)
            // The handle: a short bar across the rail, in the ink.
            Capsule()
                .fill(Ink.ink)
                .frame(width: 28, height: 12)
                .shadow(color: .black.opacity(0.22), radius: 2, x: 0, y: 1.5)
                .offset(y: 8 + travel)
        }
        .frame(width: 44, height: Self.length + 44, alignment: .top)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    guard !gave else { return }
                    let at = Self.handle(for: value.translation.height)
                    travel = at
                    feel.resist(at: Double(at / Self.length))
                    if at >= Self.length * Self.gives {
                        gave = true
                        withAnimation(reduceMotion ? Motion.plain : .easeIn(duration: 0.06)) { travel = Self.length }
                        feel.platen()
                        pulled()
                    }
                }
                .onEnded { _ in
                    feel.release()
                    gave = false
                    // Under Reduce Motion the handle still follows the finger, but it does not spring or overshoot.
                    withAnimation(reduceMotion ? Motion.plain : Motion.stamp) { travel = 0 }
                }
        )
        .accessibilityElement()
        .accessibilityLabel("The lever")
        .accessibilityHint("Pulls the proof.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "Pull the proof") {
            feel.platen()
            pulled()
        }
        .accessibilityAction { feel.platen(); pulled() }
    }
}
