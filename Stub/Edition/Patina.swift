import Foundation
import CoreGraphics

/// Patina: the surface a card earns (brief §6.2, ADR-032), by time and by hands. From the night it was seen the paper warms,
/// most at its edges, the way paper in a drawer tones from the outside in; after a couple of years a few small clusters
/// of foxing come up in it, soft and sepia. From being taken out and held, its corners rub light and a burnish comes up
/// where a thumb holds it, a patch of sheen that only shows as the light moves across it. It is surface, like the stock
/// (DESIGN.md › Editions rule 3): nothing about the design changes, and none of it is noise.
///
/// The time is a function of the copy's age and the release's seed, the same on every phone. The handling is this phone's
/// own count of how often the card has been taken out (`Handling`). A card never seen and never held changes nothing.
struct Patina: Equatable, Sendable {
    /// Years since the night it was seen, 0 to `oldest`.
    let age: Double
    /// How worn by hands, 0 to 1: quickly at first, then slowly.
    let handling: Double
    /// The foxing, in card points: x, y, radius and strength, four floats a speck, as the shader reads them.
    let spots: [Float]

    /// A card stops ageing at ten years: past that the stock would be all patina and no card.
    static let oldest = 10.0
    static let none = Patina(age: 0, seed: 0)

    /// The copy's patina. `seed` is the release's; each viewing's card foxes in its own places, `patina/<viewing>`, and a
    /// cluster that has come up never moves: they are rolled in order and age only lets more of them show. Each cluster is
    /// a lead speck and two small ones beside it, centred on whole points so a speck is a speck at any scale.
    init(age: Double, seed: UInt64, viewing: Int = 1, handled: Int = 0) {
        let age = min(max(age, 0), Self.oldest)
        self.age = age
        handling = 1 - exp(-Double(max(handled, 0)) / 25)
        var dice = Dice(seed: seed).fork("patina/\(viewing)")
        var spots: [Float] = []
        func on(_ v: CGFloat) -> Float { Float(v.rounded(.down) + 0.5) }
        for _ in 0..<Self.foxing(at: age) {
            let x = dice.span(16, Card.width - 16), y = dice.span(16, Card.height - 16)
            spots += [on(x), on(y), Float(dice.span(1.2, 2.0)), Float(dice.between(0.35, 0.5))]
            for _ in 0..<2 {
                spots += [on(x + dice.span(-4, 4)), on(y + dice.span(-4, 4)), Float(dice.span(0.9, 1.3)), Float(dice.between(0.28, 0.4))]
            }
        }
        self.spots = spots
    }

    private init(age: Double, handling: Double, spots: [Float]) {
        self.age = age
        self.handling = handling
        self.spots = spots
    }

    /// How many clusters of foxing show at `age`: none in the first two years, then one every two and a half, four at most.
    static func foxing(at age: Double) -> Int {
        age < 2 ? 0 : min(4, Int((age - 2) / 2.5) + 1)
    }

    /// How far the stock has warmed toward yellow, 0 to about 0.4: quickly at first, then hardly at all. The shader puts
    /// more of it at the edges.
    var warmth: Double { 0.42 * (1 - exp(-age / 4.5)) }

    /// How far the corners have been rubbed light, 0 to 0.55: by the years, or by hands, whichever has done more.
    var wear: Double { max(0.55 * age / Self.oldest, 0.45 * handling) }

    /// The sheen a thumb has burnished into the corner it holds, 0 to 0.6.
    var burnish: Double { 0.6 * handling }

    /// Nothing to draw.
    var isIdentity: Bool { warmth == 0 && wear == 0 && burnish == 0 && spots.isEmpty }

    /// The same patina seen from the back: the foxing is in the paper, so it comes through the card, mirrored.
    var mirrored: Patina {
        var flipped = spots
        for i in stride(from: 0, to: flipped.count, by: 4) { flipped[i] = Float(Card.width) - flipped[i] }
        return Patina(age: age, handling: handling, spots: flipped)
    }

    /// What the card has earned, in words, for the detail's history line: nil for a card with nothing to say.
    static func words(age: Double, handled: Int, foxed: Bool) -> String? {
        var parts: [String] = []
        if age >= 1 {
            let years = Int(age.rounded(.down))
            let span = years == 1 ? "a year" : "\(years) years"
            parts.append("\(span) since the night, the paper warming at its edges" + (foxed ? " and foxed in places" : ""))
        }
        if handled >= 5 { parts.append("taken out \(handled) times, its corners softened where a thumb goes") }
        return parts.isEmpty ? nil : parts.joined(separator: "; ")
    }

    /// Years from the night a stub was seen to `now`, counted in whole days so it changes only as the calendar does. A
    /// stub with no date has no age: nothing is invented (DESIGN.md › Editions rule 6).
    static func age(since screenedAt: Date?, now: Date = .now) -> Double {
        guard let screenedAt else { return 0 }
        let days = (now.timeIntervalSince(screenedAt) / 86_400).rounded(.down)
        return min(max(days / 365.25, 0), oldest)
    }
}

/// How often each card has been taken out and held on this phone (ADR-032): what wears its corners and burnishes the
/// corner a thumb holds. Counted once each time a stub's card is opened. Kept on the phone, not synced: hands are local.
enum Handling {
    static let key = "card.handled"

    static func count(for id: UUID, in defaults: UserDefaults = .standard) -> Int {
        (defaults.dictionary(forKey: key)?[id.uuidString] as? Int) ?? 0
    }

    static func touch(_ id: UUID, in defaults: UserDefaults = .standard) {
        var all = defaults.dictionary(forKey: key) ?? [:]
        all[id.uuidString] = ((all[id.uuidString] as? Int) ?? 0) + 1
        defaults.set(all, forKey: key)
    }
}
