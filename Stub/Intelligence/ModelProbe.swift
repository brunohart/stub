import Foundation
import FoundationModels
import OSLog
import Synchronization

/// Asks the on-device model one small question at launch and remembers the answer.
///
/// `SystemLanguageModel.availability` says whether the model *should* work. On Day 0 it said `.available`
/// in the simulator and then every request failed with `ModelManagerError 1026`. The status line in the
/// import screen has to be honest, so we probe once, cache the outcome, and let the reader skip the model
/// when it is known to be broken. The heuristic parser is the floor either way (ADR-001).
@available(iOS 26.0, *)
enum ModelProbe {
    static let log = Logger(subsystem: "com.designedbybruno.stub", category: "probe")

    enum Outcome: Equatable, Sendable {
        case untested
        case unavailable(String)
        case ready
        case failed(String)

        /// The one line the import screen shows.
        var statusLine: String {
            switch self {
            case .untested: return "On-device model not yet probed"
            case .unavailable(let reason): return reason
            case .ready: return "On-device model ready"
            case .failed: return "On-device model answered with an error; reading with heuristics"
            }
        }

        /// Whether the reader should bother asking the model.
        var allowsModel: Bool {
            switch self {
            case .untested, .ready: return true
            case .unavailable, .failed: return false
            }
        }
    }

    private static let state = Mutex<Outcome>(.untested)

    static var outcome: Outcome { state.withLock { $0 } }

    /// Probe once. Later calls return the cached outcome without touching the model again.
    @discardableResult
    static func run(timeout: Duration = .seconds(12)) async -> Outcome {
        if case .untested = outcome {} else { return outcome }

        if let reason = ModelParser.unavailabilityReason() {
            return record(.unavailable(reason))
        }

        let started = ContinuousClock.now
        do {
            let answer = try await withThrowingTaskGroup(of: String.self) { group in
                group.addTask {
                    let session = LanguageModelSession(instructions: "Answer with one word.")
                    var options = GenerationOptions()
                    options.maximumResponseTokens = 1
                    let response = try await session.respond(to: "Say ready.", options: options)
                    return response.content
                }
                group.addTask {
                    try await Task.sleep(for: timeout)
                    throw ProbeTimeout()
                }
                let first = try await group.next() ?? ""
                group.cancelAll()
                return first
            }
            let ms = Int(started.duration(to: .now) / .milliseconds(1))
            log.info("Model answered '\(answer.trimmingCharacters(in: .whitespacesAndNewlines))' in \(ms) ms")
            return record(.ready)
        } catch {
            let explained = explain(error)
            log.error("Model probe failed: \(explained)")
            return record(.failed(explained))
        }
    }

    struct ProbeTimeout: Error {}

    private static func record(_ outcome: Outcome) -> Outcome {
        state.withLock { $0 = outcome }
        log.info("Model probe: \(outcome.statusLine)")
        return outcome
    }

    /// Name the failure in plain English, with the underlying error chain so the log teaches something.
    static func explain(_ error: any Error) -> String {
        if error is ProbeTimeout { return "the model did not answer in time (timeout); the assets may still be loading" }
        var parts: [String] = []
        if let generation = error as? LanguageModelSession.GenerationError {
            parts.append(ModelParser.describe(generation))
        }
        // The framework throws a plain NSError whose chain hangs off NSMultipleUnderlyingErrorsKey, not
        // NSUnderlyingErrorKey, and the `GenerationError` cast fails. Walk both keys, keep the deepest reason.
        var codes: [(domain: String, code: Int)] = []
        var reason: String?
        var cursor: NSError? = error as NSError
        var depth = 0
        while let e = cursor, depth < 6 {
            codes.append((e.domain, e.code))
            if let r = e.userInfo[NSLocalizedFailureReasonErrorKey] as? String { reason = r }
            if let one = e.userInfo[NSUnderlyingErrorKey] as? NSError {
                cursor = one
            } else if let many = e.userInfo[NSMultipleUnderlyingErrorsKey] as? [NSError], let first = many.first {
                cursor = first
            } else {
                cursor = nil
            }
            depth += 1
        }
        parts.append(codes.map { "\($0.domain) \($0.code)" }.joined(separator: " ← "))
        if let reason { parts.append(reason) }
        if let guess = guess(for: codes) { parts.append(guess) }
        return parts.joined(separator: " · ")
    }

    /// Folklore about ModelManager error codes, collected one failure at a time. A guess, and labelled as one.
    static func guess(for codes: [(domain: String, code: Int)]) -> String? {
        if codes.contains(where: { $0.domain.contains("UnifiedAssetFramework") && $0.code == 5000 }) {
            return "guess: the model catalog has no assets on this host; on the simulator that is the Mac's own Apple Intelligence download (System Settings → Apple Intelligence & Siri), and it has to finish before the simulator can borrow it"
        }
        for (domain, code) in codes where domain.contains("ModelManager") {
            switch code {
            case 1026: return "guess: the model assets are not installed for this host; on the simulator that means the Mac's own Apple Intelligence download (System Settings → Apple Intelligence & Siri)"
            case 1000...1025: return "guess: the model catalog or asset request failed; check Apple Intelligence is on and the Mac is online"
            default: return "guess: ModelManager could not serve the model; see the code above"
            }
        }
        return nil
    }
}
