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
        /// A picture of a ticket: a PDF's first page, a screenshot. It is read as a photograph is.
        case page(Data)
    }

    enum Source: String, Sendable {
        case link, shortcut, pass, pdf, screenshot
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
        }
    }

    /// The sheet's line about where the ticket came from.
    var sentence: String {
        switch source {
        case .link: return "Handed over in a link. Nothing was fetched to open it."
        case .shortcut: return "Handed over by a shortcut."
        case .pass: return "Read from the Wallet pass. No camera, no model."
        case .pdf: return "The first page of the PDF, read here on the phone."
        case .screenshot: return "A screenshot of the ticket, read here on the phone."
        }
    }
}
