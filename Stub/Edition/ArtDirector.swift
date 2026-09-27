import Foundation
import FoundationModels
import Observation
import OSLog
import Synchronization

/// The words the model chooses between: the genome's lists, spelled out. A test holds them to `Genome`, so the
/// model can never choose a thing the code cannot draw.
enum Vocabulary {
    static let movements = ["swiss", "constructivist", "deco", "cutout", "riso", "letterpress", "blueprint", "noir"]
    static let palettes = ["sand", "night", "ember", "tide", "moss", "chalk", "bruise", "oxide", "cobalt", "citrus", "blush", "smoke"]
    static let stocks = ["cotton", "coated", "foil", "holographic"]

    /// What each word means. The model reads this; the code never does.
    static let glossary = """
        Movements:
        swiss: International Typographic Style; a huge flush-left title, a strict grid, one shape. Restrained, modern, urban, cerebral films.
        constructivist: diagonals, a band, a circle, bars; the title up the diagonal. Political, epic, industrial, revolutionary films.
        deco: symmetry, a sunburst, stepped frames, a light spaced title. Period glamour, musicals, jazz age, grand spectacle.
        cutout: cut and torn paper after Saul Bass, one bold field. Thrillers, crime, suspense, jazz.
        riso: risograph; a halftone, two inks overprinted a little out of register. Independent films, youth, comedy, romance, festivals.
        letterpress: deep serif type, one ink, generous margins. Quiet, literary, slow, intimate drama.
        blueprint: a technical drawing in a monospaced face. Science fiction, heists, space, engineering, puzzles.
        noir: a dark field, light through a venetian blind, an italic title. Film noir, horror, mystery, night.
        Palettes:
        sand: sun, heat, desert, distance. night: city at night, loneliness, cold blue. ember: fire, rage, violence, passion.
        tide: the sea, summer, memory, grief. moss: nature, the rural, folklore, quiet. chalk: stark black and white with one orange.
        bruise: love, longing, desire, heartbreak. oxide: architecture, ambition, industry, weight. cobalt: science, space, precision.
        citrus: comedy, youth, lightness, holidays. blush: romance, tenderness, family, warmth. smoke: crime, dread, horror.
        Stocks:
        cotton: soft uncoated card; quiet, intimate films. coated: smooth satin card; most films.
        foil: a metal foil stamp; prestige, glamour, period, grandeur. holographic: an iridescent film stamp; spectacle, science fiction, IMAX.
        """
}

/// The rules the model's choice must keep, checked on the way out (ADR-011's lesson: an instruction is a hope,
/// a check is a rule). Guided generation should make a word outside the vocabulary impossible; this makes it
/// impossible to draw.
enum EditionRules {
    enum Verdict: Equatable {
        case accepted(Movement, Palette, Stock)
        case rejected(String)
    }

    static func judge(movement: String, palette: String, stock: String) -> Verdict {
        func word(_ s: String) -> String { s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        guard let m = Movement(rawValue: word(movement)) else { return .rejected("movement '\(movement)'") }
        guard let p = Palette(rawValue: word(palette)) else { return .rejected("palette '\(palette)'") }
        guard let s = Stock(rawValue: word(stock)) else { return .rejected("stock '\(stock)'") }
        return .accepted(m, p, s)
    }
}

/// What the model is asked to fill: three words, in the order a designer would choose them.
@available(iOS 26.0, *)
@Generable
struct Direction: Sendable {
    @Guide(description: "The design movement the ticket is laid out in.", .anyOf(Vocabulary.movements))
    var movement: String
    @Guide(description: "The palette of inks it is printed in.", .anyOf(Vocabulary.palettes))
    var palette: String
    @Guide(description: "The paper stock it is printed on.", .anyOf(Vocabulary.stocks))
    var stock: String
}

/// Asks the on-device model to art-direct a release. The model chooses the movement, the palette and the stock;
/// the composition under them is the release's hash, always (ADR-015).
@available(iOS 26.0, *)
enum ArtDirector {
    static func session() -> LanguageModelSession {
        LanguageModelSession(instructions: """
            You art-direct a commemorative cinema ticket for one film release. From fixed lists you choose a design \
            movement, a palette of inks and a paper stock that suit the film's tone, genre and era as you know them. \
            If you do not know the film, choose from the sound of its title. Choose; do not explain.

            \(Vocabulary.glossary)
            """)
    }

    /// Only what the stub knows: the title as printed, the year it was seen, the screen when it says something
    /// ("IMAX" does; "2" does not).
    static func prompt(title: String, year: Int?, screen: String?) -> String {
        var lines = ["Film: \(title)"]
        if let year { lines.append("Seen: \(year)") }
        if let screen, !screen.allSatisfy(\.isNumber) { lines.append("Screen: \(screen)") }
        return lines.joined(separator: "\n")
    }

