import Foundation
import FoundationModels

/// The on-device language model reading a stub. Private by construction: the text never leaves the phone.
@available(iOS 26.0, *)
struct ModelParser: StubParsing {
    let name = "foundation-models"

    /// The shape we ask the model to fill. Guided generation means it cannot return anything else.
    @Generable
    struct Generated: Sendable {
        @Guide(description: "The film title exactly as printed, in title case, without rating, format (2D, IMAX) or session suffixes.")
        var title: String
        @Guide(description: "The cinema or venue name. Empty string if not printed.")
        var cinema: String
        @Guide(description: "Screening date and time as ISO 8601, e.g. 2026-09-06T19:30:00. Empty string if not printed.")
        var screenedAt: String
        @Guide(description: "Screen or auditorium as printed, e.g. 'Screen 4'. Empty string if absent.")
        var screen: String
        @Guide(description: "Seat as printed, e.g. 'H12'. Empty string if absent.")
        var seat: String
        @Guide(description: "Ticket price as a plain decimal, e.g. 18.50. Empty string if absent.")
        var price: String
        @Guide(description: "ISO 4217 currency code if it can be inferred (NZD, AUD, USD, GBP, EUR). Empty string otherwise.")
        var currency: String
    }

    static var availability: SystemLanguageModel.Availability {
        SystemLanguageModel.default.availability
    }

    static var isAvailable: Bool {
        if case .available = availability { return true }
        return false
    }

