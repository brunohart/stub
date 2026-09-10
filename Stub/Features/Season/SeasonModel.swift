import Foundation
import Observation
import OSLog

/// The one italic sentence, and the numbers under it. Counted by hand the instant the drawer changes;
/// phrased by the on-device model a moment later, once the reader is idle, and cached against the drawer's
/// hash so the model is asked once per drawer, not once per launch.
@MainActor @Observable
final class SeasonModel {
    enum Author: Equatable { case hand, model }

    private(set) var summary = SeasonSummary()
    private(set) var sentence: String = SeasonSummary().handSentence
    private(set) var author: Author = .hand

    /// How long the drawer has to sit still before the model is asked. An import files one stub; a seed files
    /// eight in a row, and each one would otherwise start a sentence the next one cancels.
    static let settle: Duration = .milliseconds(1500)

    /// Called from `.task(id: summary.key)`: the previous call is cancelled when the drawer changes, so a
    /// sentence is only ever written for the drawer as it is now.
    func update(_ new: SeasonSummary) async {
        summary = new
        if let cached = SeasonCache.sentence(for: new.key) {
            sentence = cached
            author = .model
            SeasonWriter.log.info("Season (\(new.films) stubs): cached: \"\(cached)\"")
            return
        }
        sentence = new.handSentence
        author = .hand
        guard new.films >= 1 else { return }   // the empty drawer's line is product copy, not a summary
        guard #available(iOS 26.0, *), ModelParser.isAvailable, ModelProbe.outcome.allowsModel else {
            SeasonWriter.log.info("Season (\(new.films) stubs): hand-counted; \(StubReader.modelStatus)")
            return
        }
        do {
            try await Task.sleep(for: Self.settle)
            // The reader has the model's attention; the sentence can wait for it.
            while StubReader.isBusy { try await Task.sleep(for: .seconds(1)) }
            let started = ContinuousClock.now
            let written = try await SeasonWriter.write(new)
            let ms = Int(started.duration(to: .now) / .milliseconds(1))
            guard !Task.isCancelled else { return }
            SeasonCache.store(written, for: new.key)
            sentence = written
            author = .model
            SeasonWriter.log.info("Season (\(new.films) stubs): written by the model in \(ms) ms: \"\(written)\"")
        } catch is CancellationError {
            return
        } catch {
            SeasonWriter.log.error("Season (\(new.films) stubs): hand-counted; \(ModelProbe.explain(error))")
        }
    }
}
