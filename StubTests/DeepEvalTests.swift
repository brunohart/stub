import Testing
import Foundation
import CoreGraphics
import FoundationModels
import Synchronization
@testable import Stub

/// How many times the deep eval asks each question: `STUB_EVAL_RUNS`, 0 when it is not set. Outside the suite, because a
/// suite's traits cannot refer to the suite.
enum DeepEval {
    static var runs: Int { Int(ProcessInfo.processInfo.environment["STUB_EVAL_RUNS"] ?? "") ?? 0 }
}

/// The deep eval (2026-09-30). One pass of `EvalTests` is one sample of a reader that is not the same twice (Day 3), and
/// it says nothing about the season sentence or the editions. This asks again, `runs` times each:
///
/// - every fixture read cold, with the heuristic's hint, streamed with the hint as the app reads it (and filed as the app
///   files it), and cold without the line that tells the cold prompt a bare `$` is NZD, so the line goes on earning its
///   place (it took the cold price from 2/9 to 8/9 on its first run);
/// - the season sentence written for three drawers, watching every attempt and what the rules said;
/// - every release art-directed, to see whether greedy sampling gives the same edition every time, as `ArtDirector`
///   says it does, and how often the model answers inside the press's twelve seconds.
///
/// It writes `docs/evals-deep.md`. It asks the model a few hundred times, so it is off unless `STUB_EVAL_RUNS` is set:
/// `scripts/eval.sh` sets it, `scripts/test.sh` does not.
@Suite(.enabled(if: DeepEval.runs > 0, "set STUB_EVAL_RUNS (scripts/eval.sh) to run the deep eval"))
struct DeepEvalTests {
    static var runs: Int { DeepEval.runs }

    typealias Truth = EvalTests.Truth
    typealias Run = EvalTests.Run

    /// The readers, in the order the table prints them.
    static let readers = ["heuristic", "model", "model + hint", "streamed, as filed", "model, no $ line"]

    struct ReaderSample: Sendable {
        var truth: Truth
        var run: Int
        /// Keyed by reader name.
        var runs: [String: Run]
        var titleMs: Int?
        var seatMs: Int?
    }

    struct Attempt: Sendable {
        var number: Int
        var wrote: String
        var verdict: SeasonRules.Verdict
        var ms: Int
    }

    struct SeasonSample: Sendable {
        var drawer: String
        var attempts: [Attempt]
        var sentence: String?
        var error: String?
    }

    struct EditionSample: Sendable {
        var truth: Truth
        var release: String
        var floor: Edition
        var edition: Edition?
        var ms: Int
        var error: String?
    }

