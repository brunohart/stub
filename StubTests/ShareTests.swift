import Testing
import Foundation
import CoreGraphics
import AVFoundation
import SwiftUI
@testable import Stub

/// The share (brief §6.4). The risk the brief named first: that `ImageRenderer` draws the edition's shaders at all. The
/// still has depended on it since Day 21 without proof, and the clip is sixty of those a second.
@MainActor
struct ShareTests {
    private let copy = Copy(title: "La Chimera", cinema: "Cinéma du Panthéon", date: "24 MAR 2024", time: "20:30",
                            screen: "2", seat: "F12", price: "€12.50", year: 2024)

    private func composition(_ stock: Stock) -> Composition {
        var edition = Genome.floor(for: copy.title)
        edition.stock = stock
        return Composition(edition: edition, copy: copy)
    }

    private func render(_ view: some View) throws -> Pixels {
        let renderer = ImageRenderer(content: view.frame(width: Card.width, height: Card.height))
        renderer.scale = 1
        return Pixels(try #require(renderer.cgImage))
    }

    /// Lit and unlit differ: the stock's sheen (a `colorEffect`), the relief and the foil (`layerEffect`s) are all
    /// drawn. Unlit, a foil mark is its metal multiplied flat; lit, the foil shader shades it, and it is never the
    /// white shape the shader is handed.
    @Test func imageRendererDrawsTheShaders() async throws {
        try await EditionShaders.prepare()
        let c = composition(.foil)
        let light = Light(tilt: CGPoint(x: 0.3, y: -0.2))
        let lit = try render(EditionFace(composition: c, light: light))
        let flat = try render(EditionFace(composition: c, light: light).environment(\.editionLit, false))
        var differ = 0, whiteFoil = 0, foil = 0
        let foilMarks = c.poster.filter(\.foil).map(\.bounds)
        for y in stride(from: 4, to: lit.height - 4, by: 3) {
            for x in stride(from: 4, to: lit.width - 4, by: 3) {
                let a = lit.rgba(x, y), b = flat.rgba(x, y)
                if abs(a.0 - b.0) + abs(a.1 - b.1) + abs(a.2 - b.2) > 0.03 { differ += 1 }
                if foilMarks.contains(where: { $0.contains(CGPoint(x: x, y: y)) }) {
                    foil += 1
                    if a.0 > 0.98 && a.1 > 0.98 && a.2 > 0.98 { whiteFoil += 1 }
                }
            }
        }
        #expect(differ > 500, "lit and unlit are the same picture: the shaders were not drawn (\(differ) pixels differ)")
        #expect(foil == 0 || Double(whiteFoil) / Double(foil) < 0.2, "the foil came out as its bare white shape")
    }

    /// The clip is a movie: HEVC, the size of the card and its margin, as long as it was asked to be, and the light
    /// moves across it (its first frame is not its last).
    @Test func theClipIsAMovie() async throws {
        let c = composition(.holographic)
        let url = try await EditionClip(composition: c).render(seconds: 0.5, fps: 12)
        let asset = AVURLAsset(url: url)
        let track = try #require(try await asset.loadTracks(withMediaType: .video).first)
        let duration = try await asset.load(.duration).seconds
        #expect(abs(duration - 0.5) < 0.1, "\(duration) s")
        let size = try await track.load(.naturalSize)
        #expect(Int(size.width) == Int((Card.width + 2 * EditionClip.margin) * EditionClip.scale) / 2 * 2)
        let formats = try await track.load(.formatDescriptions)
        #expect(formats.first.map(CMFormatDescriptionGetMediaSubType) == kCMVideoCodecType_HEVC)
        let first = try #require(EditionClip.frame(c, at: 0)), last = try #require(EditionClip.frame(c, at: 1))
        #expect(Pixels(first).bytes != Pixels(last).bytes, "the card did not turn")
        try? FileManager.default.removeItem(at: url)
    }

    @Test func theTurnEasesAtBothEnds() {
        #expect(EditionClip.tilt(at: 0).x == -0.35)
        #expect(abs(EditionClip.tilt(at: 1).x - 0.35) < 1e-9)
        #expect(abs(EditionClip.tilt(at: 0.01).x - EditionClip.tilt(at: 0).x) < 0.001, "no jolt at the start")
    }
}
