import Testing
import Foundation
import CoreGraphics
import UIKit
@testable import Stub

/// The film's key art (ADR-049): the window every movement opens for it, the poster laid into that window, and which of
/// TMDB's results is the film on the ticket.
struct KeyArtTests {
    private let titles = ["The Brutalist", "Anora", "Everything Everywhere All at Once", "Salt in the Orchard", "Glass Harbour",
                          "Perfect Days", "Dune Part Two", "Past Lives"]

    private func composition(_ movement: Movement, _ title: String) -> Composition {
        var edition = Genome.floor(for: title)
        edition.movement = movement
        return Composition(edition: edition, copy: Copy(title: title, cinema: "The Kestrel Picture House", year: 2026))
    }

    /// Every movement opens a window for the key art on every card, big enough to read as a picture, on the poster.
    @Test(arguments: Movement.allCases)
    func everyMovementOpensAWindow(_ movement: Movement) {
        for title in titles {
            let window = composition(movement, title).keyArt
            let b = window.bounds
            #expect(b.width >= 70 && b.height >= 70, "\(movement) '\(title)': \(b) is too small to read as a picture")
            #expect(b.midY < Card.poster, "\(movement) '\(title)': the window's centre is off the poster")
        }
    }

    /// Only a movement with no hero, no medallion, no letter of the hand's and no clear band presses the picture blind:
    /// the letterpress, under a long title.
    @Test func onlyTheLetterpressPressesBlind() {
        for movement in Movement.allCases where movement != .letterpress {
            let blind = titles.filter { composition(movement, $0).keyArt.blind }
            #expect(blind.isEmpty, "\(movement) presses \(blind) blind")
        }
    }

    /// A hero is a frame for the picture only if no words sit in it: the type would print over the film.
    @Test(arguments: Movement.allCases)
    func aHeroNeverHoldsWords(_ movement: Movement) {
        for title in titles {
            let c = composition(movement, title)
            guard c.keyArt.kind == .hero else { continue }
            for mark in c.poster {
                guard case .words(let w) = mark.shape else { continue }
                let centre = CGPoint(x: w.box.midX, y: w.box.midY)
                #expect(!c.keyArt.path.contains(centre), "\(movement) '\(title)': '\(w.text)' sits in the picture")
            }
        }
    }

    /// Deco's sun holds the year, so the picture is not in it: the poster fills the field behind the sunburst, its rings
    /// radiating from the sun.
    @Test func decoRadiatesFromItsSun() {
        for title in titles {
            let window = composition(.deco, title).keyArt
            #expect(window.kind == .field, "'\(title)': \(window.kind)")
            #expect(window.centre != nil, "'\(title)': the rings have no centre")
        }
    }

    /// The window is never a mark on the type plate, which would print over the picture and hide it.
    @Test(arguments: Movement.allCases)
    func theWindowIsNeverUnderTheType(_ movement: Movement) {
        for title in titles {
            let c = composition(movement, title)
            #expect(c.keyArt.layer != .type, "\(movement) '\(title)': the picture is on the type plate")
        }
    }

    /// The hand's letter is cut to the glyph the printer sets: centred on its advance, sitting on its baseline.
    @Test func theLetterSitsOnItsBaseline() throws {
        let words = Mark.Words(text: "H", face: .groteskExtraBold, size: 200, at: CGPoint(x: 160, y: 300), anchor: .center)
        let outline = try #require(KeyArtWindow.outline(of: words, turn: nil))
        let b = outline.boundingRect
        #expect(abs(b.maxY - 300) < 2, "the H stands on \(b.maxY), not the baseline")
        #expect(b.height > 120 && b.height < 170, "an H at 200 points is \(b.height) tall")
        #expect(abs(b.midX - 160) < 6, "the H is centred at \(b.midX)")
        #expect(outline.contains(CGPoint(x: b.minX + 8, y: b.midY)), "the H's stem is solid")
        #expect(!outline.contains(CGPoint(x: b.midX, y: b.minY + 8)), "the space between its stems is open")
    }

    /// The window is the edition's own, every time it is set: the same release lays its picture in the same place.
    @Test func theWindowIsTheReleasesOwn() {
        for movement in Movement.allCases {
            #expect(composition(movement, "Anora").keyArt == composition(movement, "Anora").keyArt)
        }
    }

