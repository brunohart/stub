import Testing
import Foundation
import CoreGraphics
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
