import Foundation
import FoundationModels
import OSLog

/// The drawer, counted. Everything the one italic sentence and the season sheet say comes from here, by hand,
/// in a millisecond; the model is only asked to phrase it (ADR-011).
struct SeasonSummary: Equatable, Sendable {
    struct Tally: Equatable, Sendable {
        var name: String
        var count: Int
    }

    var films: Int = 0
    /// Distinct cinemas, most visited first, then alphabetical so the order is stable.
    var cinemas: [Tally] = []
    /// "March 2024" and how many stubs fell in it, busiest first.
    var months: [Tally] = []
    var weekdays: [Tally] = []
    /// Total paid, by ISO currency code, alphabetical.
    var paid: [(currency: String, amount: Decimal)] = []

    var mostVisited: Tally? { cinemas.first }
    var busiestMonth: Tally? { months.first }
    var busiestWeekday: Tally? { weekdays.first }

    static func == (a: SeasonSummary, b: SeasonSummary) -> Bool { a.brief == b.brief }

    init() {}

    init(stubs: [Stub]) {
        films = stubs.count
        let calendar = Calendar.current
        var byCinema: [String: Int] = [:]
        var byMonth: [String: (count: Int, order: Int)] = [:]
        var byWeekday: [String: (count: Int, order: Int)] = [:]
        var byCurrency: [String: Decimal] = [:]
        for stub in stubs {
            if let cinema = stub.cinema?.trimmingCharacters(in: .whitespaces), !cinema.isEmpty {
                byCinema[cinema, default: 0] += 1
            }
            if let date = stub.screenedAt {
                let c = calendar.dateComponents([.year, .month, .weekday], from: date)
                if let y = c.year, let m = c.month {
                    let name = "\(calendar.monthSymbols[m - 1]) \(y)"
                    byMonth[name, default: (0, y * 12 + m)].count += 1
                }
                if let w = c.weekday {
                    byWeekday[calendar.weekdaySymbols[w - 1], default: (0, w)].count += 1
                }
            }
            if let price = stub.price {
                byCurrency[stub.currency ?? "NZD", default: 0] += price
            }
        }
        cinemas = byCinema.map { Tally(name: $0.key, count: $0.value) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.name < $1.name }
        months = byMonth.map { (Tally(name: $0.key, count: $0.value.count), $0.value.order) }
            .sorted { $0.0.count != $1.0.count ? $0.0.count > $1.0.count : $0.1 > $1.1 }
            .map(\.0)
        weekdays = byWeekday.map { (Tally(name: $0.key, count: $0.value.count), $0.value.order) }
            .sorted { $0.0.count != $1.0.count ? $0.0.count > $1.0.count : $0.1 < $1.1 }
            .map(\.0)
        paid = byCurrency.map { (currency: $0.key, amount: $0.value) }.sorted { $0.currency < $1.currency }
    }

    /// What the model is told. Compact, one line per fact, nothing it could mistake for an instruction.
    var brief: String {
        var lines = ["Stubs: \(films)"]
        if !cinemas.isEmpty {
            lines.append("Cinemas: \(cinemas.count) (" + cinemas.map { "\($0.name) ×\($0.count)" }.joined(separator: ", ") + ")")
        }
        if !months.isEmpty { lines.append("Months: " + months.map { "\($0.name) ×\($0.count)" }.joined(separator: ", ")) }
        if !weekdays.isEmpty { lines.append("Weekdays: " + weekdays.map { "\($0.name) ×\($0.count)" }.joined(separator: ", ")) }
        if !paid.isEmpty { lines.append("Paid: " + paid.map { "\($0.currency) \($0.amount)" }.joined(separator: ", ")) }
        return lines.joined(separator: "\n")
    }

    /// A stable hash of the drawer as the sentence sees it. `Hashable` is seeded per process, so this is
    /// FNV-1a over the brief: the same drawer hashes the same tomorrow, and the cache survives a relaunch.
    var key: String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in brief.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(hash, radix: 16)
    }

    /// The sentence counted by hand. The floor the model is measured against, and what the drawer says
    /// when the model is absent, slow, or breaks a rule.
    var handSentence: String {
        switch films {
        case 0: return "Nothing in the drawer yet. Every film you saw in a room with strangers, kept here, read here, never uploaded."
        case 1: return "One stub. The drawer has started."
        default:
            let places = cinemas.count <= 1 ? "one cinema" : "\(Self.spelled(cinemas.count)) cinemas"
            var sentence = "\(Self.spelled(films).capitalized) stubs across \(places)"
            if let month = busiestMonth, month.count >= 2, months.count >= 2 {
                sentence += ", most of them in \(month.name.split(separator: " ").first.map(String.init) ?? month.name)"
            }
            return sentence + "."
        }
    }

    static func spelled(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .spellOut
        f.locale = Locale(identifier: "en_NZ")
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    /// "once", "twice", "three times".
    static func times(_ n: Int) -> String {
        switch n {
        case 1: return "once"
        case 2: return "twice"
        default: return "\(spelled(n)) times"
        }
    }
}