    // MARK: Laying the poster

    private func poster(_ size: CGSize, focus: CGRect) -> Posters.Poster {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.gray.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return Posters.Poster(image: image, focus: focus)
    }

    /// The poster always covers the window, wherever its subject is, and is never zoomed past three times the cover.
    @Test(arguments: [CGRect(x: 0, y: 0, width: 1, height: 1), CGRect(x: 0.4, y: 0.25, width: 0.2, height: 0.2),
                      CGRect(x: 0.75, y: 0.05, width: 0.25, height: 0.3), CGRect(x: 0, y: 0.7, width: 0.3, height: 0.3)])
    func thePosterCoversItsWindow(_ focus: CGRect) {
        let p = poster(CGSize(width: 1000, height: 1500), focus: focus)
        for window in [CGRect(x: 40, y: 60, width: 160, height: 160), CGRect(x: 18, y: 120, width: 300, height: 110)] {
            let frame = KeyArt.frame(for: p, in: window)
            #expect(frame.contains(window.insetBy(dx: 0.01, dy: 0.01)), "\(focus) in \(window): \(frame) leaves the window bare")
            let cover = max(window.width / 1000, window.height / 1500)
            #expect(frame.width / 1000 <= cover * 3 + 0.0001)
        }
    }

    /// The subject sits in the middle of the window when the poster has room around it.
    @Test func theSubjectIsCentred() {
        let focus = CGRect(x: 0.4, y: 0.3, width: 0.2, height: 0.2)
        let p = poster(CGSize(width: 1000, height: 1500), focus: focus)
        let window = CGRect(x: 40, y: 60, width: 160, height: 160)
        let frame = KeyArt.frame(for: p, in: window)
        let subject = CGPoint(x: frame.minX + focus.midX * frame.width, y: frame.minY + focus.midY * frame.height)
        #expect(abs(subject.x - window.midX) < 0.5 && abs(subject.y - window.midY) < 0.5, "subject at \(subject)")
    }

    // MARK: Choosing TMDB's result

    private typealias Candidate = Posters.Candidate

    @Test func theTitleWordForWordWins() {
        let results = [
            Candidate(title: "Dune", original_title: "Dune", release_date: "2021-09-15", poster_path: "/a.jpg", popularity: 300),
            Candidate(title: "Dune: Part Two", original_title: "Dune: Part Two", release_date: "2024-02-27", poster_path: "/b.jpg", popularity: 200),
        ]
        #expect(Posters.choose(results, title: "Dune Part Two", seen: 2024)?.poster_path == "/b.jpg")
    }

    /// A remake and the original share a title; the year it was seen picks the one in cinemas then.
    @Test func theYearSeenPicksTheRelease() {
        let results = [
            Candidate(title: "Nosferatu", original_title: "Nosferatu", release_date: "1922-03-04", poster_path: "/old.jpg", popularity: 40),
            Candidate(title: "Nosferatu", original_title: "Nosferatu", release_date: "2024-12-25", poster_path: "/new.jpg", popularity: 30),
        ]
        #expect(Posters.choose(results, title: "Nosferatu", seen: 2025)?.poster_path == "/new.jpg")
        #expect(Posters.choose(results, title: "Nosferatu", seen: nil)?.poster_path == "/old.jpg", "without a year, the better known")
    }

    /// A film shown under its own title abroad is found by its original title.
    @Test func theOriginalTitleCounts() {
        let results = [
            Candidate(title: "The Zone of Interest", original_title: "The Zone of Interest", release_date: "2023-12-15", poster_path: "/z.jpg", popularity: 50),
            Candidate(title: "Anatomy of a Fall", original_title: "Anatomie d'une chute", release_date: "2023-08-23", poster_path: "/a.jpg", popularity: 40),
        ]
        #expect(Posters.choose(results, title: "Anatomie d'une chute", seen: 2023)?.poster_path == "/a.jpg")
    }

    @Test func noPosterNoChoice() {
        let results = [Candidate(title: "Anora", original_title: "Anora", release_date: "2024-10-18", poster_path: nil, popularity: 90)]
        #expect(Posters.choose(results, title: "Anora", seen: 2024) == nil)
        #expect(Posters.choose([], title: "Anora", seen: 2024) == nil)
    }
}
