import Testing
import Foundation
import CoreGraphics
import UIKit
@testable import Stub

/// The corpus eval (docs/decisions/008-corpus.md): real tickets from `corpus/`, labelled in `corpus/labels.json`, each read
/// the way the app reads its kind, by the rules and by the on-device model where the host has one. Writes
/// `docs/evals-corpus.md` with counts and rates per kind and per field, and never a title, cinema, seat or reference from
/// a real ticket: the report is public, the tickets are not. With no corpus yet, the report says what is missing.
///
/// Off the daily path: it runs only when `STUB_CORPUS` is set (`scripts/eval.sh --corpus`).
@Suite(.enabled(if: ProcessInfo.processInfo.environment["STUB_CORPUS"] != nil))
struct CorpusEvalTests {
    struct Label: Decodable, Sendable {
        var file: String
        var title: String
        var cinema: String
        var screenedAt: String
        var screen: String
        var seat: String
        var price: String
        var currency: String
        var circuit: String?
        var condition: String?

        var kind: String { file.split(separator: "/").first.map(String.init) ?? "?" }
        var truth: EvalTests.Truth {
            EvalTests.Truth(name: file, title: title, cinema: cinema, screenedAt: screenedAt, screen: screen, seat: seat,
                            price: price, currency: currency, hard: condition, kind: kind)
        }
    }
    struct Labels: Decodable { var tickets: [Label] }

    /// The kinds the corpus is measured in, and how many of each it should hold before a rate means anything.
    static let kinds = ["paper", "thermal", "pdf", "wallet", "screenshot", "email"]
    static let enough = 5

    struct Result: Sendable {
        var label: Label
        var rules: StubDraft
        var model: StubDraft?
        var readMs: Int
        var modelMs: Int?
    }

    static var corpus: URL { EvalTests.repoRoot.appendingPathComponent("corpus") }

    @Test func theCorpusWritesItsReport() async throws {
        let labelsURL = Self.corpus.appendingPathComponent("labels.json")
        let labels = (try? JSONDecoder().decode(Labels.self, from: Data(contentsOf: labelsURL)))?.tickets ?? []

        var askModel = false
        if #available(iOS 26.0, *) { askModel = await ModelProbe.run(timeout: .seconds(20)) == .ready }

        var results: [Result] = []
        for label in labels {
            let url = Self.corpus.appendingPathComponent(label.file)
            guard let data = try? Data(contentsOf: url) else { continue }
            let clock = ContinuousClock()
            let t0 = clock.now
            guard let reading = try await Self.read(data, kind: label.kind, file: url) else { continue }
            let readMs = EvalTests.ms(t0.duration(to: clock.now))
            // A Wallet pass states its fields; the rules only fill what it leaves out, as the app does (ADR-023).
            var rules = HeuristicParser.parse(reading)
            if label.kind == "wallet", let pass = try? WalletPass(pkpass: data) { rules = pass.handed(fallback: rules).draft }
            var model: StubDraft?, modelMs: Int?
            if #available(iOS 26.0, *), askModel, label.kind != "wallet" {
                let run = await EvalTests.ask(ModelParser(), reading, hint: rules, name: "model + hint")
                model = run.error == nil ? run.draft.over(rules) : rules
                modelMs = run.ms
            }
            results.append(Result(label: label, rules: rules, model: model, readMs: readMs, modelMs: modelMs))
        }

