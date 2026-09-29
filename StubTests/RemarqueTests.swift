import Testing
import Foundation
import CoreGraphics
@testable import Stub

/// After the proof (brief §6): the punch, a remarque for every viewing after the first, and the patina a card earns by
/// age. Both are the copy's, never the design's.
struct RemarqueTests {
    /// A full strip, the longest strip the card sets (a long title beside a price, a long cinema), and an empty one.
    private let copies = [
        Copy(title: "The Brutalist", cinema: "Embassy Theatre", date: "06 SEP 2026", time: "19:30", screen: "1", seat: "H12",
             price: "$18.50", year: 2026),
        Copy(title: "Everything Everywhere All at Once", cinema: "Lighthouse Cinema Cuba, Wellington Central",
             date: "24 MAR 2024", time: "20:30", screen: "IMAX", seat: "RANG F PLACE 12", price: "€12.50", year: 2024),
        Copy(title: "Anora"),
    ]

    private func edition(_ movement: Movement, _ title: String) -> Edition {
        var edition = Genome.floor(for: title)
        edition.movement = movement
        return edition
    }

    /// Test 8. For every movement and viewings 2 to 6, no punch touches a word on the strip, the Aztec code on the back,
    /// or the back's words, seen through the card; and viewing n has n − 1 punches, none on another.
    @Test(arguments: Movement.allCases)
    func punchesClearTheWords(_ movement: Movement) {
        for base in copies {
            for viewing in 2...6 {
                var copy = base
                copy.viewing = viewing
                copy.viewings = viewing
                let c = Composition(edition: edition(movement, copy.title), copy: copy)
                #expect(c.punches.count == viewing - 1, "\(movement) viewing \(viewing) of \(copy.title): \(c.punches.count) punches")
                let back = EditionBack.clearZones(for: copy, edition: c.edition).map(Remarque.mirror)
                for (i, punch) in c.punches.enumerated() {
                    #expect(punch.die == movement.punch)
                    for mark in c.strip {
                        #expect(!punch.bounds.intersects(mark.bounds), "\(movement) viewing \(viewing): punch \(i) on \(mark.shape)")
                    }
                    for zone in back {
                        #expect(!punch.bounds.intersects(zone), "\(movement) viewing \(viewing): punch \(i) on the back's \(zone)")
                    }
                    #expect(punch.centre.y > Card.poster + Punch.radius, "punches are in the strip, below the perforation")
                    for other in c.punches.dropFirst(i + 1) {
                        #expect(punch.centre.distance(to: other.centre) >= 2 * Punch.radius, "two punches in one hole")
                    }
                }
            }
        }
    }

    @Test func aFirstViewingIsNotPunched() {
        for movement in Movement.allCases {
            #expect(Composition(edition: edition(movement, "Anora"), copy: copies[0]).punches.isEmpty)
        }
    }

    /// The same viewing is punched in the same place on every phone: rolled from the release's seed, not the clock.
    @Test func punchesAreTheSameEveryTime() {
        var copy = copies[0]
        copy.viewing = 4
        let a = Composition(edition: edition(.deco, copy.title), copy: copy).punches
        let b = Composition(edition: edition(.deco, copy.title), copy: copy).punches
        #expect(a == b)
        #expect(Set(a.map(\.centre.x)).count == a.count, "three punches, three places")
    }

    /// The punch goes through both faces: seen from the back, the hole is where it was, mirrored about the long axis.
    @Test func theBackHasTheSameHolesMirrored() {
        let punch = Punch(die: .triangle, centre: CGPoint(x: 80, y: 470), degrees: 12)
        let front = punch.path(scale: 1, origin: .zero, mirrored: false).boundingRect
        let back = punch.path(scale: 1, origin: .zero, mirrored: true).boundingRect
        #expect(abs(back.midX - (Card.width - front.midX)) < 0.001)
        #expect(abs(back.midY - front.midY) < 0.001)
        #expect(abs(back.width - front.width) < 0.001)
        // Drawn at twice the size, in a card whose corner is not at the origin.
        let big = punch.path(scale: 2, origin: CGPoint(x: 10, y: 20), mirrored: false).boundingRect
        #expect(abs(big.midX - (10 + 2 * front.midX)) < 0.001 && abs(big.midY - (20 + 2 * front.midY)) < 0.001)
    }

