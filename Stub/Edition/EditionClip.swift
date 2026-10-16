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
/// and crops nothing; `card` is Day 30's, the card on the still's margin of parchment. Both carry the watermark, "shared in
/// Stub", blind-embossed into the parchment under the card (`Watermark`). There is no way to share without it.
struct EditionClip: Transferable, Sendable {
    let composition: Composition
    var format: Format = .vertical

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
        Self.log.info("Clip: '\(composition.edition.release)' \(format.rawValue), \(frames) frames at \(width)×\(height) in \(Int(ms)) ms")
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
    var canvas: CGSize { format.canvas }

    /// The frame in pixels, even in both directions: HEVC's chroma is subsampled by two.
    var pixels: (width: Int, height: Int) {
        (Int(canvas.width * format.scale) / 2 * 2, Int((canvas.height * format.scale).rounded()) / 2 * 2)
    }

    /// One frame: the card on parchment, leaning with its tilt as the keepsake leans, lit from where the tilt puts the
    /// light, and the watermark pressed into the parchment under it.
    @MainActor
    func frame(at t: Double) -> CGImage? {
        Self.page(composition, tilt: Self.tilt(at: t), format: format, watermark: true)
    }

    /// The page at a tilt. `watermark` is false only for the tests, which measure what lies under it.
    @MainActor
    static func page(_ composition: Composition, tilt: CGPoint, format: Format, watermark: Bool) -> CGImage? {
        let canvas = format.canvas
        let card = EditionFace(composition: composition, light: Light(tilt: tilt))
            .rotation3DEffect(.degrees(Double(tilt.x) * 11), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
            .rotation3DEffect(.degrees(Double(-tilt.y) * 11), axis: (x: 1, y: 0, z: 0), perspective: 0.45)
            .shadow(color: .black.opacity(0.18), radius: 12, x: 6 - tilt.x * 8, y: 10 - tilt.y * 8)
        let page = ZStack {
            Ink.paper
            card.position(format.cardCentre(in: canvas))
            if watermark {
                Watermark(size: format.markSize, light: tilt).position(format.markCentre(in: canvas))
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

    /// The band under the card the watermark sits in, in the `card` framing: below the shadow, which reaches about 22 points.
    static let markBand: CGFloat = 60

    /// The frame in points: 1080 by 1920 pixels for the vertical, the card and its margin and the watermark's band for the card.
    var canvas: CGSize {
        switch self {
        case .vertical:
            return CGSize(width: 1080 / scale, height: 1920 / scale)
        case .card:
            let m = EditionClip.margin
            return CGSize(width: Card.width + 2 * m, height: Card.height + m + Self.markBand)
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
        return CGPoint(x: canvas.width / 2, y: card.y + Card.height / 2 + (self == .vertical ? 43 : 39))
    }

    var markSize: CGFloat { self == .vertical ? 15 : 13 }

    /// The bands at the top and bottom of a Story that its own controls are drawn over, in pixels of the 1920 frame:
    /// fourteen per cent each, about 250 pixels (Meta's guidance for Stories). Nothing of ours may sit in them.
    static let storyBand: CGFloat = 250
}

/// The watermark on every share (2026-10-13): "shared in Stub" beside a small ticket, blind-embossed into the parchment
/// under the card, the way a paper mill presses its mark into a sheet. No ink of its own but a breath of the paper's own
/// shadow, so it is read by its relief: lit along the edges that face the light, shaded along the edges that do not. In the
/// moving share the light moves, and the relief catches it as the card turns. Never on the card, and always there:
/// there is no setting to leave it off.
struct Watermark: View {
    var size: CGFloat
    /// The share's tilt, -1 to 1: where the light is, so the relief is lit from the same place as the card.
    var light: CGPoint = CGPoint(x: 0.3, y: -0.2)

    var body: some View {
        // The light's direction, as a unit of offset: from the upper left, swinging with the tilt.
        let lx = 0.55 + light.x * 0.45, ly = 0.75 - light.y * 0.25
        let mark = HStack(spacing: size * 0.45) {
            TicketMark().frame(width: size * 1.25, height: size * 0.78)
            Text("shared in Stub").font(Type.display(size)).tracking(size * 0.01)
        }
        return ZStack {
            // The wall facing away from the light: a hairline of shadow up and to the left.
            mark.foregroundStyle(Color(hex: 0x5E5747).opacity(0.5)).offset(x: -lx * 0.75, y: -ly * 0.75)
            // The wall facing the light: a hairline of light down and to the right.
            mark.foregroundStyle(Color.white.opacity(0.85)).offset(x: lx * 0.8, y: ly * 0.8)
            // The floor of the impression: the paper, pressed a shade darker.
            mark.foregroundStyle(Color(hex: 0xD3CCBD))
        }
        .compositingGroup()
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Shared in Stub")
    }
}

/// The watermark's ticket: a stub's outline with a notch in each end and the perforation, small, as the icon draws it.
struct TicketMark: View {
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width, h = proxy.size.height
            let notch = h * 0.22
            Path { p in
                p.addRoundedRect(in: CGRect(x: 0, y: 0, width: w, height: h), cornerSize: CGSize(width: h * 0.16, height: h * 0.16))
                p.addEllipse(in: CGRect(x: -notch, y: h / 2 - notch, width: 2 * notch, height: 2 * notch))
                p.addEllipse(in: CGRect(x: w - notch, y: h / 2 - notch, width: 2 * notch, height: 2 * notch))
            }
            .fill(style: FillStyle(eoFill: true))
            // The perforation, a third of the way in, cut through.
            VStack(spacing: h * 0.1) {
                ForEach(0..<4, id: \.self) { _ in Circle().frame(width: h * 0.12, height: h * 0.12) }
            }
            .frame(width: w, height: h)
            .offset(x: -w * 0.18)
            .blendMode(.destinationOut)
        }
        .compositingGroup()
    }
}

/// Where a stranger who sees a share can find Stub: the page on designedbybruno.net, which is ours to point at the App Store
/// once the listing exists. It goes in the share's text, never into the frame.
enum ShareLinkText {
    static let link = URL(string: "https://designedbybruno.net/stub")!

    /// Which share brought a stranger to the page.
    enum Via: String { case clip, card, still }

    /// The page, with which share it came from. The site hands `via` to the App Store as a campaign token, so App Store
    /// Connect counts the installs that came from shares, aggregated by Apple, while Stub sends nothing and knows nothing
    /// about who shared (docs/decisions/006-network-without-data.md).
    static func link(via: Via) -> URL { URL(string: "https://designedbybruno.net/stub?via=\(via.rawValue)")! }
}
