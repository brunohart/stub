import SwiftUI
import PencilKit
import Observation
import OSLog

/// The owner's signature (ADR-016, brief §5.8). The front of a card is the film's; the back is yours. Signed once with a
/// finger in the margin on the back of a proof, kept on the device, and signed on every proof after. Redone with a long
/// press. A drawing, not a preference, so it lives in Application Support, never in `UserDefaults`, and never leaves
/// the phone (ADR-005).
@MainActor @Observable
final class Signatures {
    static let shared = Signatures()
    static let log = Logger(subsystem: "com.designedbybruno.stub", category: "signature")

    /// Where the drawing is kept.
    static var url: URL { URL.applicationSupportDirectory.appending(path: "Signature.drawing") }

    /// The signature in card points, drawn inside `EditionBack.signatureMargin`'s size.
    private(set) var drawing: PKDrawing?
    /// The signature as the pencil left it, rendered once.
    private(set) var image: UIImage?

    @ObservationIgnored private let url: URL

    init(url: URL = Signatures.url) {
        self.url = url
        if let data = try? Data(contentsOf: url), let drawing = try? PKDrawing(data: data), !drawing.strokes.isEmpty {
            self.drawing = drawing
            image = Self.render(drawing)
        }
    }

    var isSigned: Bool { drawing != nil }

    /// Keep `drawing`, already in card points.
    func keep(_ drawing: PKDrawing) {
        guard !drawing.strokes.isEmpty else { return }
        self.drawing = drawing
        image = Self.render(drawing)
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try drawing.dataRepresentation().write(to: url, options: .atomic)
        } catch {
            Self.log.error("The signature could not be kept: \(error.localizedDescription)")
        }
    }

    /// Sign again: the old one is gone, and the margin is open.
    func redo() {
        drawing = nil
        image = nil
        try? FileManager.default.removeItem(at: url)
    }

    /// The pencil: graphite, soft, a little grey.
    static let graphite = UIColor(red: 0.27, green: 0.27, blue: 0.29, alpha: 1)
    static var pencil: PKInkingTool { PKInkingTool(.pencil, color: graphite, width: 2.6) }

    static func render(_ drawing: PKDrawing) -> UIImage {
        drawing.image(from: CGRect(origin: .zero, size: EditionBack.signatureMargin.size), scale: 4)
    }

    #if DEBUG
    /// A signature for the simulator, which has no hand: a looped name and a flourish under it, drawn as a pencil would.
    static func fixture() -> PKDrawing {
        let ink = PKInk(.pencil, color: graphite)
        func stroke(_ points: [CGPoint]) -> PKStroke {
            let samples = points.enumerated().map { i, p in
                PKStrokePoint(location: p, timeOffset: Double(i) * 0.012, size: CGSize(width: 2.6, height: 2.6),
                              opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
            }
            return PKStroke(ink: ink, path: PKStrokePath(controlPoints: samples, creationDate: .now))
        }
        // A tall first stroke, then a run of uneven loops leaning right as a hand does, then a flourish back under them.
        let initial = (0...24).map { i -> CGPoint in
            let t = Double(i) / 24
            return CGPoint(x: 14 + 10 * t + 6 * sin(t * .pi), y: 44 - 38 * sin(t * .pi * 0.92))
        }
        let name = (0...140).map { i -> CGPoint in
            let t = Double(i) / 140
            let turn = t * 2 * .pi * 4.6
            let height = 6 + 9 * abs(sin(t * 5.3 + 0.4)) + 5 * (1 - t)
            let y = 34 - height * sin(turn) - 3 * t
            let x = 26 + 88 * t + 4.5 * cos(turn) + 0.32 * (34 - y)
            return CGPoint(x: x, y: y)
        }
        let flourish = (0...44).map { i -> CGPoint in
            let t = Double(i) / 44
            return CGPoint(x: 124 - 104 * t, y: 43 + 7 * sin(t * .pi) - 4 * t)
        }
        return PKDrawing(strokes: [stroke(initial), stroke(name), stroke(flourish)])
    }
    #endif
}

/// What an owner writes in pencil on the back of a proof, beside the signature: A/P, for an artist's proof, and the takes
/// that differ from the title's, the way a printmaker notes a state ("disc 14 · bars 3").
struct Pencil: Equatable {
    var artistsProof: Bool
    /// "disc 14 · bars 3", in the order the parts are drawn.
    var takes: String?
    /// For VoiceOver: "disc take fourteen, bars take three".
    var spokenTakes: String?

    init?(edition: Edition) {
        guard edition.directedBy == .you else { return nil }
        artistsProof = true
        let turned = edition.movement.parts.compactMap { part -> (String, Int)? in
            guard let take = edition.takes[part.id], take != 0 else { return nil }
            return (part.name.replacingOccurrences(of: "the ", with: ""), take)
        }
        takes = turned.isEmpty ? nil : turned.map { "\($0.0) \($0.1)" }.joined(separator: " · ")
        spokenTakes = turned.isEmpty ? nil : turned.map { "\($0.0) take \(Self.spelled($0.1))" }.joined(separator: ", ")
    }

    /// "Signed, artist's proof, disc take fourteen."
    func spoken(signed: Bool) -> String {
        var words = [signed ? "Signed" : "Unsigned", "artist's proof"]
        if let spokenTakes { words.append(spokenTakes) }
        return words.joined(separator: ", ") + "."
    }

    private static func spelled(_ n: Int) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "en")
        f.numberStyle = .spellOut
        return f.string(from: NSNumber(value: n)) ?? String(n)
    }
}

/// The margin you sign in: a PencilKit canvas that takes a finger, in graphite. It hands the drawing back once the hand
/// has been still for a moment.
struct SignaturePad: UIViewRepresentable {
    /// Card points to the pad's points: the pad is drawn over a scaled card.
    let scale: CGFloat
    var signed: (PKDrawing) -> Void

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawingPolicy = .anyInput
        canvas.tool = Signatures.pencil
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.isScrollEnabled = false
        canvas.delegate = context.coordinator
        canvas.accessibilityLabel = "The margin. Sign here with a finger."
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        context.coordinator.scale = scale
        context.coordinator.signed = signed
    }

    func makeCoordinator() -> Coordinator { Coordinator(scale: scale, signed: signed) }

    @MainActor
    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var scale: CGFloat
        var signed: (PKDrawing) -> Void
        private var still: Task<Void, Never>?

        init(scale: CGFloat, signed: @escaping (PKDrawing) -> Void) {
            self.scale = scale
            self.signed = signed
        }

        nonisolated func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            MainActor.assumeIsolated {
                let drawing = canvasView.drawing
                still?.cancel()
                guard !drawing.strokes.isEmpty else { return }
                still = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(1.2))
                    guard let self, !Task.isCancelled else { return }
                    // Kept in card points, so it signs every card at the same size, whatever it was drawn at.
                    self.signed(drawing.transformed(using: CGAffineTransform(scaleX: 1 / self.scale, y: 1 / self.scale)))
                }
            }
        }
    }
}
