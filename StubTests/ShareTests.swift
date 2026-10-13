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

    /// The clip is a movie: HEVC, the size of the card and its margin, as long as it was asked to be, and the light
    /// moves across it (its first frame is not its last). Day 30's framing, unmarked, is exactly Day 30's size.
    @Test func theClipIsAMovie() async throws {
        let c = composition(.holographic)
        let clip = EditionClip(composition: c, format: .card, marked: false)
        let url = try await clip.render(seconds: 0.5, fps: 12)
        let asset = AVURLAsset(url: url)
        let track = try #require(try await asset.loadTracks(withMediaType: .video).first)
        let duration = try await asset.load(.duration).seconds
        #expect(abs(duration - 0.5) < 0.1, "\(duration) s")
        let size = try await track.load(.naturalSize)
        #expect(Int(size.width) == 772 && Int(size.height) == 1168, "\(size)")
        let formats = try await track.load(.formatDescriptions)
        #expect(formats.first.map(CMFormatDescriptionGetMediaSubType) == kCMVideoCodecType_HEVC)
        let first = try #require(clip.frame(at: 0)), last = try #require(clip.frame(at: 1))
        #expect(Pixels(first).bytes != Pixels(last).bytes, "the card did not turn")
        try? FileManager.default.removeItem(at: url)
    }

    /// The vertical clip is 9:16 at 1080 by 1920, what a Story plays without cropping, and the card and the mark sit clear
    /// of the 250-pixel bands at the top and bottom that a Story draws its own controls over (BEDIP-221).
    @Test func theVerticalClipIsNineBySixteen() async throws {
        let c = composition(.foil)
        let clip = EditionClip(composition: c, format: .vertical, marked: true)
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
            #expect(bottom < frame.height - band, "the mark reaches \(frame.height - bottom) px from the bottom at t = \(t)")
        }
    }

    /// The mark is there when it is on and gone when it is off, and nothing else in the frame changes with it: the setting
    /// is the person's, and on until they say otherwise.
    @Test func theMarkCanBeTurnedOff() throws {
        let c = composition(.cotton)
        for format in EditionClip.Format.allCases {
            let on = Pixels(try #require(EditionClip(composition: c, format: format, marked: true).frame(at: 0.5)))
            let offClip = EditionClip(composition: c, format: format, marked: false)
            let off = Pixels(try #require(offClip.frame(at: 0.5)))
            // The mark's own box, in pixels: the only place the two frames may differ.
            let centre = format.markCentre(in: format.canvas(marked: true))
            let box = CGRect(x: (centre.x - 60) * format.scale, y: (centre.y - 12) * format.scale, width: 120 * format.scale, height: 24 * format.scale)
            var inMark = 0
            for y in stride(from: Int(box.minY), to: min(Int(box.maxY), on.height), by: 1) {
                for x in stride(from: Int(box.minX), to: Int(box.maxX), by: 1) {
                    let a = on.rgba(x, y)
                    if a.0 < 0.6 { inMark += 1 }
                }
            }
            #expect(inMark > 40, "\(format): no mark under the card (\(inMark) inked pixels)")
            if format == .vertical {
                // Same frame, same size: the mark is the only difference.
                var outside = 0
                for y in stride(from: 0, to: on.height, by: 4) where !(Int(box.minY)...Int(box.maxY)).contains(y) {
                    for x in stride(from: 0, to: on.width, by: 4) where on.rgba(x, y) != off.rgba(x, y) { outside += 1 }
                }
                #expect(outside == 0, "turning the mark off changed \(outside) pixels outside it")
                let offInMark = (Int(box.minY)..<Int(box.maxY)).reduce(0) { n, y in
                    n + (Int(box.minX)..<Int(box.maxX)).filter { off.rgba($0, y).0 < 0.6 }.count
                }
                #expect(offInMark == 0, "the mark is still there when it is off")
            } else {
                #expect(off.height == 1168, "unmarked, the card-sized clip is Day 30's: \(off.height)")
            }
        }
        // The setting: on when nothing has been said, off once the person turns it off.
        let defaults = try #require(UserDefaults(suiteName: "share-mark-test"))
        defaults.removePersistentDomain(forName: "share-mark-test")
        #expect(ShareMark.isOn(in: defaults))
        defaults.set(false, forKey: ShareMark.key)
        #expect(!ShareMark.isOn(in: defaults))
        defaults.removePersistentDomain(forName: "share-mark-test")
    }

    /// The mark never fights the card: in every movement, across the palettes and the stocks, at both ends of the turn,
    /// nothing of the card reaches the mark's box, and the tail of its shadow is within two per cent of the parchment
    /// there, so the mark is the same small words on bare paper whatever was printed above it. Writes the eight
    /// movements' middle frames, marked, side by side to `build/shots/mark-movements.png` to be looked at.
    @Test func theMarkSitsOnBareParchment() throws {
        var sheet: [CGImage] = []
        for (i, movement) in Genome.movements.enumerated() {
            var edition = Genome.floor(for: copy.title)
            edition.movement = movement
            edition.palette = Genome.palettes[(i * 5) % Genome.palettes.count]
            edition.stock = Genome.stocks[i % Genome.stocks.count]
            let c = Composition(edition: edition, copy: copy)
            for format in EditionClip.Format.allCases {
                // Measured unmarked, on the marked frame's canvas: what would be under the mark if it were not there.
                var bare = EditionClip(composition: c, format: format, marked: false)
                if format == .card { bare = EditionClip(composition: c, format: .card, marked: true) }
                let centre = format.markCentre(in: format.canvas(marked: true))
                let box = CGRect(x: (centre.x - 48) * format.scale, y: (centre.y - 9) * format.scale,
                                 width: 96 * format.scale, height: 18 * format.scale)
                for t in [0.0, 1.0] {
                    let frame = Pixels(try #require(format == .card ? Self.withoutMark(bare, at: t) : bare.frame(at: t)))
                    let paper = frame.rgba(2, 2)
                    var darkest = 0.0
                    for y in stride(from: Int(box.minY), to: min(Int(box.maxY), frame.height), by: 2) {
                        for x in stride(from: Int(box.minX), to: Int(box.maxX), by: 2) {
                            let p = frame.rgba(x, y)
                            darkest = max(darkest, max(abs(p.0 - paper.0), abs(p.1 - paper.1), abs(p.2 - paper.2)))
                        }
                    }
                    #expect(darkest < 0.02, "\(movement) \(format) at t = \(t): something of the card under the mark, \(darkest)")
                }
            }
            sheet.append(try #require(EditionClip(composition: c, format: .vertical, marked: true).frame(at: 0.5)))
        }
        try Self.write(sheet, columns: 4, to: EvalTests.repoRoot.appendingPathComponent("build/shots/mark-movements.png"))
    }

    /// The card-sized frame's marked canvas with the mark left off: its band is there, its words are not.
    @MainActor
    private static func withoutMark(_ clip: EditionClip, at t: Double) -> CGImage? {
        let tilt = EditionClip.tilt(at: t)
        let canvas = clip.canvas
        let page = ZStack {
            Ink.paper
            EditionFace(composition: clip.composition, light: Light(tilt: tilt))
                .rotation3DEffect(.degrees(Double(tilt.x) * 11), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
                .rotation3DEffect(.degrees(Double(-tilt.y) * 11), axis: (x: 1, y: 0, z: 0), perspective: 0.45)
                .shadow(color: .black.opacity(0.18), radius: 12, x: 6 - tilt.x * 8, y: 10 - tilt.y * 8)
                .position(clip.format.cardCentre(in: canvas))
        }
        .frame(width: canvas.width, height: canvas.height)
        let renderer = ImageRenderer(content: page)
        renderer.scale = clip.format.scale
        return renderer.cgImage
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
