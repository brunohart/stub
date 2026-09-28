import Testing
import Foundation
import CoreGraphics
import QuartzCore
import CoreHaptics
@testable import Stub

/// The press (ADR-016): every part rolled from its own die, a take as a fork of it, a proof as a difference laid over
/// the edition. The first test is the one the whole press depends on: turning a piece moves that piece and nothing else.
struct PressTests {
    /// Three copies to draw with: a short title, a long one, and one with almost nothing on it.
    private let copies = [
        Copy(title: "The Brutalist", cinema: "Embassy Theatre", date: "06 SEP 2026", time: "19:30", screen: "1", seat: "H12",
             price: "$18.50", year: 2026),
        Copy(title: "Everything Everywhere All at Once", cinema: "Cinéma du Panthéon", date: "24 MAR 2024", time: "20:30",
             screen: "IMAX", seat: "F12", price: "€12.50", viewing: 2, viewings: 3, year: 2024),
        Copy(title: "Anora"),
    ]

    private func edition(_ movement: Movement, _ title: String) -> Edition {
        var edition = Genome.floor(for: title)
        edition.movement = movement
        return edition
    }

    /// For every movement and every part the press can turn, takes 1 to 20: every mark outside the part is the mark
    /// take 0 drew. A frame is exempt for what hangs from it and nowhere else. `forksAreIndependent`, from the die to
    /// the drawing.
    @Test(arguments: Movement.allCases)
    func partsAreIndependent(_ movement: Movement) {
        for copy in copies {
            let base = edition(movement, copy.title)
            let first = Composition(edition: base, copy: copy)
            for part in movement.parts where part.turns {
                let exempt: Set<Part.ID> = part.kind == .frame
                    ? Set(movement.parts.filter { $0.hangs || $0.id == part.id }.map(\.id))
                    : [part.id]
                func outside(_ marks: [Mark]) -> [Mark] { marks.filter { !exempt.contains($0.part ?? "") } }
                var moved = false
                for take in 1...20 {
                    var turned = base
                    turned.takes = [part.id: take]
                    let c = Composition(edition: turned, copy: copy)
                    #expect(c.strip == first.strip, "\(part.id) take \(take) moved the strip")
                    #expect(outside(c.poster) == outside(first.poster), "\(part.id) take \(take) moved another part (\(copy.title))")
                    if c.poster != first.poster { moved = true }
                }
                #expect(moved, "\(part.id): twenty takes and not one draws anything new")
            }
        }
    }

    @Test(arguments: Movement.allCases)
    func everyMarkBelongsToADeclaredPart(_ movement: Movement) {
        let ids = Set(movement.parts.map(\.id))
        #expect(ids.count == movement.parts.count, "no part twice")
        #expect(movement.parts.filter { $0.kind == .frame }.count <= 1, "at most one frame")
        #expect(movement.parts.allSatisfy { $0.id.hasPrefix(movement.rawValue + "/") }, "ids are namespaced by movement")
        #expect(movement.parts.allSatisfy { $0.kind != .frame || !$0.hangs }, "a frame hangs from nothing")
        if movement.frame == nil {
            #expect(movement.parts.allSatisfy { !$0.hangs }, "nothing hangs where there is no frame")
        }
        for copy in copies {
            let c = Composition(edition: edition(movement, copy.title), copy: copy)
            for mark in c.poster {
                #expect(mark.part.map(ids.contains) == true, "a \(movement) mark belongs to no declared part")
            }
            #expect(c.strip.allSatisfy { $0.part == nil }, "the strip prints facts, and facts have no takes")
        }
    }