        let report = Self.render(results, labels: labels, modelAsked: askModel)
        try report.write(to: EvalTests.repoRoot.appendingPathComponent("docs/evals-corpus.md"), atomically: true, encoding: .utf8)
    }

    // MARK: Reading, as the app reads each kind

    static func read(_ data: Data, kind: String, file: URL) async throws -> StubReading? {
        switch kind {
        case "wallet":
            return (try? WalletPass(pkpass: data)).map(\.reading)
        case "pdf":
            let lines = PageImage.text(of: data)
            if !lines.isEmpty { return StubReading(lines: lines) }
            guard let page = PageImage.firstPage(of: data) else { return nil }
            return try await StubVision.read(page)
        case "email":
            return StubReading(lines: Booking.lines(Email.text(of: data)))
        default:
            let size = await PlateImage.intake
            guard let cg = PlateImage.decode(data, maxPixelSize: size) else { return nil }
            if kind == "screenshot" { return try await StubVision.read(cg) }
            let crop = await StubCrop.crop(cg)
            if let cropped = try? await StubVision.read(crop.image) { return cropped }
            return try await StubVision.read(cg)
        }
    }

    // MARK: The report: counts and rates, never a ticket's contents

    static func render(_ results: [Result], labels: [Label], modelAsked: Bool) -> String {
        let stamp = Date.now.formatted(Date.ISO8601FormatStyle(timeZone: .current).year().month().day())
        var md = "# Evals: the corpus\n\n"
        md += "Generated by `StubTests/CorpusEvalTests.swift` on \(stamp) from real tickets in `corpus/` (kept off git; "
        md += "docs/decisions/008-corpus.md). Each ticket is read the way the app reads its kind. Counts and rates only: no "
        md += "title, cinema, seat or reference from a real ticket appears here.\n\n"
        let model = !modelAsked ? "no on-device model on this host: the rules alone"
            : results.isEmpty ? "the on-device model answered its probe; there were no tickets for it to read"
            : "the on-device model read every ticket but the passes, with the rules' draft as its hint"
        md += "**Model on this run:** \(model).\n\n"

        md += "## What the corpus holds\n\n| Kind | Tickets | Circuits | Independents | Enough to rate (\(enough)+) |\n|---|---|---|---|---|\n"
        for kind in kinds {
            let here = labels.filter { $0.kind == kind }
            let circuits = Set(here.compactMap(\.circuit).filter { $0 != "independent" }).count
            let independents = here.filter { $0.circuit == "independent" }.count
            md += "| \(kind) | \(here.count) | \(circuits) | \(independents) | \(here.count >= enough ? "yes" : "no: \(enough - here.count) short") |\n"
        }
        let short = kinds.filter { kind in labels.filter { $0.kind == kind }.count < enough }
        if !short.isEmpty {
            md += "\n**Missing:** " + short.map { kind in
                let n = labels.filter { $0.kind == kind }.count
                return "\(kind) (\(n) of \(enough))"
            }.joined(separator: ", ") + ". Rates below on fewer than \(enough) tickets of a kind are shown as counts and read as anecdotes.\n"
        }

        guard !results.isEmpty else {
            md += "\nNo tickets have been read yet. Put them in `corpus/<kind>/`, describe each in `corpus/labels.json` "
            md += "(`corpus/README.md`), and run `scripts/eval.sh --corpus`.\n"
            return md
        }

        md += "\n## Field accuracy by kind\n\nEach cell is right / read, for the rules and (where asked) the model with the rules' hint.\n\n"
        md += "| Kind | Reader | " + EvalTests.fields.joined(separator: " | ") + " | all six |\n"
        md += "|---|---|" + EvalTests.fields.map { _ in "---" }.joined(separator: "|") + "|---|\n"
        for kind in kinds {
            let here = results.filter { $0.label.kind == kind }
            guard !here.isEmpty else { continue }
            let readers: [(String, (Result) -> StubDraft?)] = [("rules", { $0.rules }), ("model", { $0.model })]
            for (name, pick) in readers {
                let runs = here.compactMap { r in pick(r).map { (r.label.truth, $0) } }
                guard !runs.isEmpty else { continue }
                let cells = EvalTests.fields.map { field in
                    "\(runs.filter { EvalTests.hit(field, $0.1, $0.0) }.count)/\(runs.count)"
                }
                let whole = runs.filter { run in EvalTests.fields.allSatisfy { EvalTests.hit($0, run.1, run.0) } }.count
                md += "| \(kind) | \(name) | " + cells.joined(separator: " | ") + " | \(whole)/\(runs.count) |\n"
            }
        }

        md += "\n## Time to read, by kind\n\n| Kind | read median ms | read max ms | model median ms |\n|---|---|---|---|\n"
        for kind in kinds {
            let here = results.filter { $0.label.kind == kind }
            guard !here.isEmpty else { continue }
            let reads = here.map(\.readMs)
            let models = here.compactMap(\.modelMs)
            md += "| \(kind) | \(EvalTests.median(reads)) | \(reads.max() ?? 0) | \(models.isEmpty ? "—" : "\(EvalTests.median(models))") |\n"
        }

        let hard = Dictionary(grouping: results.compactMap { r in r.label.condition.flatMap { $0.isEmpty ? nil : ($0, r) } }, by: \.0)
        if !hard.isEmpty {
            md += "\n## Hard tickets\n\n| Condition | Tickets | Every field right, rules | Every field right, model |\n|---|---|---|---|\n"
            for (condition, pairs) in hard.sorted(by: { $0.key < $1.key }) {
                let rs = pairs.map(\.1)
                let rules = rs.filter { r in EvalTests.fields.allSatisfy { EvalTests.hit($0, r.rules, r.label.truth) } }.count
                let model = rs.filter { r in r.model.map { m in EvalTests.fields.allSatisfy { EvalTests.hit($0, m, r.label.truth) } } ?? false }.count
                md += "| \(condition) | \(rs.count) | \(rules) | \(rs.contains { $0.model != nil } ? "\(model)" : "—") |\n"
            }
        }
        return md
    }
}

