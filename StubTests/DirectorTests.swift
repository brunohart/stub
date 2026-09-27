import Testing
import Foundation
@testable import Stub

/// The model art-directs from a closed vocabulary (ADR-015). These test the closing: the words it may use, the
/// check its answer passes on the way out, and the cache that keeps a printed edition printed.
struct DirectorTests {
    @Test func vocabularyIsTheGenome() {
        #expect(Vocabulary.movements == Genome.movements.map(\.rawValue))
        #expect(Vocabulary.palettes == Genome.palettes.map(\.rawValue))
        #expect(Vocabulary.stocks == Genome.stocks.map(\.rawValue))
        for word in Vocabulary.movements + Vocabulary.palettes + Vocabulary.stocks {
            #expect(Vocabulary.glossary.contains("\(word):"), "the glossary explains '\(word)'")
        }
    }

    @Test func rulesAreChecked() {
        #expect(EditionRules.judge(movement: "noir", palette: "smoke", stock: "foil") == .accepted(.noir, .smoke, .foil))
        #expect(EditionRules.judge(movement: " Deco ", palette: "NIGHT", stock: "holographic\n") == .accepted(.deco, .night, .holographic))
        #expect(EditionRules.judge(movement: "bauhaus", palette: "night", stock: "foil") == .rejected("movement 'bauhaus'"))
        #expect(EditionRules.judge(movement: "swiss", palette: "gold", stock: "foil") == .rejected("palette 'gold'"))
        #expect(EditionRules.judge(movement: "swiss", palette: "sand", stock: "vellum") == .rejected("stock 'vellum'"))
    }

    @Test func promptSaysOnlyWhatTheStubKnows() {
        if #available(iOS 26.0, *) {
            #expect(ArtDirector.prompt(title: "Dune Part Two", year: 2024, screen: "IMAX") == "Film: Dune Part Two\nSeen: 2024\nScreen: IMAX")
            #expect(ArtDirector.prompt(title: "Anora", year: nil, screen: "2") == "Film: Anora", "a screen number says nothing about a film")
        }
    }

    @Test func aPrintedEditionStaysPrinted() throws {
        let defaults = try #require(UserDefaults(suiteName: "edition-tests-\(UUID().uuidString)"))
        defer { EditionCache.clear(in: defaults) }
        #expect(EditionCache.all(in: defaults).isEmpty)
        var brutalist = Genome.floor(for: "The Brutalist")
        EditionCache.store(brutalist, in: defaults)
        brutalist.movement = .letterpress
        brutalist.directedBy = .model
        EditionCache.store(brutalist, in: defaults)
        EditionCache.store(Genome.floor(for: "Anora"), in: defaults)
        let printed = EditionCache.all(in: defaults)
        #expect(printed.count == 2, "one entry per release")
        #expect(printed["the brutalist"] == brutalist)
        #expect(printed["the brutalist"]?.seed == UInt64(0x915efa9ae0edb7b8), "the seed survives the round trip whole, past 2^53")
    }
}