    /// A proof that differs in nothing gives back the edition it was laid over, director and all.
    @Test func takeZeroIsTheTitlesDrawing() {
        let brutalist = Genome.floor(for: "The Brutalist")
        let copy = copies[0]
        #expect(brutalist.applying(nil) == brutalist)
        #expect(brutalist.applying(Proof(release: brutalist.release)) == brutalist)
        let same = Proof(release: brutalist.release, movement: brutalist.movement, palette: brutalist.palette, stock: brutalist.stock,
                         takes: ["constructivist/disc": 0, "riso/disc": 7, "constructivist/title": 3])
        let applied = brutalist.applying(same)
        #expect(applied == brutalist, "take 0, another movement's takes and a set part's take change nothing")
        #expect(applied.directedBy == .hash)
        #expect(Composition(edition: applied, copy: copy).poster == Composition(edition: brutalist, copy: copy).poster)
        #expect(brutalist.dice("constructivist/disc", take: 0).seed == Dice(seed: brutalist.seed).fork("constructivist/disc").seed)

        let disc = brutalist.applying(Proof(release: brutalist.release, takes: ["constructivist/disc": 14]))
        #expect(disc.directedBy == .you)
        #expect(disc.takes == ["constructivist/disc": 14])
        #expect(disc.movement == brutalist.movement && disc.seed == brutalist.seed)
        #expect(brutalist.applying(Proof(release: "anora", takes: ["constructivist/disc": 14])) == brutalist, "another release's proof")
        #expect(brutalist.applying(Proof(release: brutalist.release, takes: ["constructivist/disc": 400])).takes["constructivist/disc"] == 99)
    }

    @Test func proofsRoundTrip() throws {
        let brutalist = Genome.floor(for: "The Brutalist")
        let proof = Proof(release: brutalist.release, movement: .riso, palette: .moss,
                          takes: ["riso/disc": 3, "riso/register": 11, "constructivist/disc": 14],
                          pulledAt: Date(timeIntervalSince1970: 1_790_000_000))
        let back = try Proof.decoder.decode(Proof.self, from: proof.json)
        #expect(back == proof)
        let copy = copies[1]
        #expect(Composition(edition: brutalist.applying(back), copy: copy).poster
                == Composition(edition: brutalist.applying(proof), copy: copy).poster)
        // A whole poster in about a hundred bytes, the constructivist takes kept for the way back.
        #expect(proof.json.count < 200, "\(proof.json.count) bytes")

