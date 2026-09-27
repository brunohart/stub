import Testing
import Foundation
@testable import Stub

/// Every release gets an edition (ADR-015). These test the floor: the key a release is known by, the die its
/// composition is rolled with, and the edition the hash draws before and without the model.
struct EditionTests {
    @Test func oneReleaseOneKey() {
        let dune = Release.key(for: "Dune Part Two")
        #expect(dune == "dune part two")
        #expect(Release.key(for: "DUNE: PART TWO") == dune)
        #expect(Release.key(for: "Dune Part Two IMAX") == dune)
        #expect(Release.key(for: "Dune Part Two (IMAX) 2D") == dune, "every format after the title is stripped")
        #expect(Release.key(for: "  Dune   Part Two ") == dune)
        #expect(Release.key(for: "Amélie") == Release.key(for: "AMELIE"), "diacritics fold")
        #expect(Release.key(for: "Fast & Furious") == "fast and furious")
        #expect(Release.key(for: "La Chimera") != Release.key(for: "The Chimera"), "folded, not translated")
    }

    @Test func seedIsStable() {
        // FNV-1a of "the brutalist". Pinned: an edition that reprinted itself on relaunch would not be an edition.
        #expect(Release.seed(for: "the brutalist") == UInt64(0x915efa9ae0edb7b8))
    }

    @Test func diceIsSplitMix() {
        // The published SplitMix64 sequence for seed 1.
        var dice = Dice(seed: 1)
        let rolls = (0..<3).map { _ in dice.next() }
        #expect(rolls == [0x910a2dec89025cc1, 0xbeeb8da1658eec67, 0xf893a2eefb32555e])
        var again = Dice(seed: 42)
        for _ in 0..<500 {
            let u = again.unit()
            #expect(u >= 0 && u < 1)
        }
    }

    @Test func forksAreIndependent() {
        let base = Dice(seed: 7)
        var a = base.fork("rays"), b = base.fork("rays")
        let (ra, rb) = (a.next(), b.next())
        #expect(ra == rb, "the same part rolls the same")
        #expect(base.fork("rays").seed != base.fork("title").seed)
        var rolled = base
        _ = rolled.next(); _ = rolled.next()
        #expect(rolled.fork("rays").seed == base.fork("rays").seed, "a fork is from the seed, not from how far the die has rolled")
    }

    /// The floor for three titles, pinned. If this fails the vocabulary or the arithmetic moved, and every
    /// edition already printed would reprint itself: that is a new `Genome.version`, not a new expectation.
    @Test func floorIsPinned() {
        let brutalist = Genome.floor(for: "The Brutalist")
        #expect(brutalist.movement == .constructivist)
        #expect(brutalist.palette == .sand)
        #expect(brutalist.stock == .foil)
        #expect(brutalist.directedBy == .hash)
        #expect(brutalist.version == 1)

        let dune = Genome.floor(for: "DUNE PART TWO IMAX")
        #expect(dune.movement == .riso && dune.palette == .moss && dune.stock == .holographic)

        let pastLives = Genome.floor(for: "Past Lives")
        #expect(pastLives.movement == .blueprint && pastLives.palette == .ember && pastLives.stock == .foil)
    }

    @Test func vocabularyIsWhole() {
        #expect(Set(Genome.movements) == Set(Movement.allCases))
        #expect(Set(Genome.palettes) == Set(Palette.allCases))
        #expect(Set(Genome.stocks) == Set(Stock.allCases))
        #expect(Genome.movements.count == Movement.allCases.count, "no movement twice: the hash would favour it")
    }

    @Test func editionRoundTrips() throws {
        let edition = Genome.floor(for: "Perfect Days")
        let data = try JSONEncoder().encode(edition)
        #expect(try JSONDecoder().decode(Edition.self, from: data) == edition)
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 19, _ min: Int = 30) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    @Test func viewingsCountTheRelease() {
        let first = Stub(title: "Dune Part Two", screenedAt: date(2024, 3, 2))
        let second = Stub(title: "DUNE PART TWO IMAX", screenedAt: date(2024, 3, 22))
        let other = Stub(title: "Past Lives", screenedAt: date(2024, 3, 1))
        let drawer = [second, other, first]
        #expect(Copy.viewing(of: first, among: drawer) == 1)
        #expect(Copy.viewing(of: second, among: drawer) == 2)
        #expect(Copy.viewing(of: other, among: drawer) == 1)
        let counted = Copy.viewings(of: second, among: drawer)
        #expect(counted.viewing == 2 && counted.of == 2)
        #expect(Copy(stub: first, among: drawer).viewings == 2)
        #expect(Copy(title: "x", viewing: 2).viewingWords == "Second viewing")
        #expect(Copy(title: "x", viewing: 11).viewingWords == "Viewing 11")
    }

    @Test func copyPrintsWhatTheStubKnows() {
        let stub = Stub(title: "Past Lives", cinema: "Penthouse Cinema", screenedAt: date(2024, 4, 5, 20, 15),
                        screen: "Screen 3", seat: "K9", price: 12.5, currency: "NZD")
        let copy = Copy(stub: stub, viewing: 1)
        #expect(copy.time == "20:15")
        #expect(copy.screen == "3")
        #expect(copy.place == "Screen 3 · K9")
        #expect(copy.year == 2024)
        #expect(copy.message.hasPrefix("Past Lives\nPenthouse Cinema\n"))
        #expect(copy.message.hasSuffix("Viewing 1"))
        let midnight = Copy(stub: Stub(title: "Anora", screenedAt: date(2024, 11, 1, 0, 0)), viewing: 1)
        #expect(midnight.time == nil, "a date at midnight is a date without a time")
        #expect(Copy(stub: Stub(title: "Anora", screen: "IMAX"), viewing: 1).place == "IMAX")
    }
}

/// The feel of the stock: the arithmetic under the haptics, which the simulator cannot play.
struct TextureTests {
    @Test func perforationIsCrossedOnce() {
        #expect(Texture.crossesPerforation(from: Card.poster - 3, to: Card.poster + 3))
        #expect(Texture.crossesPerforation(from: Card.poster + 10, to: Card.poster - 1))
        #expect(!Texture.crossesPerforation(from: 100, to: 200), "a stroke across the poster is not the perforation")
        #expect(!Texture.crossesPerforation(from: Card.poster, to: Card.poster + 4), "starting on it is not crossing it")
    }

    @Test func paperIsDullAndMetalIsBright() {
        #expect(Stock.cotton.sharpness < Stock.coated.sharpness)
        #expect(Stock.coated.sharpness < Stock.foil.sharpness)
        #expect(Stock.cotton.grip > Stock.holographic.grip)
        for stock in Stock.allCases {
            #expect((0...1).contains(stock.sharpness) && (0...1).contains(stock.grip))
        }
    }
}
