import Testing
import Foundation
import SwiftUI
@testable import Stub

/// The press's studio (ADR-046): passes pulled and stamps pressed, kept with the proof, laid over the card in order.
struct StudioTests {
    private let brutalist = Genome.floor(for: "The Brutalist")

    private func copy(_ viewing: Int = 1, date: String = "06 SEP 2026") -> Copy {
        Copy(title: "The Brutalist", cinema: "Embassy Theatre", date: date, time: "19:30", screen: "1", seat: "H12", price: "$18.50",
             viewing: viewing, viewings: 2, year: 2026)
    }

    @Test func anActIsKeptWithTheProofAndSurvivesTheRoundTrip() throws {
        var proof = Proof(release: brutalist.release)
        proof.acts = [.pull(.discs, in: .secondary, from: CGPoint(x: 40, y: 120), to: CGPoint(x: 260, y: 220)),
                      .stamp(.seat, in: .ink, at: CGPoint(x: 240, y: 90))]
        let read = try Proof.decoder.decode(Proof.self, from: proof.json)
        #expect(read == proof)
        // A proof kept before there was a studio still reads.
        let old = Data(#"{"release":"the brutalist","takes":{},"version":2}"#.utf8)
        #expect(try Proof.decoder.decode(Proof.self, from: old).acts == nil)
    }

    @Test func actsAreLaidOverTheDrawingInOrderAsTheStudiosPart() {
        var proof = Proof(release: brutalist.release)
        proof.acts = [.stamp(.date, in: .primary, at: CGPoint(x: 160, y: 300))]
        let edition = brutalist.applying(proof)
        #expect(edition.directedBy == .you, "a card that was acted on is the person's proof")
        let c = Composition(edition: edition, copy: copy())
        let studio = c.poster.filter { $0.part == edition.movement.studio.id }
        #expect(!studio.isEmpty)
        #expect(c.poster.suffix(studio.count).allSatisfy { $0.part == edition.movement.studio.id }, "over everything else")
        #expect(edition.movement.parts.contains { $0.id == edition.movement.studio.id && !$0.turns })
    }

    @Test func aStampPrintsTheCopysOwnNight() {
        func words(_ c: Copy) -> [String] {
            Studio.marks([.stamp(.date, in: .ink, at: CGPoint(x: 100, y: 100))], copy: c, inks: brutalist.palette.inks,
                         field: .ground, title: c.title).compactMap { mark in
                if case .words(let w) = mark.shape { w.text } else { nil }
            }
        }
        #expect(words(copy(1)).contains("06 SEP 2026"))
        #expect(words(copy(2, date: "14 MAR 2027")).contains("14 MAR 2027"), "a second viewing's card stamps its own date")
    }

    @Test func everyActPrintsInTheEditionsOwnInks() {
        let acts: [Act] = Act.Screen.allCases.map { .pull($0, in: .primary, from: CGPoint(x: 30, y: 60), to: CGPoint(x: 280, y: 300)) }
            + Act.Stamp.allCases.map { .stamp($0, in: .secondary, at: CGPoint(x: 160, y: 200)) }
        let marks = Studio.marks(acts, copy: copy(), inks: brutalist.palette.inks, field: .ground, title: "The Brutalist")
        #expect(!marks.isEmpty)
        #expect(marks.allSatisfy { [.primary, .secondary, .ink, .light].contains($0.role) })
    }

    @Test func aStampIsNeverPressedLevelButAlwaysTheSameWay() {
        let a = Act.stamp(.admit, in: .ink, at: CGPoint(x: 120, y: 140))
        let b = Act.stamp(.admit, in: .ink, at: CGPoint(x: 120, y: 140))
        #expect(a == b)
        #expect(a.angle != 0 && abs(a.angle) <= 9)
    }

    @MainActor @Test func theLastActComesOffInOneStep() {
        // A press of its own: the shared one may hold another test's proof.
        let session = PressSession(title: "The Brutalist", copy: copy(),
                                   editions: Editions(defaults: UserDefaults(suiteName: "studio-\(UUID().uuidString)")!))
        session.stamp = .postmark
        session.stamp(at: CGPoint(x: 200, y: 120))
        session.pull(from: CGPoint(x: 30, y: 200), to: CGPoint(x: 290, y: 260))
        #expect(session.acts.map(\.kind) == [.stamp, .pull])
        session.takeOffLast()
        #expect(session.acts.map(\.kind) == [.stamp])
        session.takeOffLast()
        #expect(session.acts.isEmpty && session.proof.acts == nil)
        // A tap is not a pass.
        session.pull(from: CGPoint(x: 100, y: 100), to: CGPoint(x: 104, y: 103))
        #expect(session.acts.isEmpty)
    }
}
