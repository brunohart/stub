import SwiftUI

/// The app's buttons (ADR-029): clean capsules in the drawer's own inks. `ink` is a screen's one primary act (Keep a stub,
/// Keep it): parchment words on near-black. `paper` is a destination or a second act: ink words on cream with a hairline
/// edge. `quiet` is words alone, for what should not be shouted (Cancel, Throw this stub away).
///
/// Pressed, a button goes into the page: a touch smaller, its shadow drawn in close, one soft tap under the thumb at the
/// moment of contact. Let go, it comes back up on a spring with a single small overshoot. Nothing else moves. Under Reduce
/// Motion it does not travel; it darkens a little where it is pressed.
///
/// Until 2026-10-15 the buttons were stamps, the ink printed out of register over a coloured plate and lifting off with a
/// tip and a ring of ink (ADR-022). Bruno wanted them cleaner; the plate is gone, the inks and the faces stay.
struct StubButtonStyle: ButtonStyle {
    enum Kind { case ink, paper, quiet }
    var kind: Kind = .ink
    /// Full width of its container, label to the leading edge.
    var wide = false
    /// A tile in a row (the actions under a card, the bench's choices): a rounded square-ish shape, less padding.
    var tight = false

    func makeBody(configuration: Configuration) -> some View {
        StubButtonBody(configuration: configuration, kind: kind, wide: wide, tight: tight)
    }
}

extension ButtonStyle where Self == StubButtonStyle {
    static var stub: StubButtonStyle { StubButtonStyle() }
    static func stub(_ kind: StubButtonStyle.Kind, wide: Bool = false, tight: Bool = false) -> StubButtonStyle {
        StubButtonStyle(kind: kind, wide: wide, tight: tight)
    }
}

private struct StubButtonBody: View {
    let configuration: ButtonStyle.Configuration
    let kind: StubButtonStyle.Kind
    let wide: Bool
    let tight: Bool
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let pressed = configuration.isPressed && isEnabled
        let shape = ButtonShape(tight: tight)
        configuration.label
            .font(Type.display(16))
            .foregroundStyle(foreground)
            .lineLimit(2)
            .padding(.horizontal, kind == .quiet ? 6 : tight ? 8 : 22)
            .padding(.vertical, kind == .quiet ? 6 : tight ? 12 : 0)
            .frame(maxWidth: wide ? .infinity : nil, minHeight: kind == .quiet ? 44 : tight ? 64 : 50, alignment: wide ? .leading : .center)
            // Words alone never wrap or truncate: "Cancel" in a toolbar keeps its letters.
            .fixedSize(horizontal: kind == .quiet, vertical: false)
            .background {
                if kind != .quiet {
                    shape
                        .fill(fill)
                        // The edge: a breath of light along the top of the ink, a hairline round the paper.
                        .overlay {
                            switch kind {
                            case .ink:
                                shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.16), .white.opacity(0)], startPoint: .top, endPoint: .center),
                                                   lineWidth: 1)
                            default:
                                shape.strokeBorder(Ink.ink.opacity(isEnabled ? 0.1 : 0.06), lineWidth: 0.75)
                            }
                        }
                        .shadow(color: Ink.ink.opacity(shadowOpacity(pressed)), radius: pressed ? 2 : (kind == .ink ? 10 : 6),
                                x: 0, y: pressed ? 1 : (kind == .ink ? 5 : 3))
                }
            }
            .overlay { if pressed && reduceMotion && kind != .quiet { shape.fill(Ink.ink.opacity(0.1)) } }
            .contentShape(kind == .quiet ? AnyShape(Rectangle()) : AnyShape(shape))
            .opacity(kind == .quiet && pressed ? 0.45 : 1)
            .scaleEffect(pressed && !reduceMotion ? (tight ? 0.95 : 0.965) : 1)
            .brightness(pressed && kind == .ink ? 0.04 : 0)
            .animation(pressed ? .spring(response: 0.16, dampingFraction: 0.9) : .spring(response: 0.38, dampingFraction: 0.6),
                       value: pressed)
            // One tap, at contact: the button meets the page.
            .sensoryFeedback(.impact(flexibility: .soft, intensity: kind == .quiet ? 0.3 : 0.55), trigger: pressed) { _, now in now }
    }

    private func shadowOpacity(_ pressed: Bool) -> Double {
        guard isEnabled else { return 0 }
        switch kind {
        case .ink: return pressed ? 0.14 : 0.2
        case .paper: return pressed ? 0.05 : 0.07
        case .quiet: return 0
        }
    }

    private var fill: Color {
        switch kind {
        case .ink: isEnabled ? Ink.ink : Ink.ink.opacity(0.12)
        case .paper: Ink.cream
        case .quiet: .clear
        }
    }

    private var foreground: Color {
        switch kind {
        case .ink: isEnabled ? Ink.paper : Ink.grey
        case .paper: isEnabled ? Ink.ink : Ink.grey
        case .quiet: isEnabled ? Ink.soft(0.8) : Ink.grey
        }
    }
}

