import Testing
import Foundation
import CoreGraphics
import UIKit
@testable import Stub

/// The crop must never lose the photograph. Fallbacks are the contract; the crop itself is a bonus we measure.
struct StubCropTests {
    /// A flat, featureless frame. Vision has no document to find; the full image comes back untouched.
    @Test func flatImageFallsBackToFullFrame() async {
        let image = Self.flat(width: 640, height: 480)
        let out = await StubCrop.crop(image)
        #expect(!out.cropped)
        #expect(out.image.width == 640 && out.image.height == 480)
    }

    @Test func rejectsSmudges() {
        let size = CGSize(width: 1000, height: 1000)
        let smudge = StubCrop.Quad(
            topLeft: CGPoint(x: 10, y: 60), topRight: CGPoint(x: 60, y: 60),
            bottomRight: CGPoint(x: 60, y: 10), bottomLeft: CGPoint(x: 10, y: 10)
        )
        #expect(!StubCrop.accepts(smudge, in: size))

        let collapsed = StubCrop.Quad(
            topLeft: CGPoint(x: 100, y: 900), topRight: CGPoint(x: 900, y: 900),
            bottomRight: CGPoint(x: 900, y: 898), bottomLeft: CGPoint(x: 100, y: 898)
        )
        #expect(!StubCrop.accepts(collapsed, in: size))

        let ticket = StubCrop.Quad(
            topLeft: CGPoint(x: 100, y: 700), topRight: CGPoint(x: 900, y: 720),
            bottomRight: CGPoint(x: 910, y: 300), bottomLeft: CGPoint(x: 110, y: 280)
        )
        #expect(StubCrop.accepts(ticket, in: size))
    }

    /// What the simulator's segmentation model says about every photograph: a strip along the bottom,
    /// full width, at 0.97. Big enough, four honest sides, and not a ticket.
    @Test func rejectsFrameHuggingStrips() {
        let size = CGSize(width: 2400, height: 1400)
        let strip = StubCrop.Quad(
            topLeft: CGPoint(x: 16, y: 355), topRight: CGPoint(x: 2400, y: 350),
            bottomRight: CGPoint(x: 2400, y: 5), bottomLeft: CGPoint(x: 33, y: 5)
        )
        #expect(StubCrop.reason(strip, in: size) == "hugs 3 frame edges")

        // Two edges is fine: a ticket can be laid against a corner of the frame.
        let cornered = StubCrop.Quad(
            topLeft: CGPoint(x: 10, y: 1390), topRight: CGPoint(x: 1800, y: 1380),
            bottomRight: CGPoint(x: 1790, y: 600), bottomLeft: CGPoint(x: 20, y: 610)
        )
        #expect(StubCrop.accepts(cornered, in: size))
    }

    @Test func perspectiveCorrectionStraightensAKnownRectangle() {
        let image = Self.flat(width: 800, height: 600)
        let quad = StubCrop.Quad(
            topLeft: CGPoint(x: 100, y: 500), topRight: CGPoint(x: 700, y: 500),
            bottomRight: CGPoint(x: 700, y: 200), bottomLeft: CGPoint(x: 100, y: 200)
        )
        let out = StubCrop.corrected(image, to: quad)
        #expect(out != nil)
        #expect(abs((out?.width ?? 0) - 600) <= 2)
        #expect(abs((out?.height ?? 0) - 300) <= 2)
    }

    /// The real fixtures: tilted stubs on a dark table. Evidence, not assertion: the crop should be the
    /// ticket (about 2.4:1, well under the full frame), and the text must still read from it. Which
    /// detector did it is logged, not asserted: segmentation on a device, rectangles on the simulator.
    @Test(arguments: [
        ("stub-1-the-brutalist", "The Brutalist", "H12"),
        ("stub-2-perfect-days", "Perfect Days", "F7"),
        ("stub-3-dune-part-two-imax", "Dune Part Two", "D4"),
        ("stub-4-past-lives", "Past Lives", "K9"),
    ])
    func cropsTheFixture(name: String, title: String, seat: String) async throws {
        let url = try #require(Bundle.main.url(forResource: name, withExtension: "png"))
        let cg = try #require(UIImage(data: Data(contentsOf: url))?.cgImage)
        let out = await StubCrop.crop(cg)
        #expect(out.cropped, "No ticket found in \(name)")
        #expect(out.detector != nil)
        let full = Double(cg.width * cg.height)
        let area = Double(out.image.width * out.image.height)
        #expect(area < full * 0.8)
        let aspect = Double(out.image.width) / Double(out.image.height)
        #expect(aspect > 1.8 && aspect < 3.2, "aspect \(aspect)")

        let reading = try await StubVision.read(out.image)
        let draft = HeuristicParser.parse(reading)
        #expect(draft.title == title)
        #expect(draft.seat == seat)
    }

    private static func flat(width: Int, height: Int) -> CGImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
        return renderer.image { ctx in
            UIColor(red: 0.94, green: 0.93, blue: 0.90, alpha: 1).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }.cgImage!
    }
}
