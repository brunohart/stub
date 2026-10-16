import Foundation

/// A ticket handed to Stub from outside it: a link, a shortcut, and (BEDIP-218) a Wallet pass, a PDF, a screenshot. It
/// never files itself. It opens the import sheet, prefilled or being read, and the person keeps it or lets it go (ADR-021).
struct Arrival: Identifiable, Equatable, Sendable {
    let id = UUID()
    var content: Content
    /// Where it came from, for the sheet's one sentence and the log.
    var source: Source

    enum Content: Sendable {
        /// The fields are already known: a link, a shortcut, a Wallet pass. No reader runs. `plate` is the picture the
        /// stub keeps, when there is one (a pass's strip); without one the card prints a blank stub.
        case known(StubDraft, raw: String, plate: Data?)
        /// A picture of a ticket: a screenshot, or a PDF with no text of its own. It is read as a photograph is, or, `whole`,
        /// all of it rather than the ticket the crop finds.
        case page(Data, whole: Bool)
        /// A PDF's first page and its own text: the text goes to the parsers as written, the page is the plate.
        case document(page: Data, lines: [String])
        /// A booking's words and nothing else: read by the parsers as written; the card prints a blank stub.
        case text(lines: [String])
    }

    enum Source: String, Sendable {
        case link, shortcut, pass, pdf, screenshot, booking
    }

    static func == (a: Arrival, b: Arrival) -> Bool { a.id == b.id }

    /// A mark for where it came from, beside the sentence.
    var symbol: String {
        switch source {
        case .link: "link"
        case .shortcut: "square.2.layers.3d"
        case .pass: "wallet.pass"
        case .pdf: "doc.richtext"
        case .screenshot: "rectangle.on.rectangle"
        case .booking: "envelope.open"
        }
    }

    /// The cinema's poster that came with it, if one did (ADR-050).
    var poster: URL? {
        if case .known(let draft, _, _) = content { return draft.poster }
        return nil
    }

    /// The sheet's line about where the ticket came from. `postersOn`: whether keeping it will fetch the cinema's poster,
    /// which the line then says, with where from.
    func sentence(postersOn: Bool) -> String {
        switch source {
        case .link:
            if postersOn, let host = poster?.host() {
                return "Handed over in a link, with the cinema's poster. Nothing was fetched to open it; keeping it fetches the poster once, from \(host)."
            }
            return "Handed over in a link. Nothing was fetched to open it."
        case .shortcut: return "Handed over by a shortcut."
        case .pass: return "Read from the Wallet pass. No camera, no model."
        case .pdf: return "The first page of the PDF, read here on the phone."
        case .screenshot: return "A picture of the ticket, read here on the phone."
        case .booking: return "The words of a booking, read here on the phone."
        }
    }
}