    /// The ninth fixture: a second Dune Part Two, printed "IMAX". The format folds away, so it is the release's second
    /// viewing, and its card is punched once while the first's is not.
    @Test func theSecondDuneIsPunchedOnce() {
        let first = Stub(title: "Dune Part Two", screenedAt: Self.date(2024, 3, 14, 20, 45))
        let second = Stub(title: "DUNE PART TWO IMAX", screenedAt: Self.date(2024, 3, 30, 13, 10))
        let drawer = [second, first]
        let edition = Genome.floor(for: "Dune Part Two")
        #expect(Composition(edition: edition, copy: Copy(stub: first, among: drawer)).punches.isEmpty)
        let punched = Composition(edition: edition, copy: Copy(stub: second, among: drawer))
        #expect(punched.punches.count == 1)
        #expect(Remarque.spoken(punched.punches) == "punched once")
    }

    // MARK: - Patina

    /// Test 9. Age 0 changes nothing: no warmth, no wear, no foxing, for any release and any viewing. A date in the
    /// future and no date at all are age 0 too.
    @Test func patinaAtAgeZeroIsTheIdentity() {
        for title in ["The Brutalist", "La Chimera", "Anora"] {
            for viewing in 1...3 {
                let patina = Patina(age: 0, seed: Release.seed(for: Release.key(for: title)), viewing: viewing)
                #expect(patina.isIdentity)
                #expect(patina.warmth == 0 && patina.wear == 0 && patina.spots.isEmpty)
            }
        }
        #expect(Patina(age: -3, seed: 7).isIdentity)
        #expect(Patina.none.isIdentity)
        #expect(Patina.age(since: nil) == 0, "a stub with no date has no age: nothing invented")
        #expect(Patina.age(since: .now.addingTimeInterval(86_400 * 30)) == 0)
        #expect(Copy(title: "x").age == 0)
    }

    /// Foxing is rare, grows with age, and a spot that has come up never moves.
    @Test func foxingGrowsAndStays() {
        let seed = Release.seed(for: "the brutalist")
        #expect(Patina(age: 0.9, seed: seed).spots.isEmpty, "nothing in the first year")
        let young = Patina(age: 3, seed: seed), old = Patina(age: 9, seed: seed)
        #expect(!young.spots.isEmpty && old.spots.count > young.spots.count)
        #expect(Array(old.spots.prefix(young.spots.count)) == young.spots)
        #expect(Patina(age: 40, seed: seed).spots.count / 4 <= 7, "rare")
        #expect(Patina(age: 40, seed: seed) == Patina(age: Patina.oldest, seed: seed), "a card stops ageing at ten")
        #expect(Patina(age: 6, seed: seed, viewing: 2).spots != Patina(age: 6, seed: seed, viewing: 1).spots,
                "each copy foxes in its own places")
        #expect(old.warmth > young.warmth && old.wear > young.wear)
        let back = old.mirrored
        for i in stride(from: 0, to: old.spots.count, by: 4) {
            #expect(back.spots[i] == Float(Card.width) - old.spots[i] && back.spots[i + 1] == old.spots[i + 1])
        }
    }

    /// Counted in whole days from the night it was seen, so it changes only as the calendar does.
    @Test func ageIsCountedFromTheNight() {
        let now = Self.date(2030, 9, 29, 9, 0)
        let seen = Self.date(2024, 9, 29, 20, 0)
        let age = Patina.age(since: seen, now: now)
        #expect(abs(age - 6) < 0.01)
        #expect(Patina.age(since: seen, now: now.addingTimeInterval(3_600)) == age, "an hour later is the same day")
        #expect(Patina.age(since: Self.date(1990, 1, 1, 12, 0), now: now) == Patina.oldest)
        let stub = Stub(title: "Past Lives", screenedAt: .now.addingTimeInterval(-86_400 * 365.25 * 2 - 3_600))
        #expect(abs(Copy(stub: stub, viewing: 1).age - 2) < 0.01)
    }

    private static func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }
}
