import Foundation
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins
import Vision
import OSLog

/// Cuts the stub out of the photograph. The card plate should be the ticket, not the table it was lying on.
///
/// Two detectors, in order. Vision's document segmentation (a neural model) is asked first. If it finds
/// nothing, or what it finds hugs the frame instead of sitting inside it, the classic rectangle detector is
/// asked. Core Image then straightens whichever quadrilateral won. When neither is convincing the full
/// photograph is used unchanged, so the reader always has something to read.
///
/// Why two: on the iOS 26 simulator the segmentation model answers every photograph with the same
/// bottom-quarter strip at 0.97 confidence, the way the language model reports `.available` and then
/// fails (ADR-001). Rectangles are arithmetic, not assets, and they find the ticket at 1.0.
enum StubCrop {
    static let log = Logger(subsystem: "com.designedbybruno.stub", category: "crop")

    /// Four corners in image pixels, origin at the lower left (Vision's and Core Image's convention).
    struct Quad: Equatable, Sendable {
        var topLeft: CGPoint
        var topRight: CGPoint
        var bottomRight: CGPoint
        var bottomLeft: CGPoint

        var corners: [CGPoint] { [topLeft, topRight, bottomRight, bottomLeft] }

        /// Shoelace area, in square pixels.
        var area: CGFloat {
            let p = corners
            var sum: CGFloat = 0
            for i in p.indices {
                let a = p[i], b = p[(i + 1) % p.count]
                sum += a.x * b.y - b.x * a.y
            }
            return abs(sum) / 2
        }

        /// Corners in pixels, lower-left origin, for the log.
        var description: String {
            func p(_ c: CGPoint) -> String { "(\(Int(c.x)),\(Int(c.y)))" }
            return "tl\(p(topLeft)) tr\(p(topRight)) br\(p(bottomRight)) bl\(p(bottomLeft))"
        }
    }

    enum Detector: String, Sendable {
        case segmentation
        case rectangles
    }

    struct Outcome: Sendable {
        var image: CGImage
        var quad: Quad?
        var detector: Detector?
        var cropped: Bool { quad != nil }
    }

    /// Below this share of the frame, a quadrilateral is a smudge, not a ticket.
    static let minimumAreaFraction: CGFloat = 0.06
    /// Below this confidence the segmentation is a guess.
    static let minimumConfidence: Float = 0.5
    /// A corner within this share of the frame's shorter side of an edge is "on" that edge.
    static let edgeTolerance: CGFloat = 0.02

    /// Detect and straighten. Never throws: a failure to crop is a decision to keep the whole photograph.
    static func crop(_ image: CGImage) async -> Outcome {
        let size = CGSize(width: image.width, height: image.height)
        guard let (quad, detector) = await find(in: image, size: size) else {
            log.info("No ticket found; using the full photograph")
            return Outcome(image: image, quad: nil, detector: nil)
        }
        guard let corrected = corrected(image, to: quad) else {
            log.error("Perspective correction produced no image; using the full photograph")
            return Outcome(image: image, quad: nil, detector: nil)
        }
        log.info("Cropped \(image.width)×\(image.height) → \(corrected.width)×\(corrected.height) by \(detector.rawValue)")
        return Outcome(image: corrected, quad: quad, detector: detector)
    }

    /// The first detector whose quadrilateral passes `accepts`.
    static func find(in image: CGImage, size: CGSize) async -> (Quad, Detector)? {
        do {
            if let quad = try await detectDocument(image) {
                if accepts(quad, in: size) { return (quad, .segmentation) }
                log.notice("Segmentation rejected (\(reason(quad, in: size) ?? "")); asking for rectangles")
            }
        } catch {
            log.error("Segmentation failed: \(error.localizedDescription); asking for rectangles")
        }
        do {
            for quad in try await detectRectangles(image) where accepts(quad, in: size) {
                return (quad, .rectangles)
            }
        } catch {
            log.error("Rectangle detection failed: \(error.localizedDescription)")
        }
        return nil
    }

