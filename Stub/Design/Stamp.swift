import SwiftUI

/// The app's buttons, pressed like a stamp into paper (ADR-022). At rest the ink sits a few points up and to the left of a
/// second colour pass, an orange plate that did not line up: the misregistration the title and the cards already carry.
/// Press, and the ink goes down onto its plate and the two print in register, a breath smaller, with one firm tap under the
/// thumb at the moment of contact. Let go and it springs back up off the plate with the stamp's one overshoot. The press
/// lands within a frame and the haptic with it; the release is the only part that animates for long.
///
/// Three inks. `ink` is the primary act on a screen (keep, open the press): parchment words on ink, an orange plate.
/// `paper` is a destination or a second act: ink words on cream, a navy plate. `quiet` is words alone, for what should
/// not be shouted (throw away, cancel): it dips and fades, and has no plate.
struct StampStyle: ButtonStyle {
    enum Kind { case ink, paper, quiet }
    var ink: Kind = .ink
    /// Full width of its container, label to the leading edge.
    var wide = false
    /// Less padding, for a row of four.
    var tight = false

    func makeBody(configuration: Configuration) -> some View {
        StampBody(configuration: configuration, ink: ink, wide: wide, tight: tight)
    }
}

extension ButtonStyle where Self == StampStyle {
    static var stamp: StampStyle { StampStyle() }
    static func stamp(_ ink: StampStyle.Kind, wide: Bool = false, tight: Bool = false) -> StampStyle {
        StampStyle(ink: ink, wide: wide, tight: tight)
    }
}

private struct StampBody: View {
    let configuration: ButtonStyle.Configuration
    let ink: StampStyle.Kind
    let wide: Bool
    let tight: Bool
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How far the plate is out of register at rest, in points.
    static let misregister = CGSize(width: 3, height: 3.5)

    var body: some View {
        let pressed = configuration.isPressed && isEnabled
        // Down onto the plate on the press; back up on release with the stamp's overshoot. Under Reduce Motion nothing
        // travels: the ink darkens a little where it would have gone down.
        let down = pressed && !reduceMotion
        let face = configuration.label
            .font(Type.words(16))
            .foregroundStyle(foreground)
            .padding(.horizontal, ink == .quiet ? 4 : tight ? 6 : 18)
            .padding(.vertical, ink == .quiet ? 6 : tight ? 10 : 13)
            .frame(maxWidth: wide ? .infinity : nil, minHeight: 44, alignment: wide ? .leading : .center)
            // Words alone never wrap or truncate: "Cancel" in a toolbar keeps its letters.
            .fixedSize(horizontal: ink == .quiet, vertical: false)
            .background { if ink != .quiet { shape.fill(fill) } }
            .overlay { if ink == .paper { shape.strokeBorder(Ink.ink.opacity(0.16), lineWidth: 0.75) } }
            .overlay { if pressed && reduceMotion && ink != .quiet { shape.fill(Ink.ink.opacity(0.12)) } }
            .contentShape(shape)

        face
            .offset(down ? Self.misregister : .zero)
            .scaleEffect(down ? 0.985 : 1)
            .opacity(ink == .quiet && pressed ? 0.55 : 1)
            // The plate stays where it was printed; `offset` moves only the ink, so pressing puts the ink onto it.
            .background {
                if let plate, isEnabled {
                    shape.fill(plate).offset(Self.misregister).accessibilityHidden(true)
                }
            }
            .animation(pressed ? Motion.touchDown : Motion.press(reduceMotion: reduceMotion), value: pressed)
            // The tap lands with the ink on the plate, not on release: a stamp is felt when it meets the paper.
            .sensoryFeedback(.impact(flexibility: .rigid, intensity: ink == .quiet ? 0.35 : 0.6), trigger: pressed) { _, now in now }
    }

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 6, style: .continuous) }

    private var fill: Color {
        switch ink {
        case .ink: isEnabled ? Ink.ink : Ink.ink.opacity(0.2)
        case .paper: Ink.cream
        case .quiet: .clear
        }
    }

    private var foreground: Color {
        switch ink {
        case .ink: Ink.paper
        case .paper: isEnabled ? Ink.ink : Ink.grey
        case .quiet: isEnabled ? Ink.ink.opacity(0.8) : Ink.grey
        }
    }

    /// The second pass: orange under the ink, navy under the paper, none under words alone.
    private var plate: Color? {
        switch ink {
        case .ink: Ink.orange.opacity(0.55)
        case .paper: Ink.navy.opacity(0.16)
        case .quiet: nil
        }
    }
}

/// A destination or an act shown as a word over a mark, for a row of them (the detail's actions, the table's dock): the
/// paper stamp, square-ish, the symbol above the word so four fit across a phone.
struct StampLabel: View {
    let title: String
    let symbol: String
    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .regular))
                .frame(height: 20)
            Text(title)
                .font(Type.words(13))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)
    }
}

/// Things put down one after another rather than all at once: each lands a beat after the last, from a few points up, with
/// the stamp's one overshoot (ADR-022). Under Reduce Motion they are simply there.
struct PlacedInTurn: ViewModifier {
    var order: Int
    var placed: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(placed || reduceMotion ? 1 : 0)
            .offset(y: placed || reduceMotion ? 0 : -8)
            .scaleEffect(placed || reduceMotion ? 1 : 1.03, anchor: .leading)
            .animation(reduceMotion ? nil : Motion.stamp.delay(0.12 + Double(order) * 0.07), value: placed)
    }
}

extension View {
    func placedInTurn(_ order: Int, placed: Bool) -> some View { modifier(PlacedInTurn(order: order, placed: placed)) }
}