    static func unavailabilityReason() -> String? {
        switch availability {
        case .available: return nil
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible: return "This device cannot run the on-device model."
            case .appleIntelligenceNotEnabled: return "Apple Intelligence is off in Settings."
            case .modelNotReady: return "The on-device model is still downloading."
            @unknown default: return "The on-device model is unavailable."
            }
        }
    }

    /// The standing instructions. The prompt carries the text and, when there is one, the heuristic's draft.
    static func session() -> LanguageModelSession {
        LanguageModelSession(instructions: """
            You read cinema ticket stubs. You are given the text recognised from a photograph of one stub, \
            one printed line per line, top to bottom. Extract the fields. Never invent a value that is not \
            printed; leave it empty instead. Titles are films, not cinemas. Seats look like a letter then a number. \
            When a first pass by a rule-based reader is given, treat it as a hint: keep what the text confirms, \
            correct what it does not, and fill what it missed.
            """)
    }

    /// The prompt. With a hint, the heuristic's reading is appended so the model corrects rather than starts cold.
    static func prompt(_ reading: StubReading, hint: StubDraft?) -> String {
        var text = "Ticket text:\n\(reading.text)"
        if let hint, hint.isUsable {
            var lines = ["title: \(hint.title)"]
            if !hint.cinema.isEmpty { lines.append("cinema: \(hint.cinema)") }
            if let d = hint.screenedAt { lines.append("screenedAt: \(d.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false)))") }
            if !hint.screen.isEmpty { lines.append("screen: \(hint.screen)") }
            if !hint.seat.isEmpty { lines.append("seat: \(hint.seat)") }
            if let p = hint.price { lines.append("price: \(p)") }
            if !hint.currency.isEmpty { lines.append("currency: \(hint.currency)") }
            text += "\n\nFirst pass by the rule-based reader (a hint, not the truth):\n" + lines.joined(separator: "\n")
        }
        return text
    }

    func parse(_ reading: StubReading) async throws -> StubDraft {
        try await parse(reading, hint: nil)
    }

    /// One answer, whole. `hint` is the heuristic's draft when the caller has one (Day 3: measured in `docs/evals.md`).
    func parse(_ reading: StubReading, hint: StubDraft?) async throws -> StubDraft {
        let session = Self.session()
        do {
            let response = try await session.respond(
                to: Self.prompt(reading, hint: hint),
                generating: Generated.self
            )
            return Self.draft(from: response.content, hint: hint)
        } catch let error as LanguageModelSession.GenerationError {
            throw ModelFailure(reason: Self.describe(error))
        }
    }

    /// The answer as it forms. Each snapshot of the partially generated struct becomes a draft; properties fill
    /// in the order they are declared, so the title lands before the seat and the import fields can show it.
    /// Only changed drafts are yielded. Cancelling the consumer cancels the generation.
    func stream(_ reading: StubReading, hint: StubDraft?) -> AsyncThrowingStream<StubDraft, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                let session = Self.session()
                do {
                    let snapshots = session.streamResponse(to: Self.prompt(reading, hint: hint), generating: Generated.self)
                    var last: StubDraft?
                    for try await snapshot in snapshots {
                        let draft = Self.draft(from: snapshot.content, hint: hint)
                        if draft != last {
                            continuation.yield(draft)
                            last = draft
                        }
                    }
                    continuation.finish()
                } catch let error as LanguageModelSession.GenerationError {
                    continuation.finish(throwing: ModelFailure(reason: Self.describe(error)))
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    struct ModelFailure: LocalizedError {
        let reason: String
        var errorDescription: String? { reason }
    }

    /// "SCR 2", "Cinema 3", "Salle 2" → "Screen 2". A bare number is a screen too. Anything else stays as said.
    static func normalisedScreen(_ raw: String) -> String {
        let s = raw.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return "" }
        if let n = HeuristicParser.match(#"(?i)\b(?:SCREEN|SCR|CINEMA|AUDITORIUM|AUD|HALL|THEATRE|THEATER|SALLE|SAAL|SALA)\s*[:#]?\s*(\d{1,2})\b"#, in: s)
            ?? HeuristicParser.match(#"^\s*(\d{1,2})\s*$"#, in: s) {
            return "Screen \(n)"
        }
        return s
    }

    /// "SEAT D 4", "RANG F PLACE 12", "h12" → "D4", "F12", "H12". The heuristic's seat folklore, reused.
    static func normalisedSeat(_ raw: String) -> String {
        let s = raw.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return "" }
        if let seat = HeuristicParser.seat(in: s) { return seat }
        if let bare = HeuristicParser.match(#"^\s*([A-Z]{1,2}\s?-?\d{1,3})\s*$"#, in: s.uppercased()) {
            return bare.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "")
        }
        return s.uppercased()
    }

    /// A ticket prints the time on the wall of the cinema, no zone. The model tends to write ISO 8601 with a
    /// `Z` (Day 3 evals: every date landed twelve or thirteen hours late), so any zone designator is dropped
    /// and the digits are read as local time. A date with no time is kept at midnight.
    static func wallClock(_ raw: String) -> Date? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        s = s.replacingOccurrences(of: #"(?:Z|[+-]\d{2}:?\d{2})$"#, with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\.\d+$"#, with: "", options: .regularExpression)
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        for format in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm", "yyyy-MM-dd"] {
            f.dateFormat = format
            if let d = f.date(from: s) { return d }
        }
        return nil
    }

    /// Name the failure. `GenerationError` prints as a bare code otherwise, and a bare code teaches nothing.
    static func describe(_ error: LanguageModelSession.GenerationError) -> String {
        switch error {
        case .exceededContextWindowSize(let c): return "exceededContextWindowSize: \(c.debugDescription)"
        case .assetsUnavailable(let c): return "assetsUnavailable: \(c.debugDescription)"
        case .guardrailViolation(let c): return "guardrailViolation: \(c.debugDescription)"
        case .unsupportedGuide(let c): return "unsupportedGuide: \(c.debugDescription)"
        case .unsupportedLanguageOrLocale(let c): return "unsupportedLanguageOrLocale: \(c.debugDescription)"
        case .decodingFailure(let c): return "decodingFailure: \(c.debugDescription)"
        case .rateLimited(let c): return "rateLimited: \(c.debugDescription)"
        case .concurrentRequests(let c): return "concurrentRequests: \(c.debugDescription)"
        case .refusal(_, let c): return "refusal: \(c.debugDescription)"
        @unknown default: return "unknown: \(String(reflecting: error))"
        }
    }

    static func draft(from g: Generated, hint: StubDraft? = nil) -> StubDraft {
        draft(title: g.title, cinema: g.cinema, screenedAt: g.screenedAt, screen: g.screen, seat: g.seat, price: g.price,
              currency: g.currency, hint: hint)
    }

    /// A snapshot mid-generation: every property is optional until the model has said it.
    static func draft(from p: Generated.PartiallyGenerated, hint: StubDraft? = nil) -> StubDraft {
        draft(title: p.title ?? "", cinema: p.cinema ?? "", screenedAt: p.screenedAt ?? "", screen: p.screen ?? "",
              seat: p.seat ?? "", price: p.price ?? "", currency: p.currency ?? "", hint: hint)
    }

    /// "H12", "AA3": a row and a number. The shape the drawer files a seat in.
    static func hasRow(_ seat: String) -> Bool {
        seat.range(of: #"^[A-Z]{1,2}\d{1,3}$"#, options: .regularExpression) != nil
    }

    /// The heuristic reads capitals off the ticket and title-cases them. The model sometimes copies the capitals
    /// instead ("AFTERSUN", "RIALTO CINEMAS NEWMARKET" on Day 4), and "PLACE 12" on a lock screen is the wrong
    /// first impression. A shouted answer gets the heuristic's casing; a cased one is the model's own choice and stays.
    static func cased(_ s: String) -> String {
        let t = s.trimmingCharacters(in: .whitespaces)
        guard t.contains(where: \.isLetter), !t.contains(where: \.isLowercase) else { return t }
        return HeuristicParser.titleCase(t)
    }

    /// The model's fields, put into the shapes the drawer files: the same normalisation the heuristic applies,
    /// so the two are compared on what they read and not on how they spelt it (Day 3 evals: the cold model's
    /// misses on screen and seat were "SCR 2" and "SEAT D 4", read correctly and left as printed).
    ///
    /// `hint` is the heuristic's draft when the model was reading with one (ADR-010). It settles one argument:
    /// a seat the model read without its row ("PLACE 12", Day 4) when the hint has the row (F12). The row was
    /// printed and the regex saw it; the model's version is not a seat the drawer can file. An empty seat is left
    /// empty: filling what it missed is the model's job, and the eval table should see when it does not.
    static func draft(title: String, cinema: String, screenedAt: String, screen: String, seat: String, price: String,
                      currency: String, hint: StubDraft? = nil) -> StubDraft {
        var draft = StubDraft()
        draft.title = cased(HeuristicParser.stripFormats(title.trimmingCharacters(in: .whitespaces)))
        draft.cinema = cased(cinema)
        draft.screen = normalisedScreen(screen)
        draft.seat = normalisedSeat(seat)
        if let hint, !draft.seat.isEmpty, !hasRow(draft.seat), hasRow(hint.seat) {
            draft.seat = hint.seat
        }
        draft.currency = currency.trimmingCharacters(in: .whitespaces).uppercased()
        if !price.isEmpty {
            draft.price = Decimal(string: price.replacingOccurrences(of: ",", with: ".").filter { $0.isNumber || $0 == "." })
        }
        draft.screenedAt = wallClock(screenedAt)
        var score = 0.0
        if draft.isUsable { score += 0.5 }
        if draft.screenedAt != nil { score += 0.2 }
        if !draft.seat.isEmpty { score += 0.1 }
        if !draft.cinema.isEmpty { score += 0.1 }
        if draft.price != nil { score += 0.1 }
        draft.confidence = (score * 100).rounded() / 100   // Summed tenths land at 0.9999999999999999 in binary and the label would say 99%
        draft.readBy = "foundation-models"
        return draft
    }
}