        let defaults = try #require(UserDefaults(suiteName: "press-tests-\(UUID().uuidString)"))
        defer { ProofCache.clear(in: defaults) }
        ProofCache.store(proof, in: defaults)
        ProofCache.store(Proof(release: "anora", stock: .cotton), in: defaults)
        #expect(ProofCache.all(in: defaults)[brutalist.release] == proof)
        ProofCache.remove(release: "anora", in: defaults)
        #expect(ProofCache.all(in: defaults).count == 1)
    }

    /// Going back is deleting the proof: the edition underneath, its director included, as if nothing had happened.
    @MainActor @Test func goingBackIsExact() throws {
        let defaults = try #require(UserDefaults(suiteName: "press-tests-\(UUID().uuidString)"))
        defer { EditionCache.clear(in: defaults); ProofCache.clear(in: defaults) }
        let editions = Editions(defaults: defaults)
        var model = Genome.floor(for: "Perfect Days")
        model.movement = .letterpress
        model.directedBy = .model
        editions.store(model)
        #expect(editions.edition(for: "Perfect Days") == model)

        editions.pull(Proof(release: model.release, palette: .moss, takes: ["letterpress/ornament": 5]),
                      at: Date(timeIntervalSince1970: 1_790_000_000))
        let pulled = try #require(editions.edition(for: "PERFECT DAYS"))
        #expect(pulled.directedBy == .you && pulled.palette == .moss && pulled.takes == ["letterpress/ornament": 5])
        #expect(editions.underneath(for: "Perfect Days") == model, "nothing underneath is overwritten")
        #expect(editions.proof(for: "Perfect Days")?.pulledAt == Date(timeIntervalSince1970: 1_790_000_000))
        #expect(Editions(defaults: defaults).edition(for: "Perfect Days") == pulled, "a pulled proof survives a relaunch")

        editions.discardProof(release: model.release)
        #expect(editions.edition(for: "Perfect Days") == model)
        #expect(Editions(defaults: defaults).edition(for: "Perfect Days") == model)

        editions.pull(Proof(release: model.release, movement: .letterpress, takes: ["letterpress/ornament": 0]))
        #expect(editions.proof(for: "Perfect Days") == nil, "a proof that differs in nothing is going back")
    }

    /// Version 1 was retired, not frozen (ADR-016): a v1 edition keeps its movement, palette, stock and director and is
    /// drawn at version 2.
    @MainActor @Test func versionOneIsRedrawn() throws {
        let defaults = try #require(UserDefaults(suiteName: "press-tests-\(UUID().uuidString)"))
        defer { EditionCache.clear(in: defaults) }
        var old = Genome.floor(for: "Aftersun")
        old.version = 1
        old.directedBy = .model
        EditionCache.store(old, in: defaults)
        let redrawn = try #require(Editions(defaults: defaults).edition(for: "Aftersun"))
        #expect(redrawn.version == Genome.version)
        #expect(redrawn.movement == old.movement && redrawn.palette == old.palette && redrawn.stock == old.stock)
        #expect(redrawn.directedBy == .model)
        #expect(EditionCache.all(in: defaults)["aftersun"]?.version == Genome.version, "redrawn once, not on every launch")
    }

    @Test func proofsParseFromWords() {
        let brutalist = Genome.floor(for: "The Brutalist")
        let (disc, unread) = Proof.parsing("disc=14, bars=3", over: brutalist)
        #expect(disc.takes == ["constructivist/disc": 14, "constructivist/bars": 3])
        #expect(unread.isEmpty)
        let (riso, _) = Proof.parsing("register=4,movement=riso,inks=moss,disc=2", over: brutalist)
        #expect(riso.movement == .riso && riso.palette == .moss)
        #expect(riso.takes == ["riso/register": 4, "riso/disc": 2], "parts are looked up in the movement the proof ends on")
        let (_, refused) = Proof.parsing("title=3,disc=x,bars=100,stock=vellum,nonsense", over: brutalist)
        #expect(Set(refused) == ["stock=vellum", "nonsense", "title=3", "disc=x", "bars=100"])
    }

    /// The first marks of three fixtures at version 2, computed by `docs/editions/edition.js` under Node
    /// (`node docs/editions/golden.js`). The Swift and the mirror roll the same dice in the same order.
    @Test func goldensMatchTheMirror() throws {
        func poster(_ title: String, takes: [Part.ID: Int] = [:]) -> [Mark] {
            var edition = Genome.floor(for: title)
            edition.takes = takes
            let copy = Copy(title: title, time: "19:30", seat: "H12", year: 2024)
            return Composition(edition: edition, copy: copy).poster.filter {
                if case .words = $0.shape { return false }
                return $0.part != "blueprint/grid"
            }
        }
        func expect(_ mark: Mark, _ part: String, _ numbers: [Double], rot: Double? = nil, sourceLocation: SourceLocation = #_sourceLocation) {
            #expect(mark.part == part, sourceLocation: sourceLocation)
            let got: [Double] = switch mark.shape {
            case .rect(let r): [r.minX, r.minY, r.width, r.height]
            case .circle(let c, let radius): [c.x, c.y, radius]
            case .ring(let c, let radius, _, _): [c.x, c.y, radius]
            case .line(let a, let b, _, _): [a.x, a.y, b.x, b.y]
            case .halftone(_, _, let focus, let reach, _): [focus.x, focus.y, reach]
            default: []
            }
            #expect(got.count == numbers.count, sourceLocation: sourceLocation)
            for (g, n) in zip(got, numbers) { #expect(abs(g - n) < 1e-9, "\(part): \(g) against \(n)", sourceLocation: sourceLocation) }
            if let rot { #expect(abs((mark.turn?.degrees ?? .nan) - rot) < 1e-9, sourceLocation: sourceLocation) }
        }

        let brutalist = poster("The Brutalist")
        try #require(brutalist.count >= 4)
        expect(brutalist[0], "constructivist/diagonal", [-255, 144.111262193877, 840, 90.0183983919402], rot: 20.0451445337161)
        expect(brutalist[1], "constructivist/disc", [231, 80.2399794284542, 69.2216216036769])
        expect(brutalist[2], "constructivist/bars", [28.5342435858888, 250.129660585817, 242.795657140146, 7], rot: 20.0451445337161)
        expect(brutalist[3], "constructivist/bars", [45.0150069774047, 264.129660585817, 102.032033009733, 3], rot: 20.0451445337161)

        let fourteen = poster("The Brutalist", takes: ["constructivist/disc": 14])
        expect(fourteen[0], "constructivist/diagonal", [-255, 144.111262193877, 840, 90.0183983919402], rot: 20.0451445337161)
        expect(fourteen[1], "constructivist/disc", [231, 88.7510409432022, 77.1083972626525])
        expect(fourteen[2], "constructivist/bars", [28.5342435858888, 250.129660585817, 242.795657140146, 7], rot: 20.0451445337161)

        let dune = poster("Dune Part Two")
        try #require(dune.count >= 2)
        expect(dune[0], "riso/screen", [266.189666518939, 197.392981796804, 171.503191209866])
        expect(dune[1], "riso/disc", [216.515528193731, 161.055775116935, 113.03725880757])

        let pastLives = poster("Past Lives")
        try #require(pastLives.count >= 5)
        expect(pastLives[0], "blueprint/circle", [188.147275557841, 142.275198608154, 91.5831488699207])
        expect(pastLives[1], "blueprint/circle", [188.147275557841, 142.275198608154, 56.7815522993509])
        expect(pastLives[2], "blueprint/circle", [80.5641266879202, 142.275198608154, 295.730424427762, 142.275198608154])
        expect(pastLives[4], "blueprint/radius", [188.147275557841, 142.275198608154, 232.948546189874, 62.3982976499578])
    }
}

/// The press room's arithmetic (Day 24): in-betweens, the finger on the card, the words.
struct PressRoomTests {
    private let copy = Copy(title: "The Brutalist", cinema: "Embassy Theatre", date: "06 SEP 2026", time: "19:30", screen: "1",
                            seat: "H12", price: "$18.50", year: 2026)

    private func composition(_ movement: Movement, takes: [Part.ID: Int] = [:]) -> Composition {
        var edition = Genome.floor(for: copy.title)
        edition.movement = movement
        edition.takes = takes
        return Composition(edition: edition, copy: copy)
    }

    /// `between(a, b, 0)` is a's poster and `between(a, b, 1)` is b's, exactly; halfway, only the turned part moves.
    @Test(arguments: Movement.allCases)
    func inBetweensMeetTheirEnds(_ movement: Movement) {
        for part in movement.parts where part.turns {
            let a = composition(movement, takes: [part.id: 13])
            let b = composition(movement, takes: [part.id: 14])
            #expect(Composition.between(a, b, t: 0) == a.poster)
            #expect(Composition.between(a, b, t: 1) == b.poster)
            let half = Composition.between(a, b, t: 0.5)
            let exempt = part.kind == .frame ? Set(movement.parts.filter { $0.hangs || $0.id == part.id }.map(\.id)) : [part.id]
            #expect(half.filter { !exempt.contains($0.part ?? "") } == a.poster.filter { !exempt.contains($0.part ?? "") },
                    "\(part.id): halfway, a part that was not turned moved")
        }
    }

    @Test func aDiscGlides() throws {
        let a = composition(.constructivist, takes: ["constructivist/disc": 13])
        let b = composition(.constructivist, takes: ["constructivist/disc": 14])
        let half = Composition.between(a, b, t: 0.5)
        #expect(half.count == a.poster.count, "one disc, interpolated, not two cross-fading")
        let i = try #require(a.poster.firstIndex { $0.part == "constructivist/disc" })
        guard case .circle(let ca, let ra) = a.poster[i].shape, case .circle(let cb, let rb) = b.poster[i].shape,
              case .circle(let ch, let rh) = half[i].shape else { Issue.record("the disc is a circle"); return }
        #expect(abs(rh - (ra + rb) / 2) < 1e-9)
        #expect(abs(ch.y - (ca.y + cb.y) / 2) < 1e-9)
    }

    @Test func theHalftoneCrossFades() {
        let a = composition(.riso, takes: ["riso/screen": 1])
        let b = composition(.riso, takes: ["riso/screen": 2])
        let half = Composition.between(a, b, t: 0.25)
        let screens = half.filter { if case .halftone = $0.shape { true } else { false } }
        #expect(screens.count == 2)
        #expect(screens.map(\.opacity) == [0.75, 0.25])
    }

    /// A finger on the disc picks up the disc; on bare stock, nothing; on the strip, nothing.
    @Test func theFingerFindsThePart() throws {
        let c = composition(.constructivist)
        let disc = try #require(c.poster.first { $0.part == "constructivist/disc" })
        guard case .circle(let centre, let radius) = disc.shape else { Issue.record("the disc is a circle"); return }
        #expect(c.part(at: centre) == "constructivist/disc")
        #expect(c.part(at: CGPoint(x: centre.x + radius * 0.9, y: centre.y)) == "constructivist/disc")
        #expect(c.part(at: CGPoint(x: 165, y: Card.poster + 60)) == nil, "the strip has no parts")
        // The band's centre is covered by the title set in it: the title is on top, and it is set.
        let band = try #require(c.poster.first { $0.part == "constructivist/diagonal" })
        let centreOfBand = band.turn?.around ?? .zero
        #expect(["constructivist/title", "constructivist/diagonal"].contains(c.part(at: centreOfBand)))
        #expect(c.bounds(of: "constructivist/disc").map { $0.contains(centre) } == true)
    }

    @Test func aTurnedMarkIsHitWhereItIsDrawn() {
        let mark = Mark(.rect(CGRect(x: 0, y: -5, width: 100, height: 10)), .ink, .second,
                        turn: Mark.Turn(degrees: 90, around: .zero))
        // Turned a quarter clockwise about the origin, the bar runs down the y axis.
        #expect(mark.contains(CGPoint(x: 0, y: 50), slop: 0))
        #expect(!mark.contains(CGPoint(x: 50, y: 0), slop: 0))
    }

    @MainActor @Test func theSentenceSpellsTheTake() {
        #expect(PressSession.spelled(14) == "fourteen")
        #expect(PressSession.spelled(99) == "ninety-nine")
        let session = PressSession(title: "The Brutalist", copy: copy, editions: Editions(defaults: UserDefaults(suiteName: "press-room-\(UUID().uuidString)")!))
        #expect(session.sentence(at: 0) == "Touch a part of the card to turn it.")
        let disc = Parts.Constructivist.disc
        session.pickUp(disc)
        #expect(session.sentence(at: 0) == "The disc, as the title drew it.")
        #expect(session.sentence(at: 14) == "The disc. Take fourteen.")
        session.pickUp(Parts.Constructivist.diagonal)
        #expect(session.sentence(at: 3) == "The diagonal. Everything on it moves with it.")
    }

    /// Leaving the room keeps the work on the press; the detail goes on showing the last pulled proof.
    @MainActor @Test func theWorkStaysOnThePress() throws {
        let defaults = try #require(UserDefaults(suiteName: "press-room-\(UUID().uuidString)"))
        defer { EditionCache.clear(in: defaults); ProofCache.clear(in: defaults) }
        let editions = Editions(defaults: defaults)
        let floor = Genome.floor(for: "The Brutalist")
        editions.store(floor)
        let session = PressSession(title: "The Brutalist", copy: copy, editions: editions)
        session.pickUp(Parts.Constructivist.disc)
        session.settle(on: 14)
        #expect(editions.edition(for: "The Brutalist") == floor, "nothing is pulled until the lever is")
        #expect(Editions(defaults: defaults).pressProof(for: "The Brutalist").takes == ["constructivist/disc": 14])
        let again = PressSession(title: "The Brutalist", copy: copy, editions: Editions(defaults: defaults))
        #expect(again.take(of: Parts.Constructivist.disc) == 14, "the next visit continues where you stopped")
    }
}

