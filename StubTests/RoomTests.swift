import Testing
import Foundation
import CoreGraphics
import RealityKit
import SwiftUI
@testable import Stub

/// The room's light (ADR-018). Placing the card on a table is a device test; what the simulator can prove is that the
/// card builds: the right size, a face, a back and a cut edge, the holes in its maps, and a normal map that is flat
/// where nothing is printed.
@MainActor
struct RoomTests {
    private let copy = Copy(title: "Dune Part Two", cinema: "The Roxy Cinema", date: "30 MAR 2024", time: "13:10",
                            screen: "1", seat: "G11", price: "$21.00", viewing: 2, viewings: 2, year: 2024)

    private func composition(_ stock: Stock) -> Composition {
        var edition = Genome.floor(for: copy.title)
        edition.stock = stock
        return Composition(edition: edition, copy: copy)
    }

    @Test(arguments: [Stock.cotton, .foil, .holographic])
    func theCardBuilds(_ stock: Stock) async throws {
        let c = composition(stock)
        let card = try await RoomCard.entity(for: c, back: EditionBack(composition: c, photo: nil, tilt: 1))
        let names = Set(card.children.flatMap(\.children).map(\.name))
        #expect(names == ["edge", "face", "back"])
        // Sixty-four millimetres by a hundred and two, four tenths thick, lying flat.
        let size = card.visualBounds(relativeTo: nil).extents
        #expect(abs(size.x - 0.064) < 0.0005, "width \(size.x)")
        #expect(abs(size.z - 0.1024) < 0.0005, "length \(size.z)")
        #expect(size.y < 0.001, "thickness \(size.y)")
        #expect(card.collision != nil, "a finger can move it")
    }

    /// The maps are the card's: its holes are holes, and where nothing is printed the surface is flat.
    @Test func theMapsCutTheHoles() throws {
        let c = composition(.foil)
        #expect(c.punches.count == 1)
        let maps = try RoomCard.draw(c, back: EditionBack(composition: c, photo: nil, tilt: 1))
        let front = Pixels(maps.front)
        #expect(front.width == Int(Card.width * RoomCard.scale))
        func alpha(at p: CGPoint) -> Double {
            front.rgba(Int(p.x * RoomCard.scale), Int(p.y * RoomCard.scale)).3
        }
        #expect(alpha(at: c.punches[0].centre) < 0.1, "the punch goes through")
        #expect(alpha(at: CGPoint(x: 1, y: 1)) < 0.1, "the corner is rounded off")
        #expect(alpha(at: CGPoint(x: Card.width / 2, y: Card.poster + 60)) > 0.9, "the strip is card")
        #expect(maps.foil != nil, "foil stock has a metallic map")

        // Flat ink, flat paper: straight up, (0.5, 0.5, 1) in the map.
        let blank = UIGraphicsImageRenderer(size: CGSize(width: 12, height: 12)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 12, height: 12))
        }
        let white = try #require(blank.cgImage)
        let flat = try #require(RoomCard.normalMap(Pixels(white), depth: 2, reach: 1))
        let (x, y, z, _) = Pixels(flat).rgba(6, 6)
        #expect(abs(x - 0.5) < 0.01 && abs(y - 0.5) < 0.01 && z > 0.99)
    }
}
