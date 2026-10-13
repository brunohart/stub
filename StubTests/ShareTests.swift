import Testing
import Foundation
import CoreGraphics
import AVFoundation
import SwiftUI
import UIKit
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

    /// The clip is a movie: HEVC, the size of the card, its margin and the watermark's band, as long as it was asked to be,
    /// and the light moves across it (its first frame is not its last).
    @Test func theClipIsAMovie() async throws {
        let c = composition(.holographic)
        let clip = EditionClip(composition: c, format: .card)
        let url = try await clip.render(seconds: 0.5, fps: 12)
        let asset = AVURLAsset(url: url)
        let track = try #require(try await asset.loadTracks(withMediaType: .video).first)
        let duration = try await asset.load(.duration).seconds
        #expect(abs(duration - 0.5) < 0.1, "\(duration) s")
        let size = try await track.load(.naturalSize)
        #expect(Int(size.width) == 772 && Int(size.height) == 1232, "\(size)")
        let formats = try await track.load(.formatDescriptions)
        #expect(formats.first.map(CMFormatDescriptionGetMediaSubType) == kCMVideoCodecType_HEVC)
        let first = try #require(clip.frame(at: 0)), last = try #require(clip.frame(at: 1))
        #expect(Pixels(first).bytes != Pixels(last).bytes, "the card did not turn")
        try? FileManager.default.removeItem(at: url)
    }

    /// The vertical clip is 9:16 at 1080 by 1920, what a Story plays without cropping, and the card and the watermark sit
    /// clear of the 250-pixel bands at the top and bottom that a Story draws its own controls over (BEDIP-221).
    @Test func theVerticalClipIsNineBySixteen() async throws {
        let c = composition(.foil)
        let clip = EditionClip(composition: c, format: .vertical)
        #expect(clip.pixels.width == 1080 && clip.pixels.height == 1920)
        let url = try await clip.render(seconds: 0.25, fps: 8)
        let track = try #require(try await AVURLAsset(url: url).loadTracks(withMediaType: .video).first)
        let size = try await track.load(.naturalSize)
        #expect(Int(size.width) == 1080 && Int(size.height) == 1920, "\(size)")
        try? FileManager.default.removeItem(at: url)

        // Everything that is not parchment, at the extreme of the turn, lies between the bands.
        let band = Int(EditionClip.Format.storyBand)
        for t in [0.0, 0.5, 1.0] {
            let frame = Pixels(try #require(clip.frame(at: t)))
            #expect(frame.width == 1080 && frame.height == 1920)
            let rows = inked(frame)
            let top = try #require(rows.first), bottom = try #require(rows.last)
            #expect(top > band, "the card reaches \(top) px from the top at t = \(t)")
            #expect(bottom < frame.height - band, "the watermark reaches \(frame.height - bottom) px from the bottom at t = \(t)")
        }
    }

    /// Every share carries the watermark, and there is no way to share without it: it is in the clip's every frame in both
    /// framings, legible by its relief (its shadow and its light both stand off the paper), and nothing else in the frame
    /// depends on it.
    @Test func theWatermarkIsAlwaysThere() throws {
        let c = composition(.cotton)
        for format in EditionClip.Format.allCases {
            for t in [0.0, 0.5, 1.0] {
                let tilt = EditionClip.tilt(at: t)
                let shared = Pixels(try #require(EditionClip(composition: c, format: format).frame(at: t)))
                let bare = Pixels(try #require(EditionClip.page(c, tilt: tilt, format: format, watermark: false)))
                let box = markBox(format)
                let paper = bare.rgba(2, 2)
                var darker = 0, lighter = 0, outside = 0
                for y in stride(from: 0, to: shared.height, by: 2) {
                    for x in stride(from: 0, to: shared.width, by: 2) {
                        let a = shared.rgba(x, y), b = bare.rgba(x, y)
                        let changed = abs(a.0 - b.0) + abs(a.1 - b.1) + abs(a.2 - b.2) > 0.02
                        if box.contains(CGPoint(x: x, y: y)) {
                            let l = a.0 + a.1 + a.2, p = paper.0 + paper.1 + paper.2
                            if l < p - 0.3 { darker += 1 }
                            if l > p + 0.06 { lighter += 1 }
                        } else if changed { outside += 1 }
                    }
                }
                #expect(darker > 30, "\(format) at t = \(t): the watermark's shadow is not there (\(darker))")
                #expect(lighter > 30, "\(format) at t = \(t): the watermark's light is not there (\(lighter))")
                #expect(outside == 0, "\(format): the watermark changed \(outside) pixels outside its own box")
            }
        }
        // The still carries it too: the still is the card-sized frame held at the still's light.
        #expect(EditionClip.Format.card.canvas.height == Card.height + EditionClip.margin + EditionClip.Format.markBand)
    }

    /// The watermark never fights the card: in every movement, across the palettes and the stocks, at both ends of the turn,
    /// nothing of the card reaches the watermark's box, and the tail of its shadow is within two per cent of the parchment
    /// there. Writes the eight movements' middle frames side by side to `build/shots/mark-movements.png` to be looked at.
    @Test func theWatermarkSitsOnBareParchment() throws {
        var sheet: [CGImage] = []
        for (i, movement) in Genome.movements.enumerated() {
            var edition = Genome.floor(for: copy.title)
            edition.movement = movement
            edition.palette = Genome.palettes[(i * 5) % Genome.palettes.count]
            edition.stock = Genome.stocks[i % Genome.stocks.count]
            let c = Composition(edition: edition, copy: copy)
            for format in EditionClip.Format.allCases {
                let box = markBox(format)
                for t in [0.0, 1.0] {
                    let frame = Pixels(try #require(EditionClip.page(c, tilt: EditionClip.tilt(at: t), format: format, watermark: false)))
                    let paper = frame.rgba(2, 2)
                    var darkest = 0.0
                    for y in stride(from: Int(box.minY), to: min(Int(box.maxY), frame.height), by: 2) {
                        for x in stride(from: Int(box.minX), to: Int(box.maxX), by: 2) {
                            let p = frame.rgba(x, y)
                            darkest = max(darkest, max(abs(p.0 - paper.0), abs(p.1 - paper.1), abs(p.2 - paper.2)))
                        }
                    }
                    #expect(darkest < 0.02, "\(movement) \(format) at t = \(t): something of the card under the watermark, \(darkest)")
                }
            }
            sheet.append(try #require(EditionClip(composition: c, format: .vertical).frame(at: 0.5)))
        }
        try Self.write(sheet, columns: 4, to: EvalTests.repoRoot.appendingPathComponent("build/shots/mark-movements.png"))
    }

    /// The watermark's box in pixels: wide enough for the ticket and the words, as tall as their relief.
    private func markBox(_ format: EditionClip.Format) -> CGRect {
        let centre = format.markCentre(in: format.canvas)
        let half = CGSize(width: format.markSize * 5.2, height: format.markSize * 0.66)
        return CGRect(x: (centre.x - half.width) * format.scale, y: (centre.y - half.height) * format.scale,
                      width: 2 * half.width * format.scale, height: 2 * half.height * format.scale)
    }

    /// Frames side by side at a third of their size, as a PNG.
    private static func write(_ images: [CGImage], columns: Int, to url: URL) throws {
        guard let first = images.first else { return }
        let w = first.width / 3, h = first.height / 3, gap = 12
        let rows = (images.count + columns - 1) / columns
        let size = CGSize(width: columns * w + (columns + 1) * gap, height: rows * h + (rows + 1) * gap)
        let renderer = UIGraphicsImageRenderer(size: size, format: { let f = UIGraphicsImageRendererFormat(); f.scale = 1; return f }())
        let data = renderer.pngData { ctx in
            UIColor.white.setFill(); ctx.fill(CGRect(origin: .zero, size: size))
            for (i, image) in images.enumerated() {
                let x = gap + (i % columns) * (w + gap), y = gap + (i / columns) * (h + gap)
                UIImage(cgImage: image).draw(in: CGRect(x: x, y: y, width: w, height: h))
            }
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url)
    }

    /// Rows of the frame that hold anything but bare parchment: the card, its shadow, the mark.
    private func inked(_ frame: Pixels) -> [Int] {
        let paper = frame.rgba(2, 2)
        return (0..<frame.height).filter { y in
            stride(from: 0, to: frame.width, by: 3).contains { x in
                let p = frame.rgba(x, y)
                return abs(p.0 - paper.0) + abs(p.1 - paper.1) + abs(p.2 - paper.2) > 0.06
            }
        }
    }

    @Test func theTurnEasesAtBothEnds() {
        #expect(EditionClip.tilt(at: 0).x == -0.35)
        #expect(abs(EditionClip.tilt(at: 1).x - 0.35) < 1e-9)
        #expect(abs(EditionClip.tilt(at: 0.01).x - EditionClip.tilt(at: 0).x) < 0.001, "no jolt at the start")
    }
}