/// Separations (Day 25): the finger carried back through each sheet's projection lands where it was drawn.
struct SeparationTests {
    @Test func aFingerIsCarriedBackOntoItsSheet() throws {
        for s in [CGFloat(0), 0.3, 0.8, 1] {
            for index in 0..<5 {
                for p in [CGPoint(x: 40, y: 60), CGPoint(x: 165, y: 264), CGPoint(x: 300, y: 500)] {
                    let drawn = Separation.project(p, index: index, separation: s)
                    let back = try #require(Separation.unproject(drawn, index: index, separation: s))
                    #expect(abs(back.x - p.x) < 1e-6 && abs(back.y - p.y) < 1e-6, "sheet \(index) at \(s)")
                }
            }
        }
        let flat = Separation.transform(index: 3, separation: 0)
        #expect(CATransform3DIsIdentity(flat), "at 0 the card is the card")
    }

    @Test func theSheetsLiftApart() {
        let centre = CGPoint(x: Card.width / 2, y: Card.height / 2)
        let bottom = Separation.project(centre, index: 0, separation: 1)
        let top = Separation.project(centre, index: 4, separation: 1)
        #expect(bottom.distance(to: top) > 60, "four spreads apart, the top sheet is well clear of the stock")
    }

    /// On the flat card the title covers the band's middle; apart, the band is reachable on its own sheet.
    @MainActor @Test func aBuriedPartIsReachableOnItsSheet() throws {
        let copy = Copy(title: "The Brutalist", year: 2026)
        let defaults = try #require(UserDefaults(suiteName: "separations-\(UUID().uuidString)"))
        defer { EditionCache.clear(in: defaults) }
        let editions = Editions(defaults: defaults)
        editions.store(Genome.floor(for: "The Brutalist"))
        let session = PressSession(title: "The Brutalist", copy: copy, editions: editions)
        let c = session.composition
        let band = try #require(c.poster.first { $0.part == "constructivist/diagonal" })
        let middle = band.turn?.around ?? .zero
        #expect(c.part(at: middle) == "constructivist/title", "flat, the title is on top of the band's middle")
        #expect(c.part(at: middle, on: .first) == "constructivist/diagonal")

        session.separation = 1
        let layers = Separation.layers(metallic: c.isMetallic)
        let first = try #require(layers.firstIndex(of: .first))
        // A finger where the band's middle is drawn on the first plate's sheet: the sheets above are lifted clear of it.
        let finger = Separation.project(middle, index: first, separation: 1)
        session.touch(at: finger)
        #expect(session.focus?.id == "constructivist/diagonal")
    }
}

