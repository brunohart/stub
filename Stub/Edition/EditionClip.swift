import SwiftUI
import AVFoundation
import CoreTransferable
import UniformTypeIdentifiers
import OSLog

/// The moving share (brief §6.4). A still is the wrong share for a card whose point is light, so beside it the detail
/// offers three seconds of the card turning from −0.35 to 0.35 of tilt while the light crosses the foil. Deterministic:
/// the same card turns the same way every time, drawn frame by frame by `ImageRenderer` from the same composition the
/// detail draws, written as HEVC by `AVAssetWriter`. Nothing moves that the phone's light would not move.
struct EditionClip: Transferable, Sendable {
    let composition: Composition

    static let log = Logger(subsystem: "com.designedbybruno.stub", category: "clip")
    /// Three seconds at sixty frames: long enough to see the light cross, short enough to loop.
    static let seconds = 3.0
    static let fps = 60
    /// The margin of parchment round the card, as the still has, and the pixels a card point.
    static let margin: CGFloat = 28
    static let scale: CGFloat = 2

    static var transferRepresentation: some TransferRepresentation {
        // Drawn when a destination asks for it, not when the detail opens.
        FileRepresentation(exportedContentType: .mpeg4Movie) { clip in
            SentTransferredFile(try await clip.render())
        }
    }

    /// Writes the clip to a temporary file and returns it. `seconds` and `fps` are here for the test, which wants a short one.
    @MainActor
    func render(seconds: Double = Self.seconds, fps: Int = Self.fps) async throws -> URL {
        let started = ContinuousClock.now
        let frames = max(2, Int(seconds * Double(fps)))
        let size = CGSize(width: (Card.width + 2 * Self.margin) * Self.scale, height: (Card.height + 2 * Self.margin) * Self.scale)
        // Even dimensions: HEVC's chroma is subsampled by two.
        let width = Int(size.width) / 2 * 2, height = Int(size.height) / 2 * 2
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(composition.edition.release.replacingOccurrences(of: " ", with: "-"))-edition.mp4")
        try? FileManager.default.removeItem(at: url)

        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 6_000_000],
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
        ])
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? ClipError.writer }
        writer.startSession(atSourceTime: .zero)

        for frame in 0..<frames {
            let t = Double(frame) / Double(frames - 1)
            guard let image = Self.frame(composition, at: t) else { throw ClipError.render }
            while !input.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(5)) }
            guard let pool = adaptor.pixelBufferPool, let buffer = Self.buffer(image, pool: pool, width: width, height: height) else {
                throw ClipError.buffer
            }
            adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: CMTimeScale(fps)))
            // A frame at a time on the main actor; let the share sheet breathe between them.
            await Task.yield()
        }
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? ClipError.writer }
        let ms = (ContinuousClock.now - started) / .milliseconds(1)
        Self.log.info("Clip: '\(composition.edition.release)' \(frames) frames at \(width)×\(height) in \(Int(ms)) ms")
        return url
    }

    enum ClipError: Error { case writer, render, buffer }

    /// Where the card is at `t`, 0 to 1: turned from −0.35 to 0.35, eased at both ends so the loop has no jolt, the
    /// light a little above the middle, as the still's is.
    static func tilt(at t: Double) -> CGPoint {
        let eased = 0.5 - 0.5 * cos(t * .pi)
        return CGPoint(x: -0.35 + 0.7 * eased, y: -0.2 + 0.08 * sin(t * .pi))
    }

    /// One frame: the card on its margin of parchment, leaning with its tilt as the keepsake leans, lit from where the
    /// tilt puts the light.
    @MainActor
    static func frame(_ composition: Composition, at t: Double) -> CGImage? {
        let tilt = Self.tilt(at: t)
        let card = EditionFace(composition: composition, light: Light(tilt: tilt))
            .rotation3DEffect(.degrees(Double(tilt.x) * 11), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
            .rotation3DEffect(.degrees(Double(-tilt.y) * 11), axis: (x: 1, y: 0, z: 0), perspective: 0.45)
            .shadow(color: .black.opacity(0.18), radius: 12, x: 6 - tilt.x * 8, y: 10 - tilt.y * 8)
            .padding(margin)
            .background(Ink.paper)
        let renderer = ImageRenderer(content: card)
        renderer.scale = scale
        renderer.isOpaque = true
        return renderer.cgImage
    }

    private static func buffer(_ image: CGImage, pool: CVPixelBufferPool, width: Int, height: Int) -> CVPixelBuffer? {
        var made: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &made) == kCVReturnSuccess, let buffer = made else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return buffer
    }
}
