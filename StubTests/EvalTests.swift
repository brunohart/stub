import Testing
import Foundation
import CoreGraphics
import UIKit
@testable import Stub

/// The eval harness (ADR-001: the model is measured against the heuristic, on the same fixtures).
///
/// Reads `fixtures/expected.json`, runs every fixture through the real pipeline (crop → Vision → heuristic,
/// and the model with and without the heuristic's hint when the host has one) and writes `docs/evals.md`:
/// per field, who got it right, and how long each reader took. Evidence over assertion. The one assertion
/// is the floor: the heuristic must keep reading the title and seat off at least seven of the eight.
struct EvalTests {
    struct Truth: Decodable, Sendable {
        var name: String
        var title: String
        var cinema: String
        var screenedAt: String
        var screen: String
        var seat: String
        var price: String
        var currency: String
        var hard: String?
    }
    struct File: Decodable { var fixtures: [Truth] }

    static let fields = ["title", "cinema", "date", "screen", "seat", "price"]

    struct Run: Sendable {
        var name: String
        var draft: StubDraft
        var ms: Int
        var error: String?
    }

    struct Row: Sendable {
        var truth: Truth
        var detector: String
        var lines: Int
        var visionMs: Int
        var heuristic: Run
        var model: Run?
        var hinted: Run?
    }

    @Test func evalsWriteTheTable() async throws {
        let truths = try Self.truths()
        #expect(truths.count == 8)

        var modelNote = "no on-device model on this host"
        var askModel = false
        if #available(iOS 26.0, *) {
            let outcome = await ModelProbe.run(timeout: .seconds(20))
            askModel = outcome == .ready
            switch outcome {
            case .ready: modelNote = "on-device model answered the probe"
            case .failed(let why): modelNote = "model probe failed: \(why)"
            case .unavailable(let why): modelNote = "model unavailable: \(why)"
            case .untested: modelNote = "model not probed"
            }
        }

