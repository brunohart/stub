import Testing
import Foundation
import CoreGraphics
import SwiftUI
import UIKit
@testable import Stub

/// Every stub is its own (ADR-043). A later viewing of a release pulls a variant, the same drawing in its own inks, and
/// every copy is its own pull: each plate a little off the others, the stock's fibre its own.
struct VariantTests {
    private let dune = Genome.floor(for: "Dune Part Two")

    private func copy(_ viewing: Int, of viewings: Int = 3) -> Copy {
        Copy(title: "Dune Part Two", cinema: "The Roxy Cinema", date: "14 MAR 2024", time: "20:45", screen: "2", seat: "D4",
             price: "$21.00", viewing: viewing, viewings: viewings, year: 2024)
    }

    @Test func theFirstViewingIsTheEditionItself() {
        #expect(dune.pulled(viewing: 1) == dune)
        #expect(dune.pulled(viewing: 1).kind == "edition")
    }

    @Test func aLaterViewingPullsAVariantOnTheOtherGround() {
        let second = dune.pulled(viewing: 2)
        #expect(second.palette != dune.palette)
        #expect(second.palette.inks.groundIsLight != dune.palette.inks.groundIsLight, "the variant inverts the ground first")
        #expect(second.movement == dune.movement && second.stock == dune.stock && second.seed == dune.seed,
                "the drawing is the release's: only the inks are the viewing's")
        #expect(second.kind == "variant" && second.variant == 2)
    }

    @Test func noTwoViewingsShareInksUntilAllTwelveAreUsed() {
        for title in ["Dune Part Two", "The Brutalist", "Anora", "Salt in the Orchard"] {
            let edition = Genome.floor(for: title)
            let inks = (1...12).map { edition.pulled(viewing: $0).palette }
            #expect(Set(inks).count == 12, "\(title): \(inks)")
        }
    }

    @Test func aViewingsInksNeverChange() {
        for viewing in 2...6 {
            #expect(dune.pulled(viewing: viewing) == dune.pulled(viewing: viewing))
        }
        #expect(Genome.variants(of: dune.palette, seed: dune.seed) == Genome.variants(of: dune.palette, seed: dune.seed))
    }

    @Test func inksChosenAtThePressWin() {
        let proof = Proof(release: dune.release, palette: .chalk)
        let chosen = dune.applying(proof)
        #expect(chosen.inksChosen)
        #expect(chosen.pulled(viewing: 3).palette == .chalk)
        // A proof that chose nothing about the inks leaves the variant to come through.
        let taken = dune.applying(Proof(release: dune.release, stock: .cotton))
        #expect(!taken.inksChosen && taken.pulled(viewing: 2).palette == dune.pulled(viewing: 2).palette)
    }

    @Test func theCompositionPrintsTheViewingsInks() {
        let first = Composition(edition: dune, copy: copy(1)), second = Composition(edition: dune, copy: copy(2))
        #expect(first.edition.palette == dune.palette)
        #expect(second.edition.palette == dune.pulled(viewing: 2).palette)
        #expect(second.inks == dune.pulled(viewing: 2).palette.inks)
    }

    @Test func everyCopyIsItsOwnPull() {
        let first = Composition(edition: dune, copy: copy(1)), second = Composition(edition: dune, copy: copy(2))
        #expect(first.registration(.first) != second.registration(.first))
        #expect(first.paper != second.paper)
        // The same copy lands the same way every time it is looked at.
        #expect(first.registration(.second) == Composition(edition: dune, copy: copy(1)).registration(.second))
        for c in [first, second] {
            for (plate, reach) in [(Plate.first, 0.75), (.second, 0.75), (.type, 0.25)] {
                let r = c.registration(plate)
                #expect(abs(r.width) <= reach && abs(r.height) <= reach)
            }
            let foil = c.registration(nil)
            #expect(abs(foil.width) <= 0.33 && abs(foil.height) <= 0.33)
        }
    }

    /// Two viewings of one release, drawn: never the same card twice. Writes both to the temporary folder to be looked at.
    @MainActor @Test func twoViewingsAreNeverTheSameCard() async throws {
        try await EditionShaders.prepare()
        func render(_ c: Composition) throws -> (Pixels, UIImage) {
            let renderer = ImageRenderer(content: EditionFace(composition: c).frame(width: Card.width, height: Card.height))
            renderer.scale = 2
            let image = try #require(renderer.uiImage)
            renderer.scale = 1
            return (Pixels(try #require(renderer.cgImage)), image)
        }
        let (a, first) = try render(Composition(edition: dune, copy: copy(1)))
        let (b, second) = try render(Composition(edition: dune, copy: copy(2)))
        let folder = FileManager.default.temporaryDirectory
        try first.pngData()?.write(to: folder.appending(path: "variant-1.png"))
        try second.pngData()?.write(to: folder.appending(path: "variant-2.png"))
        var different = 0
        for y in stride(from: 0, to: Int(Card.height), by: 2) {
            for x in stride(from: 0, to: Int(Card.width), by: 2) {
                let p = a.rgba(x, y), q = b.rgba(x, y)
                if abs(p.0 - q.0) + abs(p.1 - q.1) + abs(p.2 - q.2) > 0.2 { different += 1 }
            }
        }
        let sampled = (Int(Card.width) / 2) * (Int(Card.height) / 2)
        #expect(Double(different) / Double(sampled) > 0.5, "\(different) of \(sampled) points differ")
    }
}
