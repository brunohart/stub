import Foundation
import CoreGraphics

/// Patina: the surface a card earns by age (brief §6.2). It ages from the night it was seen. The stock warms, a
/// few rust spots of foxing come up in the paper, and the corners soften where a thumb has rubbed them. It is
/// surface, like the stock (DESIGN.md › Editions rule 3): nothing about the design changes.
///
/// A function of the copy's age and the release's seed, so it is the same on every phone and changes only as the
/// calendar does. Age 0 changes nothing: every term the `stock` shader multiplies by is zero and there are no spots.
struct Patina: Equatable, Sendable {
    /// Years since the night it was seen, 0 to `oldest`.
    let age: Double
    /// The foxing, in card points: x, y, radius and strength, four floats a spot, as the shader reads them.
    let spots: [Float]

    /// A card stops ageing at ten years: past that the stock would be all patina and no card.
    static let oldest = 10.0
    static let none = Patina(age: 0, seed: 0)

    /// The copy's patina. `seed` is the release's; each viewing's card foxes in its own places, `patina/<viewing>`,
    /// and a spot that has come up never moves: the spots are rolled in order and age only lets more of them show.
    init(age: Double, seed: UInt64, viewing: Int = 1) {
        let age = min(max(age, 0), Self.oldest)
        self.age = age
        var dice = Dice(seed: seed).fork("patina/\(viewing)")
        var spots: [Float] = []
        for _ in 0..<Self.foxing(at: age) {
            spots += [Float(dice.span(10, Card.width - 10)), Float(dice.span(10, Card.height - 10)),
                      Float(dice.span(1.1, 3.6)), Float(dice.between(0.35, 0.8))]
        }
        self.spots = spots
    }

    private init(age: Double, spots: [Float]) {
        self.age = age
        self.spots = spots
    }

    /// How many spots of foxing show at `age`: rare. None in the first year, about one every eighteen months after.
    static func foxing(at age: Double) -> Int {
        age < 1 ? 0 : min(7, Int((age - 1) / 1.5) + 1)
    }

    /// How far the stock has warmed toward yellow, 0 to about 0.4: quickly at first, then hardly at all.
    var warmth: Double { 0.42 * (1 - exp(-age / 4.5)) }

    /// How far the corners have been rubbed light, 0 to 0.55.
    var wear: Double { 0.55 * age / Self.oldest }

    /// Nothing to draw.
    var isIdentity: Bool { warmth == 0 && wear == 0 && spots.isEmpty }

    /// The same patina seen from the back: the foxing is in the paper, so it comes through the card, mirrored.
    var mirrored: Patina {
        var flipped = spots
        for i in stride(from: 0, to: flipped.count, by: 4) { flipped[i] = Float(Card.width) - flipped[i] }
        return Patina(age: age, spots: flipped)
    }

    /// Years from the night a stub was seen to `now`, counted in whole days so it changes only as the calendar does. A
    /// stub with no date has no age: nothing is invented (DESIGN.md › Editions rule 6).
    static func age(since screenedAt: Date?, now: Date = .now) -> Double {
        guard let screenedAt else { return 0 }
        let days = (now.timeIntervalSince(screenedAt) / 86_400).rounded(.down)
        return min(max(days / 365.25, 0), oldest)
    }
}
