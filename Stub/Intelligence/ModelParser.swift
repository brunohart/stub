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

    func parse(_ reading: StubReading) async throws -> StubDraft {
        let session = LanguageModelSession(instructions: """
            You read cinema ticket stubs. You are given the text recognised from a photograph of one stub, \
            one printed line per line, top to bottom. Extract the fields. Never invent a value that is not \
            printed; leave it empty instead. Titles are films, not cinemas. Seats look like a letter then a number.
            """)
        do {
            let response = try await session.respond(
                to: "Ticket text:\n\(reading.text)",
                generating: Generated.self
            )
            return Self.draft(from: response.content)
        } catch let error as LanguageModelSession.GenerationError {
            throw ModelFailure(reason: Self.describe(error))
        }
    }

    struct ModelFailure: LocalizedError {
        let reason: String
        var errorDescription: String? { reason }
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

    static func draft(from g: Generated) -> StubDraft {
        var draft = StubDraft()
        draft.title = g.title.trimmingCharacters(in: .whitespaces)
        draft.cinema = g.cinema.trimmingCharacters(in: .whitespaces)
        draft.screen = g.screen.trimmingCharacters(in: .whitespaces)
        draft.seat = g.seat.trimmingCharacters(in: .whitespaces).uppercased()
        draft.currency = g.currency.trimmingCharacters(in: .whitespaces).uppercased()
        if !g.price.isEmpty {
            draft.price = Decimal(string: g.price.filter { $0.isNumber || $0 == "." })
        }
        if !g.screenedAt.isEmpty {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime]
            iso.timeZone = .current
            draft.screenedAt = iso.date(from: g.screenedAt)
                ?? iso.date(from: g.screenedAt + "Z")
                ?? { iso.formatOptions = [.withFullDate]; return iso.date(from: g.screenedAt) }()
        }
        var score = 0.0
        if draft.isUsable { score += 0.5 }
        if draft.screenedAt != nil { score += 0.2 }
        if !draft.seat.isEmpty { score += 0.1 }
        if !draft.cinema.isEmpty { score += 0.1 }
        if draft.price != nil { score += 0.1 }
        draft.confidence = score
        draft.readBy = "foundation-models"
        return draft
    }
}
