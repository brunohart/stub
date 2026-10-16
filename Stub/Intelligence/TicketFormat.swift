import Foundation

/// A ticket's shape, never what it says (docs/decisions/006-network-without-data.md). When the reader got a cinema's ticket
/// wrong and the person put it right, the lines of that ticket can be sent, by them, with every value replaced by the field
/// it is and every other word blanked unless it is one of the words tickets print as labels. What leaves is how this
/// cinema lays a ticket out ("SCREEN {screen}  SEAT {seat}"), which is what the rules need to read the next one, and
/// nothing about the night: not the film, the seat, the date, the price, the reference, or anyone's name.
///
/// Built from the ticket's own text and the person's own corrected fields, never from the on-device model's answer, and it
/// feeds hand-written rules, not a model: the Apple Developer Program License Agreement §3.2(h)(2) forbids using an Apple
/// model's output to train or improve another model.
struct TicketFormat: Equatable, Sendable {
    var lines: [String]

    /// The words a ticket prints as labels, which carry the shape and nothing about the person. Anything else is blanked.
    static let labels: Set<String> = [
        "admit", "one", "adult", "adults", "child", "children", "senior", "seniors", "student", "students", "concession",
        "member", "members", "family", "general", "admission", "screen", "scr", "cinema", "theatre", "theater", "auditorium",
        "aud", "hall", "salle", "saal", "seat", "seats", "row", "rang", "place", "date", "time", "session", "showtime",
        "starts", "doors", "ticket", "tickets", "booking", "ref", "reference", "order", "confirmation", "transaction", "trans",
        "total", "price", "paid", "gst", "incl", "inc", "tax", "fee", "booking fee", "nzd", "aud", "eur", "usd", "gbp",
        "film", "movie", "rating", "rated", "your", "e-ticket", "eticket", "present", "this", "at", "the", "door", "entry",
        "qr", "code", "scan", "valid", "for", "only", "no", "refunds", "refund", "mon", "tue", "wed", "thu", "fri", "sat", "sun",
        "am", "pm", "imax", "3d", "dolby", "atmos", "premium", "recliner", "vmax", "gold", "class", "lounge",
    ]

    /// The shape of `reading`, given the fields the person kept.
    static func of(_ reading: StubReading, kept draft: StubDraft) -> TicketFormat {
        // The person's own fields, longest first so "Dune Part Two" goes before "Dune", matched as whole words.
        var values: [(String, String)] = []
        for (value, token) in [(draft.title, "{title}"), (draft.cinema, "{cinema}"), (draft.seat, "{seat}")] {
            let v = value.trimmingCharacters(in: .whitespaces)
            if v.count >= 2 { values.append((v, token)) }
        }
        values.sort { $0.0.count > $1.0.count }

        let shaped = reading.lines.map { line -> String in
            var out = line
            for (value, token) in values {
                let pattern = #"(?<![\p{L}\p{N}])"# + NSRegularExpression.escapedPattern(for: value) + #"(?![\p{L}\p{N}])"#
                out = out.replacingOccurrences(of: pattern, with: token, options: [.regularExpression, .caseInsensitive])
            }
            // The screen by its label; then money, times, dates and every other run of digits, as their shape.
            out = out.replacingOccurrences(of: #"(?i)\b(screen|scr|cinema|auditorium|aud|hall|salle|saal|theatre|theater)(\s*[:#]?\s*)\d{1,2}\b"#,
                                           with: "$1$2{screen}", options: .regularExpression)
            out = out.replacingOccurrences(of: #"[$€£]\s?\d+(?:[.,]\d{1,2})?"#, with: "{money}", options: .regularExpression)
            out = out.replacingOccurrences(of: #"\b\d{1,2}[:.]\d{2}\s?(?i:am|pm)?\b"#, with: "{time}", options: .regularExpression)
            out = out.replacingOccurrences(of: #"\b\d{1,4}[/.\-]\d{1,2}[/.\-]\d{2,4}\b"#, with: "{date}", options: .regularExpression)
            out = out.replacingOccurrences(of: #"\d+"#, with: "#", options: .regularExpression)
            // Every word that is not a label, a token or a figure's shape is blanked.
            let words = out.split(separator: " ", omittingEmptySubsequences: true).map { word -> String in
                let text = String(word)
                if text.allSatisfy({ !$0.isLetter }) { return text }
                // A word carrying a token ("{title}:") keeps it; whatever else is in the word goes.
                if let token = text.range(of: #"\{[a-z]+\}"#, options: .regularExpression) { return String(text[token]) }
                let bare = text.lowercased().trimmingCharacters(in: .punctuationCharacters.union(.symbols))
                return labels.contains(bare) ? text : "·"
            }
            return words.joined(separator: " ")
        }
        return TicketFormat(lines: shaped.filter { !$0.isEmpty })
    }

    /// What the person sees and sends.
    var text: String { lines.joined(separator: "\n") }
}
