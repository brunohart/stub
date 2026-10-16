import SwiftUI

/// The drawer's label (ADR-022): a brass holder of the kind screwed to a card-catalogue drawer, with a typed card slid
/// into it saying what the drawer holds. The drawer of every stub is not a drawer anyone labelled: it is the cabinet, so it
/// wears the cabinet's own plate, the total engraved into the brass with no card to change (ADR-036). It is the home
/// screen's name for itself, where the app's own name and a sentence used to be. Brass is a material, so it answers the light:
/// its sheen moves with the phone as the edition's foil does (one light, the phone's), and stays where it is under Reduce
/// Motion and in the simulator, which has no gyroscope. Pressed, the card goes a shade into its holder; it opens the season.
struct DrawerLabel: View {
    /// What is typed on the card.
    enum Typed: Equatable {
        /// The drawer of every stub: the years, the stubs, the cinemas.
        case every(films: Int, cinemas: Int, years: String?)
        /// A drawer the person made: its name, and under it how many stubs and the years.
        case made(name: String, films: Int, years: String?)
        /// A blank card in an empty holder: a drawer not made yet.
        case blank
    }

    let typed: Typed
    /// A stub is being held over it: the drawer slides out a little to take it (ADR-026).
    var open = false
    var action: () -> Void

    @State private var attitude = Attitude()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let size = CGSize(width: 264, height: 80)

    /// The drawer of every stub's label, from the drawer's numbers.
    init(summary: SeasonSummary, years: String?, open: @escaping () -> Void) {
        self.init(.every(films: summary.films, cinemas: summary.cinemas.count, years: years), action: open)
    }

    init(_ typed: Typed, open: Bool = false, action: @escaping () -> Void) {
        self.typed = typed
        self.open = open
        self.action = action
    }

    private var isEmptyEvery: Bool { if case .every(0, _, _) = typed { true } else { false } }

