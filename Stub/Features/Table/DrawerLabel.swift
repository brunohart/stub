import SwiftUI

/// The drawer's label (ADR-022): a brass holder of the kind screwed to a card-catalogue drawer, with a typed card slid
/// into it saying what the drawer holds: the years it spans, how many stubs, how many cinemas. It is the home screen's
/// name for itself, where the app's own name and a sentence used to be. Brass is a material, so it answers the light:
/// its sheen moves with the phone as the edition's foil does (one light, the phone's), and stays where it is under Reduce
/// Motion and in the simulator, which has no gyroscope. Pressed, the card goes a shade into its holder; it opens the season.
struct DrawerLabel: View {
    let summary: SeasonSummary
    /// The years the drawer spans, "2024–2026", or one year, or nothing for an empty drawer.
    let years: String?
    var open: () -> Void

    @State private var attitude = Attitude()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let size = CGSize(width: 264, height: 80)

    var body: some View {
        Button(action: open) {
            ZStack {
                plate
                card
                    .padding(.horizontal, 30)
                    .padding(.vertical, 11)
                HStack {
                    Rivet()
                    Spacer()
                    Rivet()
                }
                .padding(.horizontal, 11)
            }
            .frame(width: Self.size.width, height: Self.size.height)
        }
        .buttonStyle(LabelPress())
        .disabled(summary.films == 0)
        .onAppear { if !reduceMotion { attitude.start() } }
        .onDisappear { attitude.stop() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
        .accessibilityHint(summary.films == 0 ? "" : "Opens the season: the numbers behind the drawer.")
        .accessibilityAddTraits(summary.films == 0 ? [] : .isButton)
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
            // The window's lips: a darker step of brass round the card, where the plate is folded over to hold it.
            .overlay {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [Color(hex: 0x7C5A27), Color(hex: 0xE9D29C)], startPoint: .top, endPoint: .bottom),
                                  lineWidth: 1.5)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 9)
            }
            // The plate's own edge: lit along the top, shaded along the bottom.
            .overlay {
                shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.75), .black.opacity(0.35)], startPoint: .top, endPoint: .bottom),
                                   lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.28), radius: 0.8, x: 0, y: 1)
            .shadow(color: Color(hex: 0x3B2A12).opacity(0.18), radius: 7, x: 2, y: 6)
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
                    Text(years ?? "Empty")
                        .font(years == nil ? Type.words(19) : Type.numbers(19))
                        .foregroundStyle(Ink.ink)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    if summary.films > 0 {
                        let films = Text("\(summary.films)").font(Type.numbers(11))
                        let cinemas = Text("\(summary.cinemas.count)").font(Type.numbers(11))
                        Text("\(films) \(summary.films == 1 ? "stub" : "stubs")  ·  \(cinemas) \(summary.cinemas.count == 1 ? "cinema" : "cinemas")")
                            .font(Type.words(11))
                            .foregroundStyle(Ink.grey)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .padding(.horizontal, 8)
            }
    }

    private var spoken: String {
        guard summary.films > 0 else { return "The drawer, empty." }
        let span = years?.replacingOccurrences(of: "–", with: " to ") ?? ""
        return "The drawer: \(span), \(summary.films) \(summary.films == 1 ? "stub" : "stubs"), "
            + "\(summary.cinemas.count) \(summary.cinemas.count == 1 ? "cinema" : "cinemas")."
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