        var rows: [Row] = []
        for truth in truths {
            let cg = try Self.fixture(truth.name)
            let clock = ContinuousClock()
            let t0 = clock.now
            let crop = await StubCrop.crop(cg)
            var reading: StubReading
            var detector = crop.detector?.rawValue ?? "full frame"
            do {
                reading = try await StubVision.read(crop.image)
            } catch {
                reading = try await StubVision.read(cg)
                detector = "full frame (crop had no text)"
            }
            let visionMs = Self.ms(t0.duration(to: clock.now))

            let h0 = clock.now
            let heuristic = HeuristicParser.parse(reading)
            let heuristicRun = Run(name: "heuristic", draft: heuristic, ms: Self.ms(h0.duration(to: clock.now)))

            var model: Run?, hinted: Run?
            if #available(iOS 26.0, *), askModel {
                model = await Self.ask(ModelParser(), reading, hint: nil, name: "model")
                hinted = await Self.ask(ModelParser(), reading, hint: heuristic, name: "model + hint")
            }
            rows.append(Row(truth: truth, detector: detector, lines: reading.lines.count, visionMs: visionMs,
                            heuristic: heuristicRun, model: model, hinted: hinted))
        }

        let markdown = Self.render(rows, modelNote: modelNote)
        let out = Self.repoRoot.appendingPathComponent("docs/evals.md")
        try markdown.write(to: out, atomically: true, encoding: .utf8)

        // The floor. Seven of eight is the bar until the table says otherwise; the eighth is allowed to teach.
        let titles = rows.filter { Self.hit("title", $0.heuristic.draft, $0.truth) }.count
        let seats = rows.filter { Self.hit("seat", $0.heuristic.draft, $0.truth) }.count
        #expect(titles >= 7, "heuristic read \(titles)/8 titles")
        #expect(seats >= 7, "heuristic read \(seats)/8 seats")
    }

    // MARK: - Asking

    @available(iOS 26.0, *)
    static func ask(_ parser: ModelParser, _ reading: StubReading, hint: StubDraft?, name: String) async -> Run {
        let clock = ContinuousClock()
        let t0 = clock.now
        do {
            let draft = try await parser.parse(reading, hint: hint)
            return Run(name: name, draft: draft, ms: ms(t0.duration(to: clock.now)))
        } catch {
            return Run(name: name, draft: StubDraft(), ms: ms(t0.duration(to: clock.now)), error: ModelProbe.explain(error))
        }
    }

    // MARK: - Scoring

    static func hit(_ field: String, _ d: StubDraft, _ t: Truth) -> Bool {
        func same(_ a: String, _ b: String) -> Bool {
            a.trimmingCharacters(in: .whitespaces).lowercased() == b.trimmingCharacters(in: .whitespaces).lowercased()
        }
        switch field {
        case "title": return same(d.title, t.title)
        case "cinema": return same(d.cinema, t.cinema)
        case "screen": return same(d.screen, t.screen)
        case "seat": return same(d.seat, t.seat)
        case "price":
            guard let p = d.price else { return t.price.isEmpty }
            return p == Decimal(string: t.price) && same(d.currency, t.currency)
        case "date":
            guard let date = d.screenedAt else { return t.screenedAt.isEmpty }
            return dateFormatter.string(from: date) == t.screenedAt
        default: return false
        }
    }

    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()

    static func value(_ field: String, _ d: StubDraft) -> String {
        switch field {
        case "title": return d.title
        case "cinema": return d.cinema
        case "screen": return d.screen
        case "seat": return d.seat
        case "price": return d.price.map { "\($0) \(d.currency)" } ?? ""
        case "date": return d.screenedAt.map { dateFormatter.string(from: $0) } ?? ""
        default: return ""
        }
    }

    // MARK: - Rendering

    static func render(_ rows: [Row], modelNote: String) -> String {
        let stamp = Date.now.formatted(.iso8601.year().month().day())
        let os = ProcessInfo.processInfo.operatingSystemVersion
        var md = "# Evals\n\n"
        md += "Generated by `StubTests/EvalTests.swift` on \(stamp) from `fixtures/expected.json`, in the iOS \(os.majorVersion).\(os.minorVersion) simulator. "
        md += "Every fixture goes through the real pipeline: `StubCrop` → `StubVision` → parsers. "
        md += "The heuristic parser is the floor (ADR-001); the model is asked cold and again with the heuristic's draft as a hint.\n\n"
        md += "**Model on this run:** \(modelNote).\n\n"

        let readers: [(String, (Row) -> Run?)] = [
            ("heuristic", { $0.heuristic }), ("model", { $0.model }), ("model + hint", { $0.hinted }),
        ]
        let present = readers.filter { name, pick in rows.contains { pick($0) != nil } }

        md += "## Hit rate by field\n\n"
        md += "| Field | " + present.map { $0.0 }.joined(separator: " | ") + " |\n"
        md += "|---|" + present.map { _ in "---" }.joined(separator: "|") + "|\n"
        for field in fields {
            let cells = present.map { _, pick -> String in
                let runs = rows.compactMap { row in pick(row).map { (row, $0) } }
                let hits = runs.filter { hit(field, $0.1.draft, $0.0.truth) }.count
                return "\(hits)/\(runs.count)"
            }
            md += "| \(field) | " + cells.joined(separator: " | ") + " |\n"
        }

        md += "\n## Latency\n\n| Reader | median ms | max ms |\n|---|---|---|\n"
        let vision = rows.map(\.visionMs)
        md += "| crop + Vision | \(median(vision)) | \(vision.max() ?? 0) |\n"
        for (name, pick) in present {
            let times = rows.compactMap { pick($0)?.ms }
            md += "| \(name) | \(median(times)) | \(times.max() ?? 0) |\n"
        }

        md += "\n## Per fixture\n\n"
        for row in rows {
            md += "### \(row.truth.name)\(row.truth.hard.map { " — \($0)" } ?? "")\n\n"
            md += "Cropped by \(row.detector); Vision read \(row.lines) lines in \(row.visionMs) ms.\n\n"
            md += "| Field | truth | " + present.map { $0.0 }.joined(separator: " | ") + " |\n"
            md += "|---|---|" + present.map { _ in "---" }.joined(separator: "|") + "|\n"
            for field in fields {
                let truthValue: String
                switch field {
                case "title": truthValue = row.truth.title
                case "cinema": truthValue = row.truth.cinema
                case "screen": truthValue = row.truth.screen
                case "seat": truthValue = row.truth.seat
                case "price": truthValue = "\(row.truth.price) \(row.truth.currency)"
                default: truthValue = row.truth.screenedAt
                }
                let cells = present.map { _, pick -> String in
                    guard let run = pick(row) else { return "" }
                    if let error = run.error { return "error: \(error.prefix(60))…" }
                    let v = value(field, run.draft)
                    return (hit(field, run.draft, row.truth) ? "✓ " : "✗ ") + (v.isEmpty ? "—" : v)
                }
                md += "| \(field) | \(truthValue) | " + cells.joined(separator: " | ") + " |\n"
            }
            md += "\n"
        }
        return md
    }

    static func median(_ xs: [Int]) -> Int {
        let s = xs.sorted()
        guard !s.isEmpty else { return 0 }
        return s[s.count / 2]
    }

    static func ms(_ d: Duration) -> Int { Int(d / .milliseconds(1)) }

    // MARK: - Files

    /// The repo, found from this file: the simulator shares the Mac's filesystem, so the test can write the table.
    static var repoRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    static func truths() throws -> [Truth] {
        let url = repoRoot.appendingPathComponent("fixtures/expected.json")
        return try JSONDecoder().decode(File.self, from: Data(contentsOf: url)).fixtures
    }

    static func fixture(_ name: String) throws -> CGImage {
        let url = try #require(Bundle.main.url(forResource: name, withExtension: "png"), "missing fixture \(name)")
        return try #require(UIImage(data: Data(contentsOf: url))?.cgImage)
    }
}