    var body: some View {
        Button(action: action) {
            ZStack {
                plate
                if case .every(let films, let cinemas, let years) = typed {
                    engraving(films: films, cinemas: cinemas, years: years)
                        .padding(.horizontal, 30)
                } else {
                    window
                    card
                        .padding(.horizontal, 30)
                        .padding(.vertical, 11)
                }
                HStack {
                    Rivet()
                    Spacer()
                    Rivet()
                }
                .padding(.horizontal, 11)
            }
            .frame(width: Self.size.width, height: Self.size.height)
            .scaleEffect(open ? 1.06 : 1)
            .offset(y: open ? 6 : 0)
            .animation(Motion.stamp, value: open)
        }
        .buttonStyle(LabelPress())
        .disabled(isEmptyEvery)
        .sensoryFeedback(.impact(weight: .medium, intensity: 0.7), trigger: open) { _, now in now }
        .onAppear { if !reduceMotion { attitude.start() } }
        .onDisappear { attitude.stop() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
        .accessibilityHint(hint)
        .accessibilityAddTraits(isEmptyEvery ? [] : .isButton)
    }

    // MARK: Brass

    /// The plate: brass brushed along its length, lit from the upper left, its edge catching the light on top and falling
    /// into shadow underneath, and a sheen that slides along it as the phone turns.
    private var plate: some View {
        let shape = RoundedRectangle(cornerRadius: 7, style: .continuous)
        let tilt = reduceMotion ? 0 : attitude.tilt.x
        return shape
            .fill(LinearGradient(stops: [
                .init(color: Color(hex: 0xE6CD93), location: 0),
                .init(color: Color(hex: 0xC9A15C), location: 0.38),
                .init(color: Color(hex: 0xA77E3F), location: 0.72),
                .init(color: Color(hex: 0xC59D58), location: 1),
            ], startPoint: .topLeading, endPoint: .bottomTrailing))
            // The sheen: a soft band of the lamp, where the light is.
            .overlay {
                LinearGradient(stops: [
                    .init(color: .white.opacity(0), location: 0),
                    .init(color: .white.opacity(0.42), location: 0.5),
                    .init(color: .white.opacity(0), location: 1),
                ], startPoint: .leading, endPoint: .trailing)
                .frame(width: 90)
                .rotationEffect(.degrees(18))
                .offset(x: -40 + tilt * 110)
                .blendMode(.screen)
                .animation(.linear(duration: 0.08), value: tilt)
            }
            .clipShape(shape)
            // The plate's own edge: lit along the top, shaded along the bottom.
            .overlay {
                shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.75), .black.opacity(0.35)], startPoint: .top, endPoint: .bottom),
                                   lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.28), radius: 0.8, x: 0, y: 1)
            .shadow(color: Color(hex: 0x3B2A12).opacity(0.18), radius: 7, x: 2, y: 6)
    }

    /// A holder's window: a darker step of brass round the card, where the plate is folded over to hold it.
    private var window: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .strokeBorder(LinearGradient(colors: [Color(hex: 0x7C5A27), Color(hex: 0xE9D29C)], startPoint: .top, endPoint: .bottom),
                          lineWidth: 1.5)
            .padding(.horizontal, 28)
            .padding(.vertical, 9)
    }

    // MARK: The cabinet's plate

    /// The drawer of every stub: the total cut into the brass, large, and beside it what it is and what it spans. Engraved,
    /// so it reads as the cabinet's and not as a label someone slid in; the cuts are dark, their lower lips catch the light.
    private func engraving(films: Int, cinemas: Int, years: String?) -> some View {
        HStack(alignment: .center, spacing: 12) {
            if films > 0 {
                Engraved(Text("\(films)").font(Type.numbers(36)))
                    .lineLimit(1)
                    .fixedSize()
            }
            VStack(alignment: .leading, spacing: 3) {
                Engraved(Text("Every stub").font(Type.display(16)).tracking(Type.displayTracking(16)))
                Group {
                    if films > 0 {
                        let places = Text("\(cinemas)").font(Type.numbers(11)) + Text(cinemas == 1 ? " cinema" : " cinemas")
                        let span = years.map { Text("  ·  ") + Text($0).font(Type.numbers(11)) } ?? Text("")
                        Engraved(places + span, depth: 0.7)
                    } else {
                        Engraved(Text("Nothing kept yet"), depth: 0.7)
                    }
                }
                .font(Type.words(11))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: The card

    /// A slip of cream card, typed: the years in the mono, the counts under them. Shaded where the lips overhang it.
    private var card: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(LinearGradient(colors: [Ink.cream, Color(hex: 0xEDE5D2)], startPoint: .top, endPoint: .bottom))
            .overlay(alignment: .top) {
                LinearGradient(colors: [.black.opacity(0.2), .black.opacity(0)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 5)
            }
            .overlay {
                VStack(spacing: 2) {
                    switch typed {
                    case .every(let films, let cinemas, let years):
                        Text(years ?? "Empty")
                            .font(years == nil ? Type.words(19) : Type.numbers(19))
                            .foregroundStyle(Ink.ink)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                        if films > 0 {
                            counts(films, unit: films == 1 ? "stub" : "stubs", then: "\(cinemas)", cinemas == 1 ? "cinema" : "cinemas")
                        }
                    case .made(let name, let films, let years):
                        Text(name)
                            .font(Type.display(18))
                            .foregroundStyle(Ink.ink)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                        if films > 0, let years {
                            counts(films, unit: films == 1 ? "stub" : "stubs", then: years, nil)
                        } else {
                            Text("Nothing filed yet").font(Type.words(11)).foregroundStyle(Ink.grey)
                        }
                    case .blank:
                        HStack(spacing: 6) {
                            Image(systemName: "plus").font(.system(size: 13, weight: .medium))
                            Text("New drawer").font(Type.words(16))
                        }
                        .foregroundStyle(Ink.ink.opacity(0.55))
                    }
                }
                .padding(.horizontal, 8)
            }
    }

    /// "11 stubs · 9 cinemas", the numbers in the mono.
    private func counts(_ films: Int, unit: String, then figure: String, _ unit2: String?) -> some View {
        let first = Text("\(films)").font(Type.numbers(11))
        let second = Text(figure).font(Type.numbers(11))
        let line = unit2.map { Text("\(first) \(unit)  ·  \(second) \($0)") } ?? Text("\(first) \(unit)  ·  \(second)")
        return line
            .font(Type.words(11))
            .foregroundStyle(Ink.grey)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    private var spoken: String {
        switch typed {
        case .every(let films, let cinemas, let years):
            guard films > 0 else { return "Every stub, empty." }
            let span = years.map { ", " + $0.replacingOccurrences(of: "–", with: " to ") } ?? ""
            return "Every stub: \(films) \(films == 1 ? "stub" : "stubs"), \(cinemas) \(cinemas == 1 ? "cinema" : "cinemas")\(span)."
        case .made(let name, let films, _):
            return "\(name), a drawer: \(films == 0 ? "nothing filed yet" : "\(films) \(films == 1 ? "stub" : "stubs")")."
        case .blank:
            return "New drawer"
        }
    }

    private var hint: String {
        switch typed {
        case .every(let films, _, _): films == 0 ? "" : "Opens the season: the numbers behind the drawer."
        case .made: "Opens the drawer's season, where it can be renamed or taken out."
        case .blank: "Names a new drawer to file stubs in."
        }
    }

    /// The years the stubs were seen in: "2024–2026", "2025", or `nil` for an empty drawer. A stub without a date counts by
    /// the day it was kept.
    static func years(of stubs: [Stub]) -> String? {
        let calendar = Calendar.current
        let all = stubs.map { calendar.component(.year, from: $0.screenedAt ?? $0.createdAt) }
        guard let first = all.min(), let last = all.max() else { return nil }
        return first == last ? "\(first)" : "\(first)–\(last)"
    }
}

/// Letters cut into brass: the cut darker than the plate, its upper lip in shade and its lower lip catching the light from
/// the upper left. `depth` lightens a smaller line, cut less deep.
private struct Engraved: View {
    let text: Text
    var depth: Double = 1
    init(_ text: Text, depth: Double = 1) { self.text = text; self.depth = depth }
    var body: some View {
        text
            .foregroundStyle(Color(hex: 0x4A3416).opacity(0.62 + 0.26 * depth))
            .shadow(color: Color(hex: 0xF6E3AE).opacity(0.85 * depth), radius: 0, x: 0, y: 0.9)
            .shadow(color: Color.black.opacity(0.22 * depth), radius: 0, x: 0, y: -0.5)
    }
}

/// A brass rivet: domed, lit from the upper left.
private struct Rivet: View {
    var body: some View {
        Circle()
            .fill(RadialGradient(colors: [Color(hex: 0xFBE9BE), Color(hex: 0xC09450), Color(hex: 0x6E4F22)],
                                 center: UnitPoint(x: 0.32, y: 0.3), startRadius: 0, endRadius: 6))
            .overlay(Circle().strokeBorder(Color(hex: 0x5A3F18).opacity(0.55), lineWidth: 0.5))
            .frame(width: 8, height: 8)
            .shadow(color: .black.opacity(0.3), radius: 0.6, x: 0.4, y: 0.8)
    }
}

/// The label pressed: the card goes a shade into its holder, the brass darkens a breath, and the tap lands at contact.
private struct LabelPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(configuration.isPressed ? Motion.touchDown : Motion.stamp, value: configuration.isPressed)
            .sensoryFeedback(.impact(flexibility: .solid, intensity: 0.5), trigger: configuration.isPressed) { _, now in now }
    }
}
