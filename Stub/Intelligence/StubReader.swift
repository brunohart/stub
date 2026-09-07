import Foundation
import CoreGraphics
import OSLog

/// The whole pipeline: photograph → crop → text → fields. Prefers the on-device model, keeps the heuristic
/// as the floor, and always returns the raw read so the human can overrule both.
enum StubReader {
    static let log = Logger(subsystem: "com.designedbybruno.stub", category: "reader")

    enum Stage: Equatable, Sendable {
        case cropping     // Vision document segmentation
        case reading      // Vision text
        case understanding(parser: String)
        case done
    }

    struct Result: Sendable {
        /// The straightened stub when one was found, otherwise the photograph as given.
        var plate: CGImage
        var cropped: Bool
        /// Who found the ticket's corners, when someone did.
        var detector: StubCrop.Detector?
        var reading: StubReading
        var draft: StubDraft
    }

    static func read(_ image: CGImage, progress: @Sendable @MainActor (Stage) -> Void) async throws -> Result {
        await progress(.cropping)
        let crop = await StubCrop.crop(image)

        await progress(.reading)
        var reading: StubReading
        var plate = crop.image
        var cropped = crop.cropped
        var detector = crop.detector
        do {
            reading = try await StubVision.read(crop.image)
        } catch where crop.cropped {
            // The crop had no text in it. Vision was wrong about the document; read the whole frame.
            log.notice("No text in the crop; reading the full photograph instead")
            reading = try await StubVision.read(image)
            plate = image
            cropped = false
            detector = nil
        }
        log.info("Vision read \(reading.lines.count) lines\(cropped ? " from the crop" : "")")

        let parser = preferredParser()
        await progress(.understanding(parser: parser.name))

        var draft: StubDraft
        do {
            draft = try await parser.parse(reading)
            if !draft.isUsable, parser.name != "heuristic" {
                log.notice("Model returned no title; falling back to heuristics")
                draft = HeuristicParser.parse(reading)
            }
        } catch {
            let explained: String
            if #available(iOS 26.0, *) { explained = ModelProbe.explain(error) } else { explained = error.localizedDescription }
            log.error("\(parser.name) failed: \(explained). Using heuristics.")
            draft = HeuristicParser.parse(reading)
        }
        await progress(.done)
        return Result(plate: plate, cropped: cropped, detector: detector, reading: reading, draft: draft)
    }

    /// The model, when it reports available and the launch probe did not catch it lying. Otherwise the floor.
    static func preferredParser() -> any StubParsing {
        if #available(iOS 26.0, *), ModelParser.isAvailable, ModelProbe.outcome.allowsModel {
            return ModelParser()
        }
        return HeuristicParser()
    }

    /// What the import screen says about the model. Cached from the launch probe, so it is what happened,
    /// not what the availability flag promised.
    static var modelStatus: String {
        if #available(iOS 26.0, *) {
            return ModelProbe.outcome.statusLine
        }
        return "Requires iOS 26"
    }
}
