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

    var isUsable: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }
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
