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

    /// `partial` is called with the rules' draft as soon as it has a title, so the person can keep it at once; and, while
    /// the rules have no title, with each draft the model streams, title first, so a screen can fill in as the answer forms.
    ///
    /// `whole`: read the whole picture and use the crop only for the plate. A PDF's page or a screenshot is already flat
    /// and upright, and what it says about the ticket is often outside the box the crop finds: an e-ticket's cinema is in
    /// the page's heading, above the bordered ticket (BEDIP-218).
    static func read(
        _ image: CGImage,
        whole: Bool = false,
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
            reading = try await StubVision.read(whole ? image : crop.image)
        } catch where crop.cropped && !whole {
            // The crop had no text in it. Vision was wrong about the document; read the whole frame.
            log.notice("No text in the crop; reading the full photograph instead")
            reading = try await StubVision.read(image)
            plate = image
            cropped = false
            detector = nil
        }
        log.info("Vision read \(reading.lines.count) lines\(whole ? " from the whole page" : cropped ? " from the crop" : "")")

        let draft = await understand(reading, progress: progress, partial: partial)
        return Result(plate: plate, cropped: cropped, detector: detector, reading: reading, draft: draft)
    }

    /// The camera path (Day 6): the live scanner has already read the print, so there is nothing for Vision to
    /// read. The lines go straight to the parsers. The frame is cropped to the ticket as a photograph is, while the
    /// parsers work, so a scanned card's plate is the ticket and not the table (Day 6's note); a frame with no ticket
    /// found in it stays whole.
    static func read(
        _ reading: StubReading,
        plate frame: CGImage,
        using parser: (any StubParsing)? = nil,
        progress: @Sendable @MainActor (Stage) -> Void,
        partial: (@Sendable @MainActor (StubDraft) -> Void)? = nil
    ) async -> Result {
        inFlight.withLock { $0 += 1 }
        defer { inFlight.withLock { $0 -= 1 } }
        log.info("Scanner read \(reading.lines.count) lines live")
        async let crop = StubCrop.crop(frame)
        let draft = await understand(reading, using: parser, progress: progress, partial: partial)
        let plate = await crop
        log.info("Scanned frame \(plate.cropped ? "cropped to the ticket" : "kept whole: no ticket found")")
        return Result(plate: plate.image, cropped: plate.cropped, detector: plate.detector, reading: reading, draft: draft)
    }

    /// How long the model is waited for once the rules have a draft. A person at the cinema door is not kept waiting for a
    /// second opinion (decision 001); past this the rules' draft stands and the model is let go (budget in decision 004).
    static let patience: Duration = .seconds(8)

    /// Text to fields. The floor first, always, and on screen at once: a draft with a title can be kept the moment the
    /// rules have read it. Then the model, with the floor's draft in hand (ADR-010), for as long as `patience` allows. Its
    /// answer is laid over the floor's, field by field, so a field the model leaves empty keeps what the rules read.
    /// While the floor has no title the model's snapshots stream to `partial`, title first. Whatever happens, a draft.
    static func understand(
        _ reading: StubReading,
        using parser: (any StubParsing)? = nil,
        progress: @Sendable @MainActor (Stage) -> Void,
        partial: (@Sendable @MainActor (StubDraft) -> Void)? = nil
    ) async -> StubDraft {
        let parser = parser ?? preferredParser()
        await progress(.understanding(parser: parser.name))

        // The floor first: it is cheap, it is the fallback, and it is the model's hint. Shown now, not after the model.
        let floor = HeuristicParser.parse(reading)
        var draft = floor
        if floor.isUsable { await partial?(floor) }
        if #available(iOS 26.0, *), let model = parser as? ModelParser {
            let started = ContinuousClock.now
            let streamsToScreen = !floor.isUsable
            // A race that stops waiting at the deadline: a task group would wait for the model's stream to wind down after
            // being cancelled, and a stream on a busy phone winds down slowly (measured: 14 s against an 8 s patience).
            let outcome = await Deadline.race(patience) {
                var last: StubDraft?
                var titleAt: Duration?
                for try await snapshot in model.stream(reading, hint: floor) {
                    if titleAt == nil, snapshot.isUsable { titleAt = started.duration(to: .now) }
                    last = snapshot
                    if streamsToScreen { await partial?(snapshot) }
                }
                let ms = { (d: Duration?) in d.map { "\(Int($0 / .milliseconds(1))) ms" } ?? "never" }
                log.info("Model streamed: title at \(ms(titleAt)), done at \(ms(started.duration(to: .now)))")
                return last
            }
            switch outcome {
            case .finished(let last?) where last.isUsable:
                draft = last.over(floor)
            case .finished:
                log.notice("Model returned no title; the rules' draft stands")
            case .failed(let error):
                log.error("\(parser.name) failed: \(ModelProbe.explain(error)). Using heuristics.")
            case .timedOut:
                log.notice("Model let go after \(Int(patience / .seconds(1))) s; the rules' draft stands")
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

/// Whichever comes first: the work, or the deadline. Unlike a task group, it returns at the deadline without waiting for the
/// work to wind down; the work is cancelled and left to finish on its own.
enum Deadline {
    enum Outcome<Value: Sendable>: Sendable {
        case finished(Value)
        case failed(any Error)
        case timedOut
    }

    static func race<Value: Sendable>(_ limit: Duration, _ work: @escaping @Sendable () async throws -> Value) async -> Outcome<Value> {
        let once = Once<Outcome<Value>>()
        return await withCheckedContinuation { continuation in
            once.set(continuation)
            let job = Task {
                do { once.resume(.finished(try await work())) } catch { once.resume(.failed(error)) }
            }
            Task {
                try? await Task.sleep(for: limit)
                if once.resume(.timedOut) { job.cancel() }
            }
        }
    }

    /// A continuation resumed exactly once, by whichever side gets there first.
    private final class Once<T: Sendable>: @unchecked Sendable {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<T, Never>?
        private var done = false

        func set(_ continuation: CheckedContinuation<T, Never>) {
            lock.lock(); defer { lock.unlock() }
            self.continuation = continuation
        }

        /// Whether this call was the one that resumed it.
        @discardableResult
        func resume(_ value: T) -> Bool {
            lock.lock()
            guard !done, let continuation else { lock.unlock(); return false }
            done = true
            self.continuation = nil
            lock.unlock()
            continuation.resume(returning: value)
            return true
        }
    }
}
