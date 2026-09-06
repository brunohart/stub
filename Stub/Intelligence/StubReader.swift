import Foundation
import CoreGraphics
import OSLog

/// The whole pipeline: photograph → text → fields. Prefers the on-device model, keeps the heuristic
/// as the floor, and always returns the raw read so the human can overrule both.
enum StubReader {
    static let log = Logger(subsystem: "com.designedbybruno.stub", category: "reader")

    enum Stage: Equatable, Sendable {
        case reading      // Vision
        case understanding(parser: String)
        case done
    }

    struct Result: Sendable {
        var reading: StubReading
        var draft: StubDraft
    }

    static func read(_ image: CGImage, progress: @Sendable @MainActor (Stage) -> Void) async throws -> Result {
        await progress(.reading)
        let reading = try await StubVision.read(image)
        log.info("Vision read \(reading.lines.count) lines")

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
            let ns = error as NSError
            log.error("\(parser.name) failed: \(error.localizedDescription) [\(ns.domain) \(ns.code)] \(String(reflecting: error)) \(ns.userInfo). Using heuristics.")
            draft = HeuristicParser.parse(reading)
        }
        await progress(.done)
        return Result(reading: reading, draft: draft)
    }

    static func preferredParser() -> any StubParsing {
        if #available(iOS 26.0, *), ModelParser.isAvailable {
            return ModelParser()
        }
        return HeuristicParser()
    }

    static var modelStatus: String {
        if #available(iOS 26.0, *) {
            return ModelParser.unavailabilityReason() ?? "On-device model ready"
        }
        return "Requires iOS 26"
    }
}