/// A booking email saved from Mail as `.eml`: its readable words. The plain-text part if there is one, else the HTML part
/// with its tags taken out; quoted-printable undone. Enough for the corpus; the app takes a booking's words from the share
/// sheet, already plain.
enum Email {
    static func text(of data: Data) -> String {
        let raw = String(decoding: data, as: UTF8.self).replacingOccurrences(of: "\r\n", with: "\n")
        let parts = raw.components(separatedBy: "\n\n")
        guard parts.count > 1 else { return raw }
        let body = parts.dropFirst().joined(separator: "\n\n")
        // The plain part of a multipart message, when there is one.
        let chosen: String
        if let plain = section(of: body, type: "text/plain") { chosen = plain }
        else if let html = section(of: body, type: "text/html") { chosen = strip(html) }
        else { chosen = body.contains("<html") ? strip(body) : body }
        return unquote(chosen)
    }

    private static func section(of body: String, type: String) -> String? {
        guard let start = body.range(of: "Content-Type: \(type)", options: .caseInsensitive) else { return nil }
        let after = body[start.upperBound...]
        guard let blank = after.range(of: "\n\n") else { return nil }
        let rest = after[blank.upperBound...]
        let end = rest.range(of: "\n--")?.lowerBound ?? rest.endIndex
        return String(rest[..<end])
    }

    private static func strip(_ html: String) -> String {
        html.replacingOccurrences(of: #"<(br|p|div|tr|li)[^>]*>"#, with: "\n", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ").replacingOccurrences(of: "&amp;", with: "&")
    }

    /// Quoted-printable undone byte by byte, then read as UTF-8, so "=C3=A9" is one "é".
    private static func unquote(_ text: String) -> String {
        let bytes = Array(text.replacingOccurrences(of: "=\n", with: "").utf8)
        var out: [UInt8] = []
        out.reserveCapacity(bytes.count)
        var i = 0
        while i < bytes.count {
            if bytes[i] == UInt8(ascii: "="), i + 2 < bytes.count,
               let byte = UInt8(String(decoding: bytes[(i + 1)...(i + 2)], as: UTF8.self), radix: 16) {
                out.append(byte)
                i += 3
            } else {
                out.append(bytes[i])
                i += 1
            }
        }
        return String(decoding: out, as: UTF8.self)
    }
}