    /// Ask Vision's document model for the corners. `nil` when it sees none it is sure about.
    static func detectDocument(_ image: CGImage) async throws -> Quad? {
        let request = DetectDocumentSegmentationRequest()
        guard let observation = try await request.perform(on: image) else { return nil }
        guard observation.confidence >= minimumConfidence else {
            log.info("Segmentation confidence \(observation.confidence) below \(minimumConfidence)")
            return nil
        }
        let size = CGSize(width: image.width, height: image.height)
        let quad = Quad(
            topLeft: observation.topLeft.toImageCoordinates(size, origin: .lowerLeft),
            topRight: observation.topRight.toImageCoordinates(size, origin: .lowerLeft),
            bottomRight: observation.bottomRight.toImageCoordinates(size, origin: .lowerLeft),
            bottomLeft: observation.bottomLeft.toImageCoordinates(size, origin: .lowerLeft)
        )
        log.info("Segmentation (\(observation.confidence, format: .fixed(precision: 2))): \(quad.description)")
        return quad
    }

    /// Ask the classic rectangle detector. Largest first. Tickets are wide, so the aspect window is generous.
    static func detectRectangles(_ image: CGImage) async throws -> [Quad] {
        var request = DetectRectanglesRequest()
        request.minimumAspectRatio = 0.15
        request.maximumAspectRatio = 1
        request.minimumSize = 0.2
        request.minimumConfidence = minimumConfidence
        request.maximumObservations = 4
        let size = CGSize(width: image.width, height: image.height)
        let quads = try await request.perform(on: image).map { o in
            Quad(
                topLeft: o.topLeft.toImageCoordinates(size, origin: .lowerLeft),
                topRight: o.topRight.toImageCoordinates(size, origin: .lowerLeft),
                bottomRight: o.bottomRight.toImageCoordinates(size, origin: .lowerLeft),
                bottomLeft: o.bottomLeft.toImageCoordinates(size, origin: .lowerLeft)
            )
        }.sorted { $0.area > $1.area }
        for q in quads { log.info("Rectangle: \(q.description)") }
        return quads
    }

    /// A quadrilateral is worth cropping to when it is big enough to be the ticket, not degenerate,
    /// and inside the photograph rather than a strip along its edges.
    static func accepts(_ quad: Quad, in size: CGSize) -> Bool {
        reason(quad, in: size) == nil
    }

    /// Why `accepts` says no, for the log. `nil` means yes.
    static func reason(_ quad: Quad, in size: CGSize) -> String? {
        let frame = size.width * size.height
        guard frame > 0 else { return "empty frame" }
        let fraction = quad.area / frame
        guard fraction >= minimumAreaFraction else { return "area \(Int(fraction * 100))% of frame" }
        // Each side must have some length; a collapsed edge means the detector guessed.
        let sides = [
            (quad.topLeft, quad.topRight), (quad.topRight, quad.bottomRight),
            (quad.bottomRight, quad.bottomLeft), (quad.bottomLeft, quad.topLeft),
        ]
        let shortest = min(size.width, size.height) * 0.05
        guard sides.allSatisfy({ hypot($0.0.x - $0.1.x, $0.0.y - $0.1.y) >= shortest }) else { return "collapsed side" }
        // A ticket photographed on a table sits inside the frame. Three or more edges touched is a strip,
        // and the model saying so about every photograph is the simulator, not the ticket.
        let tolerance = min(size.width, size.height) * edgeTolerance
        let touched = [
            quad.corners.contains { $0.x <= tolerance },
            quad.corners.contains { $0.x >= size.width - tolerance },
            quad.corners.contains { $0.y <= tolerance },
            quad.corners.contains { $0.y >= size.height - tolerance },
        ].filter { $0 }.count
        guard touched < 3 else { return "hugs \(touched) frame edges" }
        return nil
    }

    /// Straighten the quadrilateral into a rectangle with `CIPerspectiveCorrection`.
    static func corrected(_ image: CGImage, to quad: Quad) -> CGImage? {
        let filter = CIFilter.perspectiveCorrection()
        filter.inputImage = CIImage(cgImage: image)
        filter.topLeft = quad.topLeft
        filter.topRight = quad.topRight
        filter.bottomRight = quad.bottomRight
        filter.bottomLeft = quad.bottomLeft
        filter.crop = true
        guard let out = filter.outputImage, !out.extent.isEmpty, !out.extent.isInfinite else { return nil }
        let context = CIContext(options: [.useSoftwareRenderer: false])
        return context.createCGImage(out, from: out.extent)
    }
}