    struct Rejected: LocalizedError {
        let reason: String
        var errorDescription: String? { "the model's direction broke a rule (\(reason))" }
    }

    /// The model's edition for the release `floor` belongs to: its choice, judged, over the floor's seed.
    static func direct(_ floor: Edition, title: String, year: Int?, screen: String?) async throws -> Edition {
        // Greedy: the same film, the same model, the same choice, on every phone. `samplingMode` is the iOS 27 SDK's
        // name for `sampling`, back-deployed to 26.
        let options = GenerationOptions(samplingMode: .greedy)
        let response: LanguageModelSession.Response<Direction>
        do {
            response = try await session().respond(to: prompt(title: title, year: year, screen: screen),
                                                   generating: Direction.self, options: options)
        } catch let error as LanguageModelSession.GenerationError {
            throw ModelParser.ModelFailure(reason: ModelParser.describe(error))
        }
        let d = response.content
        switch EditionRules.judge(movement: d.movement, palette: d.palette, stock: d.stock) {
        case .accepted(let movement, let palette, let stock):
            return Edition(release: floor.release, movement: movement, palette: palette, stock: stock,
                           seed: floor.seed, directedBy: .model)
        case .rejected(let reason):
            throw Rejected(reason: reason)
        }
    }
}

/// Every release's edition, as printed. One entry per release in one dictionary, kept against the release key.
/// Never pruned and never re-asked: an edition already printed does not reprint itself.
enum EditionCache {
    static let keyName = "edition.printed"

    static func all(in defaults: UserDefaults = .standard) -> [String: Edition] {
        guard let data = defaults.data(forKey: keyName),
              let editions = try? JSONDecoder().decode([String: Edition].self, from: data) else { return [:] }
        return editions
    }

    static func store(_ edition: Edition, in defaults: UserDefaults = .standard) {
        var editions = all(in: defaults)
        editions[edition.release] = edition
        if let data = try? JSONEncoder().encode(editions) { defaults.set(data, forKey: keyName) }
    }

    static func clear(in defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: keyName)
    }
}

/// Every release's edition, decided once, and the proof pulled over it, if any. Asked for a release it has not
/// printed, it gives the model a while to choose (when there is a model), falls back to the floor, and keeps whichever
/// it printed.
///
/// `edition(for:)` is the one seam where a proof is applied (ADR-016): the detail, the print run and the share all get
/// the proof without knowing it exists. The edition underneath is never overwritten, so going back is deleting the
/// proof.
@MainActor @Observable
final class Editions {
    static let shared = Editions()
    static let log = Logger(subsystem: "com.designedbybruno.stub", category: "edition")
    /// How long the press waits for the model before printing the floor. The print run says it is choosing.
    static let patience: Duration = .seconds(12)

