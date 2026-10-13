import SwiftUI
import AVFoundation
import CoreTransferable
import UniformTypeIdentifiers
import OSLog

/// The moving share (brief §6.4). A still is the wrong share for a card whose point is light, so beside it the detail
/// offers three seconds of the card turning from −0.35 to 0.35 of tilt while the light crosses the foil. Deterministic:
/// the same card turns the same way every time, drawn frame by frame by `ImageRenderer` from the same composition the
/// detail draws, written as HEVC by `AVAssetWriter`. Nothing moves that the phone's light would not move.
///
/// Two framings (BEDIP-221). `vertical`, the default, is 9:16 at 1080 by 1920, so a Story or a Reel shows the whole of it
/// and crops nothing; `card` is Day 30's, the card on the still's margin of parchment. Either can carry the mark, "kept in
/// Stub", small in the lower margin, which is on unless the person turned it off (`ShareMark`).
struct EditionClip: Transferable, Sendable {
    let composition: Composition
    var format: Format = .vertical
    /// "kept in Stub" under the card.
    var marked: Bool = true

    enum Format: String, Sendable, CaseIterable {
        /// 9:16, 1080 by 1920: the card centred with room above and below, clear of the bands a Story draws its own
        /// controls over.
        case vertical
        /// The card on its margin of parchment, as the still is (Day 30).
        case card
    }

    static let log = Logger(subsystem: "com.designedbybruno.stub", category: "clip")
    /// Three seconds at sixty frames: long enough to see the light cross, short enough to loop.
    static let seconds = 3.0
    static let fps = 60
    /// The margin of parchment round the card in the `card` framing, as the still has.
    static let margin: CGFloat = 28

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
        let (width, height) = pixels
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(composition.edition.release.replacingOccurrences(of: " ", with: "-"))-edition-\(format.rawValue).mp4")
        try? FileManager.default.removeItem(at: url)

        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: format == .vertical ? 8_000_000 : 6_000_000],
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
            guard let image = self.frame(at: t) else { throw ClipError.render }
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
        Self.log.info("Clip: '\(composition.edition.release)' \(format.rawValue)\(marked ? ", marked" : ""), \(frames) frames at \(width)×\(height) in \(Int(ms)) ms")
        return url
    }

    enum ClipError: Error { case writer, render, buffer }

    /// Where the card is at `t`, 0 to 1: turned from −0.35 to 0.35, eased at both ends so the loop has no jolt, the
    /// light a little above the middle, as the still's is.
    static func tilt(at t: Double) -> CGPoint {
        let eased = 0.5 - 0.5 * cos(t * .pi)
        return CGPoint(x: -0.35 + 0.7 * eased, y: -0.2 + 0.08 * sin(t * .pi))
    }

    /// The frame in points.
    var canvas: CGSize { format.canvas(marked: marked) }

    /// The frame in pixels, even in both directions: HEVC's chroma is subsampled by two.
    var pixels: (width: Int, height: Int) {
        (Int(canvas.width * format.scale) / 2 * 2, Int((canvas.height * format.scale).rounded()) / 2 * 2)
    }

    /// One frame: the card on parchment, leaning with its tilt as the keepsake leans, lit from where the tilt puts the
    /// light, and the mark under it when it is on.
    @MainActor
    func frame(at t: Double) -> CGImage? {
        let tilt = Self.tilt(at: t)
        let canvas = self.canvas
        let card = EditionFace(composition: composition, light: Light(tilt: tilt))
            .rotation3DEffect(.degrees(Double(tilt.x) * 11), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
            .rotation3DEffect(.degrees(Double(-tilt.y) * 11), axis: (x: 1, y: 0, z: 0), perspective: 0.45)
            .shadow(color: .black.opacity(0.18), radius: 12, x: 6 - tilt.x * 8, y: 10 - tilt.y * 8)
        let page = ZStack {
            Ink.paper
            card.position(format.cardCentre(in: canvas))
            if marked {
                ClipMark(size: format.markSize).position(format.markCentre(in: canvas))
            }
        }
        .frame(width: canvas.width, height: canvas.height)
        let renderer = ImageRenderer(content: page)
        renderer.scale = format.scale
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

extension EditionClip.Format {
    /// Pixels a point. The vertical frame is 1080 by 1920 pixels, so the card is drawn larger in it than in the card's own.
    var scale: CGFloat { self == .vertical ? 2.25 : 2 }

    /// The band under the card the mark sits in, in the `card` framing: below the shadow, which reaches about 22 points.
    static let markBand: CGFloat = 60

    /// The frame in points. The vertical frame is the same with or without the mark; the card's grows a band for it.
    func canvas(marked: Bool) -> CGSize {
        switch self {
        case .vertical:
            return CGSize(width: 1080 / scale, height: 1920 / scale)
        case .card:
            let m = EditionClip.margin
            return CGSize(width: Card.width + 2 * m, height: Card.height + m + (marked ? Self.markBand : m))
        }
    }

    /// Where the card's centre is. In the vertical frame it sits a little above the middle, so the card and the mark
    /// together are centred and both clear the bottom band a Story draws its reply bar over.
    func cardCentre(in canvas: CGSize) -> CGPoint {
        switch self {
        case .vertical: return CGPoint(x: canvas.width / 2, y: canvas.height / 2 - 16)
        case .card: return CGPoint(x: canvas.width / 2, y: EditionClip.margin + Card.height / 2)
        }
    }

    /// Where the mark's centre is: under the card and its shadow.
    func markCentre(in canvas: CGSize) -> CGPoint {
        let card = cardCentre(in: canvas)
        return CGPoint(x: canvas.width / 2, y: card.y + Card.height / 2 + (self == .vertical ? 38 : 36))
    }

    var markSize: CGFloat { self == .vertical ? 14 : 12 }

    /// The bands at the top and bottom of a Story that its own controls are drawn over, in pixels of the 1920 frame:
    /// fourteen per cent each, about 250 pixels (Meta's guidance for Stories). Nothing of ours may sit in them.
    static let storyBand: CGFloat = 250
}

/// "kept in Stub", under the card in the moving share: the one word the clip says about where it came from. Host
/// Grotesk, small, in the parchment's own ink, the way a museum label sits under a print; a caption, not a logo. Never on
/// the card, never on the still, and off when the person says so (`ShareMark`).
struct ClipMark: View {
    var size: CGFloat
    var body: some View {
        Text("kept in Stub")
            .font(Type.words(size))
            .foregroundStyle(Ink.ink.opacity(0.62))
            .fixedSize()
    }
}

/// Whether the moving share carries the mark, and the link in the share's text (BEDIP-221). On unless the person turns it
/// off: nobody is made to advertise. One `UserDefaults` key (the privacy manifest's CA92.1 already covers it).
enum ShareMark {
    static let key = "share.mark"

    static func isOn(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: key) as? Bool ?? true
    }

    /// Where a stranger who sees the clip can find Stub. The page on designedbybruno.net is ours to point at the App Store
    /// once the listing exists; the link is in the share's text, never burned into the frame.
    static let link = URL(string: "https://designedbybruno.net/stub")!
}