/// The bench (Day 26): the genome's three choices, and the objects that offer them.
struct BenchTests {
    /// Choosing the edition's own movement, inks or stock is not a difference: the proof holds only what differs.
    @MainActor @Test func aChoiceIsKeptOnlyWhenItDiffers() throws {
        let defaults = try #require(UserDefaults(suiteName: "bench-\(UUID().uuidString)"))
        defer { EditionCache.clear(in: defaults); ProofCache.clear(in: defaults) }
        let editions = Editions(defaults: defaults)
        let floor = Genome.floor(for: "The Brutalist")
        editions.store(floor)
        let session = PressSession(title: "The Brutalist", copy: Copy(title: "The Brutalist"), editions: editions)
        session.choose(.riso)
        session.choose(.moss)
        session.choose(.cotton)
        #expect(session.proof.movement == .riso && session.proof.palette == .moss && session.proof.stock == .cotton)
        #expect(Editions(defaults: defaults).pressProof(for: "The Brutalist").movement == .riso, "left on the press")
        session.choose(floor.movement)
        session.choose(floor.palette)
        session.choose(floor.stock)
        #expect(session.proof.movement == nil && session.proof.palette == nil && session.proof.stock == nil)
        #expect(session.edition == floor)
        #expect(session.titlesMovement == .constructivist)
        #expect(session.modelsMovement == nil, "the hash drew it")
    }

