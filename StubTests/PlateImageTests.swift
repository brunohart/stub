import Testing
import Foundation
import CoreGraphics
import ImageIO
import UIKit
@testable import Stub

/// The plate comes back upright, sized to its frame, and decoded once per frame.
struct PlateImageTests {
    /// A landscape buffer tagged EXIF 6 is how a phone stores a portrait photograph. It must come back portrait.
    @Test func appliesTheOrientation() throws {
        let data = try #require(Self.jpeg(width: 400, height: 300, orientation: 6))
        let cg = try #require(PlateImage.decode(data, maxPixelSize: 4032))
        #expect(cg.width == 300 && cg.height == 400)
    }

    @Test func capsTheLongestSideAndNeverUpscales() throws {
        let data = try #require(Self.jpeg(width: 4000, height: 1000, orientation: 1))
        let small = try #require(PlateImage.decode(data, maxPixelSize: 1200))
        #expect(max(small.width, small.height) == 1200)
        let whole = try #require(PlateImage.decode(data, maxPixelSize: 8000))
        #expect(whole.width == 4000 && whole.height == 1000)
    }

    @Test func readsTheUprightSizeFromTheHeader() throws {
        let data = try #require(Self.jpeg(width: 400, height: 300, orientation: 6))
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let size = try #require(PlateImage.uprightSize(of: source))
        #expect(size.width == 300 && size.height == 400)
    }

    /// Decoded no smaller than the frame draws it, whichever side binds.
    @Test func sizesToWhatTheFrameShows() {
        let card = PlateFrame.card
        // A ticket, 2.3:1: the card's width binds.
        #expect(card.longestSide(width: 2400, height: 1043) == 1200)
        // A portrait photograph fills a square card: its width is the card's, its height a third more.
        #expect(card.longestSide(width: 3024, height: 4032) == 1600)
        // Flatter than 2.6:1, it fills the card's height and runs past its width.
        #expect(card.longestSide(width: 3200, height: 1000) == 1477)
        // The detail fits the width: a tall crop keeps every pixel the width can show.
        #expect(PlateFrame.detail.longestSide(width: 800, height: 2000) == 3300)
    }

    /// The card's body runs on every touch-down. Only the first run may touch the photograph.
    @Test @MainActor func decodesOncePerFrame() throws {
        let data = try #require(Self.jpeg(width: 800, height: 400, orientation: 1))
        let id = UUID()
        var reads = 0
        func read() -> Data? { reads += 1; return data }
        let first = PlateImage.image(for: id, in: .card, data: read())
        let again = PlateImage.image(for: id, in: .card, data: read())
        #expect(first != nil && first === again)
        #expect(reads == 1)
        // Smaller than the card, so decoded whole: the thumbnailer never upscales.
        #expect(first?.size == CGSize(width: 800, height: 400))
    }

    private static func jpeg(width: Int, height: Int, orientation: Int) -> Data? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
        guard let cg = renderer.image(actions: { ctx in
            UIColor(red: 0.83, green: 0.38, blue: 0.17, alpha: 1).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }).cgImage else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data as CFMutableData, "public.jpeg" as CFString, 1, nil)
        else { return nil }
        let properties: [CFString: Any] = [kCGImagePropertyOrientation: orientation]
        CGImageDestinationAddImage(destination, cg, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}
