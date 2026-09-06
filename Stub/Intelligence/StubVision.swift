import Foundation
import CoreGraphics
import Vision

/// Reads the printed text off a stub photograph. On device, always.
enum StubVision {
    enum ReadError: Error { case noText }

    static func read(_ image: CGImage) async throws -> StubReading {
        // iOS 26: document-aware recognition keeps reading order and paragraphs together,
        // which matters on a stub where the title and the seat are both shouting in caps.
        if #available(iOS 26.0, *) {
            let request = RecognizeDocumentsRequest()
            if let document = try await request.perform(on: image).first?.document {
                let lines = document.text.transcript
                    .split(whereSeparator: \.isNewline)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                if !lines.isEmpty { return StubReading(lines: lines) }
            }
        }

        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        let observations = try await request.perform(on: image)
        let lines = observations
            .sorted { $0.boundingBox.origin.y > $1.boundingBox.origin.y }
            .compactMap { $0.topCandidates(1).first?.string.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else { throw ReadError.noText }
        return StubReading(lines: lines)
    }
}
