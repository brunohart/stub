import Testing
import Foundation
import CoreGraphics
import SwiftUI
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

    /// The patina reaches what is printed (2026-09-30). Until then it lived in the stock under the plates, and a spot of
    /// foxing that came up under a band of ink, or a corner the ink covered, stayed as new. Every spot that lands on ink
    /// in any of the eight movements now stains it, and ink on a rubbed corner is worn through toward the paper under it.
    @MainActor @Test func theInkAgesWithThePaper() async throws {
        func render(_ c: Composition, printed: Int = Plate.foil) throws -> Pixels {
            let renderer = ImageRenderer(content: EditionFace(composition: c, printed: printed).frame(width: Card.width, height: Card.height))
            renderer.scale = 1
            return Pixels(try #require(renderer.cgImage))
        }
        typealias RGBA = (Double, Double, Double, Double)
        func luma(_ p: RGBA) -> Double { 0.299 * p.0 + 0.587 * p.1 + 0.114 * p.2 }
        func apart(_ a: RGBA, _ b: RGBA) -> Double { abs(a.0 - b.0) + abs(a.1 - b.1) + abs(a.2 - b.2) }
        // SwiftUI compiles a shader the first time it is used, and a render made before that draws the layer without it:
        // the first run of this test counted differently from the second.
        try await EditionShaders.prepare()
        var inkedSpots = 0, stained = 0, inkedCorners = 0, worn = 0
        let w = Int(Card.width), h = Int(Card.height)
        for movement in Movement.allCases {
            var young = copies[0], old = copies[0]
            young.age = 0
            old.age = Patina.oldest
            let e = edition(movement, "The Brutalist")
            let new = Composition(edition: e, copy: young), aged = Composition(edition: e, copy: old)
            let bare = try render(new, printed: 0), inked = try render(new)
            let paper = try render(aged, printed: 0), card = try render(aged)
            for i in stride(from: 0, to: aged.patina.spots.count, by: 4) {
                let x = Int(aged.patina.spots[i]), y = Int(aged.patina.spots[i + 1]), r = Int(aged.patina.spots[i + 2].rounded(.up))
                // Foil is metal, and foxing never comes through it.
                let foil = aged.isMetallic && aged.poster.contains { $0.foil && $0.bounds.insetBy(dx: -4, dy: -4).contains(CGPoint(x: x, y: y)) }
                guard !foil, apart(inked.rgba(x, y), bare.rgba(x, y)) > 0.25 else { continue }
                // Only a spot under opaque ink proves anything: through a halftone or a multiplied plate the stock's own
                // foxing shows anyway. A neighbour clear of the spot in the same ink that shows no age at all (not even
                // the stock's warmth) is opaque ink, and so is this.
                let opaque = [(3 * r, 0), (-3 * r, 0), (0, 3 * r), (0, -3 * r)].contains { dx, dy in
                    let nx = x + dx, ny = y + dy
                    guard nx > 12, ny > 12, nx < w - 12, ny < h - 12 else { return false }
                    return apart(inked.rgba(nx, ny), inked.rgba(x, y)) < 0.03 && apart(card.rgba(nx, ny), inked.rgba(nx, ny)) < 0.01
                }
                guard opaque else { continue }
                inkedSpots += 1
                if luma(card.rgba(x, y)) < luma(inked.rgba(x, y)) * 0.95 { stained += 1 }
            }
            for (x, y) in [(4, 4), (w - 5, 4), (4, h - 5), (w - 5, h - 5)] {
                guard apart(inked.rgba(x, y), bare.rgba(x, y)) > 0.25 else { continue }
                inkedCorners += 1
                if apart(card.rgba(x, y), paper.rgba(x, y)) < apart(inked.rgba(x, y), bare.rgba(x, y)) * 0.8 { worn += 1 }
            }
        }
        #expect(inkedSpots > 0, "no spot of foxing landed on opaque ink in eight movements, so this proves nothing")
        #expect(stained == inkedSpots, "\(stained) of \(inkedSpots) spots on opaque ink stained it")
        #expect(worn == inkedCorners, "\(worn) of \(inkedCorners) inked corners were worn")
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