    /// Every release's edition as the hash or the model printed it.
    private(set) var printed: [String: Edition]
    /// Every release's last pulled proof.
    private(set) var proofs: [String: Proof]
    private var deciding: [String: Task<Edition, Never>] = [:]
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        var printed = EditionCache.all(in: defaults)
        // Version 1 was retired, not frozen: nothing had shipped (ADR-016). The movement, the palette, the stock and
        // who chose them are kept; the composition under them is drawn at the current version from now on.
        for (key, edition) in printed where edition.version < Genome.version {
            var redrawn = edition
            redrawn.version = Genome.version
            printed[key] = redrawn
            EditionCache.store(redrawn, in: defaults)
            Self.log.notice("Edition '\(key)': printed at version \(edition.version), redrawn at version \(Genome.version)")
        }
        self.printed = printed
        proofs = ProofCache.all(in: defaults)
        #if DEBUG
        for edition in printed.values { pullDebugProof(over: edition) }
        #endif
    }

    /// The release's edition as it is shown, its pulled proof laid over it; `nil` means the next look at it will
    /// print it.
    func edition(for title: String) -> Edition? {
        let key = Release.key(for: title)
        return printed[key]?.applying(proofs[key])
    }

    /// The edition as the hash or the model printed it, under any proof: what "going back" goes back to.
    func underneath(for title: String) -> Edition? {
        printed[Release.key(for: title)]
    }

    /// The release's last pulled proof.
    func proof(for title: String) -> Proof? {
        proofs[Release.key(for: title)]
    }

    /// Keep `proof` as its release's pulled proof. A proof that differs in nothing is not a proof: it is going back.
    func pull(_ proof: Proof, at date: Date = .now) {
        guard let underneath = printed[proof.release] else { return }
        guard underneath.applying(proof) != underneath else {
            discardProof(release: proof.release)
            return
        }
        var pulled = proof
        pulled.pulledAt = pulled.pulledAt ?? date
        proofs[proof.release] = pulled
        ProofCache.store(pulled, in: defaults)
    }

    /// Going back: the proof is deleted and the edition underneath shows again, exactly as it was.
    func discardProof(release: String) {
        proofs[release] = nil
        ProofCache.remove(release: release, in: defaults)
    }

    /// Keep an edition as printed. The model and the floor come in through `decide`; this is for a test, and for a
    /// release printed some other way in future.
    func store(_ edition: Edition) {
        printed[edition.release] = edition
        EditionCache.store(edition, in: defaults)
    }

    /// The release's edition, its proof laid over it: the one already printed, or one decided now and kept.
    func decide(title: String, year: Int?, screen: String?) async -> Edition {
        let key = Release.key(for: title)
        if printed[key] == nil {
            if let running = deciding[key] {
                _ = await running.value
            } else {
                let task = Task { await Self.choose(title: title, year: year, screen: screen) }
                deciding[key] = task
                let edition = await task.value
                deciding[key] = nil
                store(edition)
                #if DEBUG
                pullDebugProof(over: edition)
                #endif
            }
        }
        return edition(for: title) ?? Genome.floor(for: title)
    }

    #if DEBUG
    /// `-proof "disc=14,bars=3"`: pull a proof over every release that has none yet, those already printed at launch
    /// and the rest as they are printed, so a take can be screenshotted without hands (ADR-009: `DebugDrive`, not a
    /// third mechanism).
    private func pullDebugProof(over edition: Edition) {
        guard let spec = DebugDrive.proofSpec, proofs[edition.release] == nil else { return }
        let (proof, unread) = Proof.parsing(spec, over: edition)
        if !unread.isEmpty { Self.log.error("-proof: could not read \(unread.joined(separator: ", ")) for \(edition.movement.rawValue)") }
        pull(proof)
        let json = proofs[edition.release].map { String(decoding: $0.json, as: UTF8.self) } ?? "nothing (it differs in nothing)"
        Self.log.info("Edition '\(edition.release)': pulled from -proof: \(json)")
    }
    #endif

    private struct Impatient: Error {}

    /// The model's answer or the end of the press's patience, whichever comes first. Unstructured on purpose: a task
    /// group waits for every child before it returns, so a model slow to notice it was cancelled would keep the press
    /// waiting past its patience. Here the loser is cancelled and nobody waits for it.
    private static func race(patience: Duration, _ work: @escaping @Sendable () async throws -> Edition) async throws -> Edition {
        let once = Once()
        return try await withCheckedThrowingContinuation { continuation in
            let job = Task {
                do {
                    let edition = try await work()
                    if once.claim() { continuation.resume(returning: edition) }
                } catch {
                    if once.claim() { continuation.resume(throwing: error) }
                }
            }
            Task {
                try? await Task.sleep(for: patience)
                if once.claim() {
                    job.cancel()
                    continuation.resume(throwing: Impatient())
                }
            }
        }
    }

    /// True for the first caller only: a continuation is resumed exactly once.
    private final class Once: Sendable {
        private let done = Mutex(false)

        func claim() -> Bool {
            done.withLock { done in
                if done { return false }
                done = true
                return true
            }
        }
    }

    private static func choose(title: String, year: Int?, screen: String?) async -> Edition {
        let floor = Genome.floor(for: title)
        let summary = { (e: Edition) in "\(e.movement.rawValue), \(e.palette.rawValue), \(e.stock.rawValue)" }
        guard #available(iOS 26.0, *), ModelParser.isAvailable, ModelProbe.outcome.allowsModel else {
            log.info("Edition '\(floor.release)': drawn from the title (\(summary(floor))); \(StubReader.modelStatus)")
            return floor
        }
        let patience = Self.patience
        let started = ContinuousClock.now
        do {
            let edition = try await Self.race(patience: patience) {
                // The reader has the model's attention first, as the season waits for it (ADR-011).
                while StubReader.isBusy { try await Task.sleep(for: .milliseconds(500)) }
                return try await ArtDirector.direct(floor, title: title, year: year, screen: screen)
            }
            let ms = Int(started.duration(to: .now) / .milliseconds(1))
            log.info("Edition '\(floor.release)': chosen by the model in \(ms) ms (\(summary(edition))); the floor was \(summary(floor))")
            return edition
        } catch is Impatient {
            log.notice("Edition '\(floor.release)': the model took longer than \(patience); drawn from the title (\(summary(floor)))")
            return floor
        } catch {
            log.error("Edition '\(floor.release)': drawn from the title (\(summary(floor))); \(ModelProbe.explain(error))")
            return floor
        }
    }
}