    @Test func theFanFitsInTheHand() {
        let fan = FanLayout(focus: 150)
        let width: CGFloat = 402
        let centres = (0..<8).map { fan.centre($0, of: 8, width: width) }
        #expect(centres == centres.sorted(), "left to right")
        #expect(abs(centres[0] + centres[7] - width) < 1e-9, "symmetric about the middle")
        let half = fan.cardWidth * 1.18 / 2
        #expect(centres[0] - half > 0 && centres[7] + half < width, "no card off the edge of a phone")
        #expect(fan.closeness(150) == 1)
        #expect(fan.closeness(150 + fan.cardWidth * 3) < 0.01, "three cards away, no lift")
        #expect(FanLayout(focus: nil).closeness(150) == 0)
        #expect(FanLayout.angle(0, of: 8) == -FanLayout.angle(7, of: 8))
    }

    /// At the end of a flood every corner of the card is under the new ink, wherever it started. The shader's edge runs
    /// from `radius - soft` (fully inked) and the noise moves a point at most `wander` further out, so the farthest
    /// corner pushed back by the most the noise can manage must still be inside `radius - soft`.
    @Test func aFloodReachesEveryCorner() {
        let corners = [CGPoint(x: 0, y: 0), CGPoint(x: Card.width, y: 0), CGPoint(x: 0, y: Card.height), CGPoint(x: Card.width, y: Card.height)]
        for stock in Stock.allCases {
            let w = stock.wicking
            for origin in [CGPoint(x: 0, y: 0), CGPoint(x: Card.width / 2, y: Card.height / 2), CGPoint(x: 99, y: 148), CGPoint(x: Card.width, y: Card.height)] {
                let radius = FloodEffect.reach(from: origin, on: stock)
                for corner in corners {
                    #expect(corner.distance(to: origin) + w.wander <= radius - w.soft + 1e-9, "\(stock) from \(origin)")
                }
            }
        }
        #expect(Stock.cotton.wicking.soft > Stock.coated.wicking.soft, "cotton wicks wide and soft")
    }