/// A button's outline: a capsule, or for a tile in a row a rounded rectangle with continuous corners.
struct ButtonShape: InsettableShape {
    var tight = false
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset, dy: inset)
        return tight ? RoundedRectangle(cornerRadius: max(16 - inset, 0), style: .continuous).path(in: r)
                     : Capsule(style: .continuous).path(in: r)
    }

    func inset(by amount: CGFloat) -> ButtonShape {
        var shape = self
        shape.inset += amount
        return shape
    }
}

/// A destination or an act shown as a word under a mark, for a row of tiles (the actions under a card): the symbol above
/// the word so four fit across a phone.
struct ActionLabel: View {
    let title: String
    let symbol: String
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .regular))
                .frame(height: 22)
            Text(title)
                .font(Type.words(13))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Two or three choices of one thing, as one control: a cream track, and an ink thumb that slides to the choice made, the
/// chosen words in parchment. A tick under the thumb as it lands.
struct Segmented<Value: Hashable>: View {
    let options: [Value]
    @Binding var selection: Value
    let label: (Value) -> (title: String, symbol: String?)
    @Namespace private var thumb
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // In a row with its symbols; in a row of words alone where that will not fit; one over the other at the largest
        // sizes. Never a word cut at the screen's edge (decision 005).
        ViewThatFits(in: .horizontal) {
            track(AnyLayout(HStackLayout(spacing: 0)), symbols: true, stacked: false)
            track(AnyLayout(HStackLayout(spacing: 0)), symbols: false, stacked: false)
            track(AnyLayout(VStackLayout(alignment: .leading, spacing: 0)), symbols: true, stacked: true)
        }
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func track(_ layout: AnyLayout, symbols: Bool, stacked: Bool) -> some View {
        layout {
            ForEach(options, id: \.self) { option in
                let chosen = option == selection
                let words = label(option)
                Button {
                    withAnimation(reduceMotion ? Motion.plain : .spring(response: 0.34, dampingFraction: 0.78)) { selection = option }
                } label: {
                    HStack(spacing: 6) {
                        if symbols, let symbol = words.symbol { Image(systemName: symbol).font(Type.display(13)) }
                        Text(words.title).font(Type.display(14))
                    }
                    .fixedSize()
                    .foregroundStyle(chosen ? Ink.paper : Ink.soft(0.7))
                    .padding(.horizontal, 14)
                    .frame(minHeight: 38)
                    .frame(maxWidth: stacked ? .infinity : nil, alignment: .leading)
                    .background {
                        if chosen {
                            RoundedRectangle(cornerRadius: 19, style: .continuous)
                                .fill(Ink.ink)
                                .shadow(color: Ink.ink.opacity(0.18), radius: 4, x: 0, y: 2)
                                .matchedGeometryEffect(id: "thumb", in: thumb)
                        }
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(chosen ? .isSelected : [])
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Ink.cream))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Ink.ink.opacity(0.1), lineWidth: 0.75))
    }
}

/// Things put down one after another rather than all at once: each lands a beat after the last, from a few points up, with
/// one small overshoot (ADR-022). Under Reduce Motion they are simply there.
struct PlacedInTurn: ViewModifier {
    var order: Int
    var placed: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let down = placed || reduceMotion
        content
            .opacity(down ? 1 : 0)
            // A render effect, not a layout one: what VoiceOver and the audit measure is where the thing comes to rest.
            .visualEffect { view, _ in
                view.offset(y: down ? 0 : -8).scaleEffect(down ? 1 : 1.03, anchor: .leading)
            }
            .animation(reduceMotion ? nil : Motion.stamp.delay(0.12 + Double(order) * 0.07), value: placed)
    }
}

extension View {
    func placedInTurn(_ order: Int, placed: Bool) -> some View { modifier(PlacedInTurn(order: order, placed: placed)) }
}