    @Test func theDeepEvalWritesItsTables() async throws {
        guard #available(iOS 26.0, *) else { return }
        let outcome = await ModelProbe.run(timeout: .seconds(30))
        try #require(outcome == .ready || outcome.allowsModel && outcome != .untested,
                     "the deep eval needs the model: \(outcome.statusLine)")
        let n = Self.runs
        let truths = try EvalTests.truths()
        let reader = try await Self.readTheFixtures(truths, runs: n)
        let season = await Self.writeTheSeason(truths, runs: n)
        let editions = await Self.directTheEditions(truths, runs: n)
        let markdown = await Self.render(reader: reader, season: season, editions: editions, runs: n, truths: truths)
        try markdown.write(to: EvalTests.repoRoot.appendingPathComponent("docs/evals-deep.md"), atomically: true, encoding: .utf8)
        #expect(reader.count == truths.count * n)
    }

    // MARK: - The reader

    @available(iOS 26.0, *)
    static func readTheFixtures(_ truths: [Truth], runs n: Int) async throws -> [ReaderSample] {
        let clock = ContinuousClock()
        var samples: [ReaderSample] = []
        for truth in truths {
            let cg = try EvalTests.fixture(truth.name)
            let crop = await StubCrop.crop(cg)
            let reading: StubReading
            if let read = try? await StubVision.read(crop.image) { reading = read } else { reading = try await StubVision.read(cg) }
            let heuristic = HeuristicParser.parse(reading)
            for run in 1...n {
                print("deep eval: reading \(truth.name), run \(run) of \(n)")
                var runs = ["heuristic": Run(name: "heuristic", draft: heuristic, ms: 0)]
                runs["model"] = await EvalTests.ask(ModelParser(), reading, hint: nil, name: "model")
                runs["model + hint"] = await EvalTests.ask(ModelParser(), reading, hint: heuristic, name: "model + hint")

                // As the app reads: streamed with the hint, and filed as `StubReader.understand` files it, the heuristic's
                // draft standing when the model's has no title.
                let t0 = clock.now
                var last: StubDraft?, titleMs: Int?, seatMs: Int?, failure: String?
                do {
                    for try await snapshot in ModelParser().stream(reading, hint: heuristic) {
                        if titleMs == nil, snapshot.isUsable { titleMs = EvalTests.ms(t0.duration(to: clock.now)) }
                        if seatMs == nil, !snapshot.seat.isEmpty { seatMs = EvalTests.ms(t0.duration(to: clock.now)) }
                        last = snapshot
                    }
                } catch {
                    failure = ModelProbe.explain(error)
                }
                let filed = last.flatMap { $0.isUsable ? $0 : nil } ?? heuristic
                runs["streamed, as filed"] = Run(name: "streamed", draft: filed, ms: EvalTests.ms(t0.duration(to: clock.now)), error: failure)

                runs["model, no $ line"] = await askWithoutTheDollarLine(reading)
                samples.append(ReaderSample(truth: truth, run: run, runs: runs, titleMs: titleMs, seatMs: seatMs))
            }
        }
        return samples
    }

    /// The cold prompt as it was until 2026-09-30, without the line saying a bare $ is NZD: kept as a column so the line
    /// goes on earning its place.
    @available(iOS 26.0, *)
    static func askWithoutTheDollarLine(_ reading: StubReading) async -> Run {
        let clock = ContinuousClock()
        let t0 = clock.now
        let prompt = ModelParser.prompt(reading, hint: nil).replacingOccurrences(of: "\n\n" + ModelParser.bareDollar, with: "")
        do {
            let response = try await ModelParser.session().respond(to: prompt, generating: ModelParser.Generated.self)
            return Run(name: "model, no $ line", draft: ModelParser.draft(from: response.content), ms: EvalTests.ms(t0.duration(to: clock.now)))
        } catch {
            return Run(name: "model, no $ line", draft: StubDraft(), ms: EvalTests.ms(t0.duration(to: clock.now)), error: ModelProbe.explain(error))
        }
    }

    // MARK: - The season

    /// Three drawers: all nine fixtures, the four from Day 0, and one stub in euros.
    static func drawers(_ truths: [Truth]) -> [(name: String, stubs: [Stub])] {
        func stub(_ t: Truth) -> Stub {
            Stub(title: t.title, cinema: t.cinema, screenedAt: EvalTests.dateFormatter.date(from: t.screenedAt), screen: t.screen,
                 seat: t.seat, price: Decimal(string: t.price), currency: t.currency.isEmpty ? nil : t.currency)
        }
        let all = truths.map(stub)
        let first = truths.filter { t in ["stub-1", "stub-2", "stub-3", "stub-4"].contains { t.name.hasPrefix($0 + "-") } }.map(stub)
        let euro = truths.filter { $0.currency == "EUR" }.prefix(1).map(stub)
        return [("all nine", all), ("the first four", first), ("one in euros", Array(euro))]
    }

    @available(iOS 26.0, *)
    static func writeTheSeason(_ truths: [Truth], runs n: Int) async -> [SeasonSample] {
        var samples: [SeasonSample] = []
        for drawer in drawers(truths) where !drawer.stubs.isEmpty {
            let summary = SeasonSummary(stubs: drawer.stubs)
            for run in 1...n {
                print("deep eval: the season for \(drawer.name), run \(run) of \(n)")
                let recorder = Recorder()
                var sample = SeasonSample(drawer: drawer.name, attempts: [])
                do {
                    sample.sentence = try await SeasonWriter.write(summary) { number, wrote, verdict in
                        recorder.record(number, wrote, verdict)
                    }
                } catch {
                    sample.error = ModelProbe.explain(error)
                }
                sample.attempts = recorder.attempts
                samples.append(sample)
            }
        }
        return samples
    }

    /// Every attempt the season writer makes, timed from the one before it (or from when this was made).
    final class Recorder: Sendable {
        private let clock = ContinuousClock()
        private let state: Mutex<(since: ContinuousClock.Instant, attempts: [Attempt])>

        init() { state = Mutex((ContinuousClock().now, [])) }

        func record(_ number: Int, _ wrote: String, _ verdict: SeasonRules.Verdict) {
            let now = clock.now
            state.withLock { s in
                s.attempts.append(Attempt(number: number, wrote: wrote, verdict: verdict, ms: EvalTests.ms(s.since.duration(to: now))))
                s.since = now
            }
        }

        var attempts: [Attempt] { state.withLock { $0.attempts } }
    }

    // MARK: - The editions

    @available(iOS 26.0, *)
    static func directTheEditions(_ truths: [Truth], runs n: Int) async -> [EditionSample] {
        var samples: [EditionSample] = []
        var seen: Set<String> = []
        for truth in truths {
            let release = Release.key(for: truth.title)
            guard seen.insert(release).inserted else { continue }   // the second Dune is the first's release
            let floor = Genome.floor(for: truth.title)
            let year = EvalTests.dateFormatter.date(from: truth.screenedAt).map { Calendar.current.component(.year, from: $0) }
            for run in 1...n {
                print("deep eval: the edition for \(release), run \(run) of \(n)")
                let clock = ContinuousClock()
                let t0 = clock.now
                do {
                    let edition = try await ArtDirector.direct(floor, title: truth.title, year: year, screen: truth.screen)
                    samples.append(EditionSample(truth: truth, release: release, floor: floor, edition: edition, ms: EvalTests.ms(t0.duration(to: clock.now))))
                } catch {
                    samples.append(EditionSample(truth: truth, release: release, floor: floor, edition: nil,
                                                 ms: EvalTests.ms(t0.duration(to: clock.now)), error: ModelProbe.explain(error)))
                }
            }
        }
        return samples
    }

    // MARK: - Rendering

    /// "once", "twice", "3 times".
    static func times(_ n: Int) -> String { n == 1 ? "once" : n == 2 ? "twice" : "\(n) times" }

    /// A model's answer as the report quotes it: on one line, and cut short when it runs on.
    static func quoted(_ s: String) -> String {
        let one = s.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return one.count > 160 ? String(one.prefix(157)) + "…" : one
    }

    @MainActor static func render(reader: [ReaderSample], season: [SeasonSample], editions: [EditionSample], runs n: Int, truths: [Truth]) -> String {
        let stamp = Date.now.formatted(Date.ISO8601FormatStyle(timeZone: .current).year().month().day())
        let os = ProcessInfo.processInfo.operatingSystemVersion
        var md = "# Deep evals\n\n"
        md += "Generated by `StubTests/DeepEvalTests.swift` (`scripts/eval.sh \(n)`) on \(stamp), in the iOS \(os.majorVersion).\(os.minorVersion) simulator: "
        md += "every question asked \(times(n)). `docs/evals.md` is one pass of the reader; this is how much a pass can be trusted, "
        md += "and the two things the model does that the reader's table does not cover.\n\n"
        md += renderReader(reader, runs: n, truths: truths)
        md += renderSeason(season, runs: n)
        md += renderEditions(editions, runs: n)
        return md
    }

    static func renderReader(_ samples: [ReaderSample], runs n: Int, truths: [Truth]) -> String {
        var md = "## The reader, \(times(n)) over\n\n"
        md += "Each cell is the fewest and the most fixtures a reader got right in one run, of \(truths.count). "
        md += "*Streamed, as filed* is the app's own path: the hinted model streamed, and the heuristic's draft kept when the model's has no title. "
        md += "*Model* is cold, as the app asks when the heuristic found no title, which since 2026-09-30 includes one line: \"\(ModelParser.bareDollar)\" "
        md += "*Model, no $ line* is the same prompt without it.\n\n"
        md += "| Field | " + readers.joined(separator: " | ") + " |\n|---|" + readers.map { _ in "---" }.joined(separator: "|") + "|\n"
        for field in EvalTests.fields {
            let cells = readers.map { reader -> String in
                let perRun = (1...n).map { run in
                    samples.filter { $0.run == run }.filter { s in s.runs[reader].map { EvalTests.hit(field, $0.draft, s.truth) } ?? false }.count
                }
                let lo = perRun.min() ?? 0, hi = perRun.max() ?? 0
                return lo == hi ? "\(lo)/\(truths.count)" : "\(lo)–\(hi)/\(truths.count)"
            }
            md += "| \(field) | " + cells.joined(separator: " | ") + " |\n"
        }

        md += "\n### Answers that changed between runs\n\n"
        md += "A fixture's field counts once if any two runs of a reader gave it different answers.\n\n"
        md += "| Reader | changed | of |\n|---|---|---|\n"
        var changes: [String: [String]] = [:]
        for reader in readers {
            var changed: [String] = []
            for truth in truths {
                let runs = samples.filter { $0.truth.name == truth.name }.compactMap { $0.runs[reader] }
                for field in EvalTests.fields {
                    let answers = runs.map { $0.error == nil ? EvalTests.value(field, $0.draft) : "error" }
                    let distinct = answers.reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
                    if distinct.count > 1 {
                        changed.append("\(truth.name) · \(field): " + distinct.map { $0.isEmpty ? "—" : $0 }.joined(separator: " / "))
                    }
                }
            }
            changes[reader] = changed
            md += "| \(reader) | \(changed.count) | \(truths.count * EvalTests.fields.count) |\n"
        }
        for reader in readers where !(changes[reader] ?? []).isEmpty {
            md += "\n**\(reader)**\n\n" + (changes[reader] ?? []).map { "- \($0)\n" }.joined()
        }

        md += "\n### Latency, every run\n\n| Reader | median ms | max ms | errors |\n|---|---|---|---|\n"
        for reader in readers.dropFirst() {
            let runs = samples.compactMap { $0.runs[reader] }
            let times = runs.map(\.ms)
            md += "| \(reader) | \(EvalTests.median(times)) | \(times.max() ?? 0) | \(runs.filter { $0.error != nil }.count) |\n"
        }
        let titles = samples.compactMap(\.titleMs), seats = samples.compactMap(\.seatMs)
        md += "\nStreamed, the title was in the import field at a median \(EvalTests.median(titles)) ms (max \(titles.max() ?? 0)) "
        md += "and the seat at \(EvalTests.median(seats)) ms (max \(seats.max() ?? 0)); "
        md += "\(samples.count - titles.count) of \(samples.count) streams never showed a title.\n\n"
        return md
    }

    static func renderSeason(_ samples: [SeasonSample], runs n: Int) -> String {
        var md = "## The season sentence, \(times(n)) a drawer\n\n"
        md += "`SeasonWriter.write` as the app calls it: a refused sentence gets one retry with the reason. "
        md += "*First try* is how often the model kept every rule unprompted.\n\n"
        md += "| Drawer | kept first try | kept on the retry | refused twice | failed | median words kept | median ms, first try |\n|---|---|---|---|---|---|---|\n"
        var drawers: [String] = []
        for s in samples where !drawers.contains(s.drawer) { drawers.append(s.drawer) }
        func words(_ s: String) -> Int { s.split(whereSeparator: \.isWhitespace).count }
        for drawer in drawers {
            let these = samples.filter { $0.drawer == drawer }
            let first = these.filter { $0.attempts.first.map { if case .accepted = $0.verdict { true } else { false } } ?? false }.count
            let retried = these.filter { $0.sentence != nil && $0.attempts.count > 1 }.count
            let refused = these.filter { $0.sentence == nil && $0.error?.contains("broke a rule") == true }.count
            let failed = these.filter { $0.sentence == nil && $0.error?.contains("broke a rule") != true }.count
            let kept = these.compactMap(\.sentence).map(words)
            let firstMs = these.compactMap { $0.attempts.first?.ms }
            md += "| \(drawer) | \(first)/\(these.count) | \(retried)/\(these.count) | \(refused) | \(failed) | \(kept.isEmpty ? "—" : String(EvalTests.median(kept))) | \(EvalTests.median(firstMs)) |\n"
        }
        var reasons: [String: Int] = [:]
        for s in samples { for a in s.attempts { if case .rejected(let why) = a.verdict { reasons[why.contains("words") ? "too long" : why, default: 0] += 1 } } }
        if !reasons.isEmpty {
            md += "\nWhy attempts were refused: " + reasons.sorted { $0.value > $1.value }.map { "\($0.key) ×\($0.value)" }.joined(separator: ", ") + ".\n"
        }
        let retries = samples.filter { $0.attempts.count > 1 }
        let repeated = retries.filter { $0.attempts[1].wrote == $0.attempts[0].wrote }.count
        if !retries.isEmpty {
            md += "The retry wrote the refused sentence again, word for word, \(repeated) of \(retries.count) times.\n"
        }
        md += "\n### What it wrote\n\n"
        for s in samples {
            let tries = s.attempts.enumerated().map { i, a -> String in
                if i > 0, a.wrote == s.attempts[i - 1].wrote { return "the same again, word for word" }
                switch a.verdict {
                case .accepted: return "kept: *\(quoted(a.wrote))*"
                case .rejected(let why): return "refused (\(why)): *\(quoted(a.wrote))*"
                }
            }
            md += "- \(s.drawer): " + (tries.isEmpty ? "failed: \(s.error ?? "no answer")" : tries.joined(separator: " → ")) + "\n"
        }
        return md + "\n"
    }

    @MainActor static func renderEditions(_ samples: [EditionSample], runs n: Int) -> String {
        let patience = Int(Editions.patience / .milliseconds(1))
        var md = "## The editions, \(times(n)) a release\n\n"
        md += "`ArtDirector.direct` asks greedily, so the same film should get the same edition every time and on every phone. "
        md += "The press waits \(patience / 1000) s for it before printing the floor, the edition the title's hash draws.\n\n"
        md += "| Release | the model's choice | the same every time | the floor | median ms | over \(patience / 1000) s |\n|---|---|---|---|---|---|\n"
        var releases: [String] = []
        for s in samples where !releases.contains(s.release) { releases.append(s.release) }
        func name(_ e: Edition) -> String { "\(e.movement.rawValue), \(e.palette.rawValue), \(e.stock.rawValue)" }
        var steady = 0, overPatience = 0, asFloor = 0
        for release in releases {
            let these = samples.filter { $0.release == release }
            let choices = these.map { $0.edition.map(name) ?? "error" }
            let distinct = choices.reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
            let same = distinct.count == 1 && distinct[0] != "error"
            if same { steady += 1 }
            let floor = these[0].floor
            if these.contains(where: { $0.edition.map { $0.movement == floor.movement && $0.palette == floor.palette && $0.stock == floor.stock } ?? false }) { asFloor += 1 }
            let over = these.filter { $0.ms > patience }.count
            overPatience += over
            md += "| \(release) | \(distinct.joined(separator: " / ")) | \(same ? "yes" : "no") | \(name(floor)) | \(EvalTests.median(these.map(\.ms))) | \(over)/\(these.count) |\n"
        }
        md += "\nThe model chose the same edition every time for \(steady) of \(releases.count) releases; "
        md += "\(overPatience) of \(samples.count) answers took longer than the press's patience; "
        md += "\(asFloor) of \(releases.count) releases got the title's own edition from the model at least once.\n"
        // How much of the closed vocabulary the model reaches for: the floor draws from all of it.
        let chosen = samples.compactMap(\.edition)
        func tally(_ words: [String]) -> String {
            var counts: [String: Int] = [:]
            for w in words { counts[w, default: 0] += 1 }
            return counts.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }.map { "\($0.key) ×\($0.value)" }.joined(separator: ", ")
        }
        if !chosen.isEmpty {
            md += "\nThe model used \(Set(chosen.map(\.movement)).count) of \(Movement.allCases.count) movements (\(tally(chosen.map(\.movement.rawValue)))), "
            md += "\(Set(chosen.map(\.palette)).count) of \(Palette.allCases.count) palettes (\(tally(chosen.map(\.palette.rawValue)))) "
            md += "and \(Set(chosen.map(\.stock)).count) of \(Stock.allCases.count) stocks (\(tally(chosen.map(\.stock.rawValue)))). "
            let floors = Array(Set(samples.map(\.release))).compactMap { r in samples.first { $0.release == r }?.floor }
            md += "The floors for the same releases use \(Set(floors.map(\.movement)).count) movements, \(Set(floors.map(\.palette)).count) palettes "
            md += "and \(Set(floors.map(\.stock)).count) stocks.\n"
        }
        let errors = samples.compactMap(\.error)
        if !errors.isEmpty { md += "\nErrors: " + errors.map { "\($0.prefix(90))" }.joined(separator: "; ") + ".\n" }
        return md
    }
}