/// The shape the model fills. One sentence; the rules are in the instructions and checked again on the way out.
@available(iOS 26.0, *)
@Generable
struct Season: Sendable {
    @Guide(description: "One dry sentence about this season of cinema-going, under twenty words, numbers spelled out as words, no exclamation marks, no emoji.")
    var sentence: String
}

/// The rules the sentence must keep, applied to what the model wrote. A rule the instructions state is a
/// hope; a rule the code checks is a rule.
enum SeasonRules {
    static let maximumWords = 19

    enum Verdict: Equatable {
        case accepted(String)
        case rejected(String)
    }

    /// Trim, collapse whitespace, give it a full stop, then check every rule. Returns the polished sentence
    /// or the reason it was refused.
    static func judge(_ raw: String) -> Verdict {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        s = s.trimmingCharacters(in: CharacterSet(charactersIn: "\"“”'"))
        guard !s.isEmpty else { return .rejected("empty") }
        if s.contains("!") { return .rejected("exclamation mark") }
        if s.unicodeScalars.contains(where: { $0.properties.isEmojiPresentation || ($0.properties.isEmoji && $0.value > 0x7F) }) {
            return .rejected("emoji")
        }
        if s.unicodeScalars.contains(where: { CharacterSet.decimalDigits.contains($0) }) { return .rejected("digits") }
        if s.range(of: #"[.?]\s+\S"#, options: .regularExpression) != nil { return .rejected("more than one sentence") }
        let words = s.split(whereSeparator: { $0.isWhitespace }).count
        if words > maximumWords { return .rejected("\(words) words") }
        if !s.hasSuffix(".") && !s.hasSuffix("?") { s += "." }
        return .accepted(s)
    }
}

/// The last sentence the model wrote, kept against the hash of the drawer it described. One entry: the
/// drawer only has one present.
enum SeasonCache {
    static let keyName = "season.key"
    static let sentenceName = "season.sentence"

    static func sentence(for key: String, in defaults: UserDefaults = .standard) -> String? {
        guard defaults.string(forKey: keyName) == key else { return nil }
        return defaults.string(forKey: sentenceName)
    }

    static func store(_ sentence: String, for key: String, in defaults: UserDefaults = .standard) {
        defaults.set(key, forKey: keyName)
        defaults.set(sentence, forKey: sentenceName)
    }

    static func clear(in defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: keyName)
        defaults.removeObject(forKey: sentenceName)
    }
}

/// Asks the on-device model to phrase the summary. The numbers are never the model's to decide.
@available(iOS 26.0, *)
enum SeasonWriter {
    static let log = Logger(subsystem: "com.designedbybruno.stub", category: "season")

    static func session() -> LanguageModelSession {
        LanguageModelSession(instructions: """
            You write one sentence about a person's season of cinema-going, from a short summary of the ticket \
            stubs in their drawer. Rules: one sentence, under twenty words. No exclamation marks. No emoji. \
            Spell every number out as a word; never write a digit. Dry and observational, the way a friend who \
            has seen the drawer might put it; no enthusiasm, no advice, no questions. Do not list every cinema \
            or month; pick the one or two facts that say the most.
            """)
    }

    struct Rejected: LocalizedError {
        let reason: String
        var errorDescription: String? { "the model's sentence broke a rule (\(reason))" }
    }

    /// The model's sentence, judged. Throws when the model fails or its sentence breaks a rule.
    static func write(_ summary: SeasonSummary) async throws -> String {
        var options = GenerationOptions()
        options.maximumResponseTokens = 80
        let response: LanguageModelSession.Response<Season>
        do {
            response = try await session().respond(to: summary.brief, generating: Season.self, options: options)
        } catch let error as LanguageModelSession.GenerationError {
            throw ModelParser.ModelFailure(reason: ModelParser.describe(error))
        }
        switch SeasonRules.judge(response.content.sentence) {
        case .accepted(let sentence): return sentence
        case .rejected(let reason):
            log.notice("Season rejected (\(reason)): \(response.content.sentence)")
            throw Rejected(reason: reason)
        }
    }
}
