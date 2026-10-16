import Foundation

/// What a reader believes a stub says, before a human agrees.
struct StubDraft: Equatable, Sendable {
    var title: String = ""
    var cinema: String = ""
    var screenedAt: Date? = nil
    var screen: String = ""
    var seat: String = ""
    var price: Decimal? = nil
    var currency: String = ""
    var confidence: Double = 0
    var readBy: String = "heuristic"
    /// Who issued the ticket, when it says: a Wallet pass's `organizationName`. The circuit, more often than not (ADR-024).
    var organization: String = ""

    var isUsable: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    /// The model's answer over the rules': every field the model filled, and the rules' where it left one empty. The model
    /// read the rules' draft as its hint (ADR-010), so a field it leaves empty is one it did not disagree with.
    func over(_ floor: StubDraft) -> StubDraft {
        var merged = self
        if merged.title.isEmpty { merged.title = floor.title }
        if merged.cinema.isEmpty { merged.cinema = floor.cinema }
        if merged.screenedAt == nil { merged.screenedAt = floor.screenedAt }
        if merged.screen.isEmpty { merged.screen = floor.screen }
        if merged.seat.isEmpty { merged.seat = floor.seat }
        if merged.price == nil { merged.price = floor.price; merged.currency = floor.currency }
        if merged.currency.isEmpty, merged.price != nil { merged.currency = floor.currency }
        if merged.organization.isEmpty { merged.organization = floor.organization }
        return merged
    }

    /// Whether the person changed any field the reader offered: the read was wrong somewhere.
    func corrected(from offered: StubDraft) -> Bool {
        title != offered.title || cinema != offered.cinema || screenedAt != offered.screenedAt || screen != offered.screen
            || seat != offered.seat || price != offered.price
    }

    /// A later answer laid over the draft the person is looking at. A field they have changed since `offered` was put in
    /// front of them stays theirs; every other field takes the later answer (decision 001: the model improves the draft in
    /// place, it never undoes a hand).
    func adopting(_ later: StubDraft, unchangedFrom offered: StubDraft) -> StubDraft {
        var next = self
        if title == offered.title { next.title = later.title }
        if cinema == offered.cinema { next.cinema = later.cinema }
        if screenedAt == offered.screenedAt { next.screenedAt = later.screenedAt }
        if screen == offered.screen { next.screen = later.screen }
        if seat == offered.seat { next.seat = later.seat }
        if price == offered.price, currency == offered.currency { next.price = later.price; next.currency = later.currency }
        if organization == offered.organization { next.organization = later.organization }
        next.readBy = later.readBy
        next.confidence = later.confidence
        return next
    }
}

/// Who a stub says read it (DESIGN.md rule 7), in words. The stored value is a short name; the screen says who.
enum ReadBy {
    static func words(_ readBy: String) -> String {
        switch readBy {
        case "foundation-models": return "the on-device model"
        // The rules that read a ticket on the phone, named as a person would, not as an engineer would (ADR-048).
        case "heuristic": return "Stub's reader"
        case "manual": return "you"
        case "link": return "a link"
        case "shortcut": return "a shortcut"
        case "wallet-pass": return "the Wallet pass"
        default: return readBy
        }
    }
}

/// The raw read: what Vision saw, line by line, top to bottom.
struct StubReading: Equatable, Sendable {
    var lines: [String]
    var text: String { lines.joined(separator: "\n") }

    init(lines: [String]) { self.lines = lines }
    init(text: String) { self.lines = text.split(whereSeparator: \.isNewline).map(String.init) }
}

protocol StubParsing: Sendable {
    var name: String { get }
    func parse(_ reading: StubReading) async throws -> StubDraft
}
