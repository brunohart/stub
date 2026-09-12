import Foundation
import CoreGraphics
import OSLog
import Synchronization

/// The whole pipeline: photograph → crop → text → fields. Prefers the on-device model, keeps the heuristic
/// as the floor, and always returns the raw read so the human can overrule both.
enum StubReader {
    static let log = Logger(subsystem: "com.designedbybruno.stub", category: "reader")

    /// How many reads are in flight. The season sentence waits for zero: the model has one pair of hands,
    /// and a stub being read should not queue behind a sentence about the drawer.
    private static let inFlight = Mutex(0)
    static var isBusy: Bool { inFlight.withLock { $0 > 0 } }

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

    /// `partial` is called with each draft the model streams, title first, so a screen can fill in as the
    /// answer forms. It is not called on the heuristic path: that answer arrives whole.
    static func read(
        _ image: CGImage,
        progress: @Sendable @MainActor (Stage) -> Void,
        partial: (@Sendable @MainActor (StubDraft) -> Void)? = nil
    ) async throws -> Result {
        inFlight.withLock { $0 += 1 }
        defer { inFlight.withLock { $0 -= 1 } }
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

        let draft = await understand(reading, progress: progress, partial: partial)
        return Result(plate: plate, cropped: cropped, detector: detector, reading: reading, draft: draft)
    }

    /// The camera path (Day 6): the live scanner has already read the print, so there is nothing to crop
    /// and nothing for Vision to do. The lines go straight to the parsers; the photograph is only the plate.
    static func read(
        _ reading: StubReading,
        plate: CGImage,
        progress: @Sendable @MainActor (Stage) -> Void,
        partial: (@Sendable @MainActor (StubDraft) -> Void)? = nil
    ) async -> Result {
        inFlight.withLock { $0 += 1 }
        defer { inFlight.withLock { $0 -= 1 } }
        log.info("Scanner read \(reading.lines.count) lines live")
        let draft = await understand(reading, progress: progress, partial: partial)
        return Result(plate: plate, cropped: false, detector: nil, reading: reading, draft: draft)
    }

    /// Text to fields. The floor first, always; then the model with the floor's draft in hand (ADR-010),
    /// streaming each snapshot to `partial`. Whatever the model does, this returns a draft.
    static func understand(
        _ reading: StubReading,
        using parser: (any StubParsing)? = nil,
        progress: @Sendable @MainActor (Stage) -> Void,
        partial: (@Sendable @MainActor (StubDraft) -> Void)? = nil
    ) async -> StubDraft {
        let parser = parser ?? preferredParser()
        await progress(.understanding(parser: parser.name))

        // The floor first: it is cheap, it is the fallback, and it is the model's hint.
        let floor = HeuristicParser.parse(reading)
        var draft = floor
        if #available(iOS 26.0, *), let model = parser as? ModelParser {
            do {
                let started = ContinuousClock.now
                var last: StubDraft?
                var titleAt: Duration?, seatAt: Duration?
                for try await snapshot in model.stream(reading, hint: floor) {
                    if titleAt == nil, snapshot.isUsable { titleAt = started.duration(to: .now) }
                    if seatAt == nil, !snapshot.seat.isEmpty { seatAt = started.duration(to: .now) }
                    last = snapshot
                    await partial?(snapshot)
                }
                let total = started.duration(to: .now)
                func ms(_ d: Duration?) -> String { d.map { "\(Int($0 / .milliseconds(1))) ms" } ?? "never" }
                log.info("Model streamed: title at \(ms(titleAt)), seat at \(ms(seatAt)), done at \(ms(total))")
                if let last, last.isUsable {
                    draft = last
                } else {
                    log.notice("Model returned no title; falling back to heuristics")
                }
            } catch {
                log.error("\(parser.name) failed: \(ModelProbe.explain(error)). Using heuristics.")
            }
        }
        await progress(.done)
        return draft
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