    @Test func everyChoiceIsSpoken() {
        for movement in Movement.allCases { #expect(movement.spoken.hasSuffix(".")) }
        for stock in Stock.allCases { #expect(stock.feel.hasSuffix(".") && !stock.words.isEmpty) }
    }
}

/// The lever, the platen and the back (Day 27).
struct PullTests {
    /// A pulled proof, undone, is not pulled; redone, it is again. Shake, or three fingers.
    @MainActor @Test func aPullCanBeUndone() throws {
        let defaults = try #require(UserDefaults(suiteName: "pull-\(UUID().uuidString)"))
        defer { EditionCache.clear(in: defaults); ProofCache.clear(in: defaults) }
        let editions = Editions(defaults: defaults)
        editions.store(Genome.floor(for: "The Brutalist"))
        let session = PressSession(title: "The Brutalist", copy: Copy(title: "The Brutalist"), editions: editions)
        let undo = UndoManager()
        undo.groupsByEvent = false
        session.undoManager = undo

        undo.beginUndoGrouping()
        session.pickUp(Parts.Constructivist.disc)
        session.settle(on: 14)
        undo.endUndoGrouping()
        #expect(session.somethingToPull)
        #expect(session.sentence(at: 14) == "The disc. Take fourteen.")
        session.putDown()
        #expect(session.sentence(at: 0) == "Pull it when it is right.")

        undo.beginUndoGrouping()
        session.pull()
        undo.endUndoGrouping()
        #expect(editions.proof(for: "The Brutalist")?.takes == ["constructivist/disc": 14])
        #expect(editions.edition(for: "The Brutalist")?.directedBy == .you)
        #expect(!session.somethingToPull)
        #expect(session.pulls == 1)

        undo.undo()
        #expect(editions.proof(for: "The Brutalist") == nil, "the pull undone")
        undo.redo()
        #expect(editions.proof(for: "The Brutalist")?.takes == ["constructivist/disc": 14], "and done again")

        undo.undo()   // the pull
        undo.undo()   // the take
        #expect(session.proof.takes.isEmpty, "the take on the press undone too")
    }

    @Test func thePencilSaysWhatDiffers() throws {
        var edition = Genome.floor(for: "The Brutalist")
        #expect(Pencil(edition: edition) == nil, "only a proof is written on")
        edition = edition.applying(Proof(release: edition.release, takes: ["constructivist/bars": 3, "constructivist/disc": 14]))
        let pencil = try #require(Pencil(edition: edition))
        #expect(pencil.artistsProof)
        #expect(pencil.takes == "disc 14 · bars 3", "in the order the parts are drawn")
        #expect(pencil.spoken(signed: true) == "Signed, artist's proof, disc take fourteen, bars take three.")
        #expect(edition.colophon == "Constructivist, sand inks, foil on coated card. Artist's proof, pulled by you.")
        let inks = Genome.floor(for: "The Brutalist").applying(Proof(release: edition.release, palette: .moss))
        #expect(Pencil(edition: inks)?.takes == nil, "A/P alone when no take differs")
    }

    /// Kept once, in Application Support, as a drawing; redone, it is gone.
    @MainActor @Test func theSignatureIsKept() throws {
        let url = URL.temporaryDirectory.appending(path: "signature-\(UUID().uuidString)/Signature.drawing")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let book = Signatures(url: url)
        #expect(!book.isSigned)
        let fixture = Signatures.fixture()
        #expect(fixture.strokes.count == 3)
        book.keep(fixture)
        #expect(book.isSigned && book.image != nil)
        #expect(Signatures(url: url).drawing?.strokes.count == 3, "it survives a relaunch")
        book.redo()
        #expect(!book.isSigned)
        #expect(!Signatures(url: url).isSigned)
    }

    @Test func theLeverResistsAndGives() throws {
        #expect(LeverFeel.resistance(at: 0) == 0.1)
        #expect(abs(LeverFeel.resistance(at: 1) - 0.8) < 1e-6)
        #expect(LeverFeel.resistance(at: 0.5) < LeverFeel.resistance(at: 0.9))
        // The handle lags the finger a little, more so as it goes; it gives before a thumb runs out of screen.
        #expect(Lever.handle(for: 0) == 0)
        #expect(Lever.handle(for: 75) < 75 && Lever.handle(for: 75) > 60)
        let gives = (0...300).first { Lever.handle(for: CGFloat($0)) >= Lever.length * Lever.gives }
        #expect(gives.map { $0 > 150 && $0 < 180 } == true, "it gives after \(gives ?? -1) points of drag")
        #expect(abs(Lever.handle(for: 1000) - Lever.length) < 1e-9, "dragged on past the bottom, it stays at the bottom")
        let path = (0...2000).map { Lever.handle(for: CGFloat($0)) }
        #expect(zip(path, path.dropFirst()).allSatisfy { $0 <= $1 }, "it never comes back up while the finger goes down")
    }

    /// The platen's feel is an asset in the bundle, and it parses.
    @Test func thePlatenIsInTheBundle() throws {
        let url = try #require(LeverFeel.platen)
        _ = try CHHapticPattern(contentsOf: url)
    }
}
