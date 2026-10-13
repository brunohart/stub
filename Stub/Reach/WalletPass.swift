import Foundation

/// A Wallet pass, read (BEDIP-218, ADR-023). A `.pkpass` is a zip with `pass.json` in it, and a cinema's pass usually says
/// what the ticket says in structured fields, so nothing here guesses: no camera, no Vision, no model.
///
/// In order, for each of the ticket's fields: the pass's semantic tags (`semantics.eventName`, `venueName`,
/// `eventStartDate`, `seats`, `venueRoom`, `totalPrice`), which say exactly what they are; then the visible fields, by
/// their key or their label ("Film", "Cinema", "Session", "Seat", "Screen"); then `relevantDate` for the time and
/// `organizationName` for the cinema. What none of those settles is left for the heuristic parser to try on the pass's own
/// words, in the app (`WalletPass.read(_:fallback:)`), and a stub that needed it says so in its confidence.
struct WalletPass: Equatable, Sendable {
    /// The ticket as the pass states it.
    var ticket = AddLink.Ticket()
    /// Which of title, cinema, date, screen, seat, price came from the pass's structure.
    var stated: Set<String> = []
    /// The issuer: often the circuit ("Event Cinemas"), sometimes the cinema.
    var organization = ""
    /// The pass's picture, for the stub's plate: its strip, else its background, else its thumbnail.
    var plate: Data?
    /// What the pass shows, a field a line: the stub's raw read.
    var lines: [String] = []
    /// Whether the pass calls itself a film (`semantics.eventType` is `PKEventTypeMovie`).
    var isMovie = false

    enum Failure: Error, Equatable { case notAPass, noPassJSON, unreadable(String) }

    /// The largest pass this will open: real ones are well under a megabyte.
    static let largest = 8 << 20

    init() {}

    /// Opens a `.pkpass` and reads it. Throws when it is not a pass at all.
    init(pkpass data: Data) throws {
        guard data.count <= Self.largest else { throw Failure.unreadable("larger than \(Self.largest >> 20) MB") }
        let zip: Zip
        do { zip = try Zip(data) } catch { throw Failure.notAPass }
        guard let json = try? zip.read("pass.json") else { throw Failure.noPassJSON }
        try self.init(passJSON: json)
        for name in Self.plateNames {
            let candidates = zip.names.filter { $0 == name || $0.hasSuffix("/" + name) }   // a localised one (en.lproj/strip.png) will do
            if let found = candidates.first, let bytes = try? zip.read(found), !bytes.isEmpty { plate = bytes; break }
        }
    }

    /// The strip is the pass's picture of the night; a background or a thumbnail stands in. Never the logo or the icon.
    static let plateNames = ["strip@3x.png", "strip@2x.png", "strip.png", "background@3x.png", "background@2x.png", "background.png",
                             "thumbnail@3x.png", "thumbnail@2x.png", "thumbnail.png"]

    /// Reads `pass.json` alone.
    init(passJSON data: Data) throws {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw Failure.unreadable("pass.json") }
        organization = AddLink.text(root["organizationName"] as? String)
        let semantics = root["semantics"] as? [String: Any] ?? [:]
        isMovie = (semantics["eventType"] as? String) == "PKEventTypeMovie"
        let style = ["eventTicket", "generic", "storeCard", "coupon", "boardingPass"].lazy.compactMap { root[$0] as? [String: Any] }.first ?? [:]
        let fields = Field.all(in: style)
        lines = ([organization, AddLink.text(root["description"] as? String)].filter { !$0.isEmpty })
            + fields.filter { !$0.isBack }.map(\.line)

        // Title.
        if let name = semantics["eventName"] as? String, !AddLink.text(name).isEmpty {
            ticket.title = name; stated.insert("title")
        } else if let field = fields.first(where: { $0.means(.title) }) {
            ticket.title = field.text; stated.insert("title")
        }
        // Cinema. A "Theatre" or "Cinema" field holding "5" or "Cinema 5" is the screen, not the building.
        if let venue = semantics["venueName"] as? String, !AddLink.text(venue).isEmpty {
            ticket.cinema = venue; stated.insert("cinema")
        } else if let field = fields.first(where: { $0.means(.cinema) && !Self.looksLikeAScreen($0.text) }) {
            ticket.cinema = field.text; stated.insert("cinema")
        }
        // When.
        if let start = (semantics["eventStartDate"] as? String).flatMap(Self.date) {
            ticket.at = start; ticket.hasTime = true; stated.insert("date")
        } else if let field = fields.first(where: { $0.means(.date) && $0.date != nil }), let date = field.date {
            ticket.at = date; ticket.hasTime = field.hasTime; stated.insert("date")
        } else if let relevant = Self.relevantDate(root) {
            ticket.at = relevant; ticket.hasTime = true; stated.insert("date")
        }
        // Screen.
        if let room = semantics["venueRoom"] as? String, !AddLink.text(room).isEmpty {
            ticket.screen = room; stated.insert("screen")
        } else if let field = fields.first(where: { $0.means(.screen) })
                    ?? fields.first(where: { $0.means(.cinema) && Self.looksLikeAScreen($0.text) }) {
            ticket.screen = field.text; stated.insert("screen")
        }
        // Seat: the semantic seat, a seat field, or a row field and a seat field together ("F" and "7" are F7).
        if let seat = (semantics["seats"] as? [[String: Any]])?.first.flatMap(Self.seat) {
            ticket.seat = seat; stated.insert("seat")
        } else if let seat = Self.seat(from: fields) {
            ticket.seat = seat; stated.insert("seat")
        }
        // Price.
        if let total = semantics["totalPrice"] as? [String: Any], let amount = Self.amount(total["amount"]) {
            ticket.price = amount
            ticket.currency = AddLink.text(total["currencyCode"] as? String).uppercased()
            stated.insert("price")
        } else if let field = fields.first(where: { $0.means(.price) && $0.amount != nil }) {
            ticket.price = field.amount
            ticket.currency = field.currency
            stated.insert("price")
        }
        // The booking's own number, kept in what the reader saw and printed nowhere.
        ticket.ref = fields.first(where: { $0.means(.reference) })?.text ?? AddLink.text(root["serialNumber"] as? String)
        // A pass from a cinema that names only itself: the issuer is the best word for where.
        if ticket.cinema.isEmpty, !organization.isEmpty { ticket.cinema = organization }
    }

    /// The draft the import sheet takes: the pass's own fields, and the heuristic parser's reading of its words for any it
    /// did not state. Full confidence when the pass stated everything it has; less when the heuristic had to help.
    func handed(fallback: StubDraft? = nil) -> (draft: StubDraft, raw: String) {
        var ticket = self.ticket
        var helped = false
        if let fallback {
            if ticket.title.isEmpty, !fallback.title.isEmpty { ticket.title = fallback.title; helped = true }
            if ticket.at == nil, let at = fallback.screenedAt { ticket.at = at; ticket.hasTime = true; helped = true }
            if ticket.screen.isEmpty, !fallback.screen.isEmpty { ticket.screen = fallback.screen; helped = true }
            if ticket.seat.isEmpty, !fallback.seat.isEmpty { ticket.seat = fallback.seat; helped = true }
            if ticket.price == nil, let price = fallback.price { ticket.price = price; ticket.currency = fallback.currency; helped = true }
        }
        var handed = AddLink.handed(ticket, readBy: "wallet-pass")
        handed.draft.confidence = helped ? 0.8 : 1
        handed.draft.organization = organization
        let raw = lines + (ticket.ref.isEmpty ? [] : ["ref: \(ticket.ref)"])
        return (handed.draft, raw.joined(separator: "\n"))
    }

    /// "5", "Cinema 5", "Theatre 12", "IMAX 2": a room, not a building.
    static func looksLikeAScreen(_ s: String) -> Bool {
        s.count <= 14 && s.range(of: #"^[\p{L} ]{0,10}\d{1,2}$"#, options: .regularExpression) != nil
    }

    /// The pass's words as a reading, for the heuristic parser to try.
    var reading: StubReading { StubReading(lines: lines) }

    // MARK: Fields

    struct Field: Equatable, Sendable {
        var key: String
        var label: String
        var text: String
        var date: Date?
        var hasTime: Bool
        var amount: Decimal?
        var currency: String
        var isBack: Bool

        var line: String { label.isEmpty ? text : "\(label): \(text)" }

        enum Meaning { case title, cinema, date, screen, seat, row, price, reference }

        /// Whether the field's key or label says it is `meaning`. Keys first (they are the developer's), labels after
        /// (they are the cinema's words, in English or French: Stub reads La Chimera's ticket too).
        func means(_ meaning: Meaning) -> Bool {
            let words = Self.words[meaning] ?? []
            let k = key.lowercased(), l = label.lowercased().trimmingCharacters(in: .punctuationCharacters.union(.whitespaces))
            if words.contains(where: { k == $0 || k.hasPrefix($0) || k.hasSuffix($0) }) { return true }
            return words.contains(where: { l == $0 || l.hasPrefix($0 + " ") || l.hasSuffix(" " + $0) })
        }

        static let words: [Meaning: [String]] = [
            .title: ["film", "movie", "title", "feature", "event", "eventname", "show", "film title", "movie title"],
            .cinema: ["cinema", "venue", "theatre", "theater", "location", "site", "cinéma", "salle de cinéma"],
            .date: ["date", "time", "session", "showtime", "starts", "start", "when", "séance", "datetime", "doors"],
            .screen: ["screen", "auditorium", "aud", "salle", "house", "hall", "theatre no", "cinema no"],
            .seat: ["seat", "seats", "seating", "place", "siège"],
            .row: ["row", "rang"],
            .price: ["price", "total", "paid", "amount", "cost", "tarif"],
            .reference: ["booking", "reference", "ref", "confirmation", "order", "booking ref", "booking number", "réservation"],
        ]

        static func all(in style: [String: Any]) -> [Field] {
            let front = ["primaryFields", "secondaryFields", "auxiliaryFields", "headerFields"].flatMap { make(style[$0], back: false) }
            return front + make(style["backFields"], back: true)
        }

        private static func make(_ list: Any?, back: Bool) -> [Field] {
            guard let list = list as? [[String: Any]] else { return [] }
            return list.compactMap { (entry: [String: Any]) -> Field? in
                let key = entry["key"] as? String ?? ""
                let label = AddLink.text(entry["label"] as? String)
                let value = entry["value"]
                var field = Field(key: key, label: label, text: "", date: nil, hasTime: true, amount: nil, currency: "", isBack: back)
                switch value {
                case let s as String:
                    field.text = AddLink.text(s)
                    // A date field's value is ISO 8601; `dateStyle` or `timeStyle` says it is one.
                    if entry["dateStyle"] != nil || entry["timeStyle"] != nil || s.range(of: #"^\d{4}-\d{2}-\d{2}T"#, options: .regularExpression) != nil {
                        field.date = WalletPass.date(s)
                        field.hasTime = (entry["timeStyle"] as? String) != "PKDateStyleNone"
                    }
                case let n as NSNumber:
                    field.text = n.stringValue
                    if let code = entry["currencyCode"] as? String { field.amount = Decimal(string: n.stringValue); field.currency = code.uppercased() }
                default:
                    return nil
                }
                if field.amount == nil, let code = entry["currencyCode"] as? String { field.amount = WalletPass.amount(field.text); field.currency = code.uppercased() }
                return field.text.isEmpty ? nil : field
            }
        }
    }

    // MARK: Values

    /// `2026-10-18T19:30+13:00`, with or without seconds: what a pass's dates look like.
    static func date(_ s: String) -> Date? {
        // A pass's dates carry their offset; one that does not is taken as the phone's time, as a link's is.
        AddLink.date(s, timeZone: .current).map(\.0)
    }

    /// iOS 18's `relevantDates` (the first one's start), else the older `relevantDate`.
    static func relevantDate(_ root: [String: Any]) -> Date? {
        if let dates = root["relevantDates"] as? [[String: Any]], let first = dates.first,
           let s = (first["startDate"] ?? first["date"]) as? String, let d = date(s) { return d }
        return (root["relevantDate"] as? String).flatMap(date)
    }

    static func amount(_ value: Any?) -> Decimal? {
        switch value {
        case let s as String: return AddLink.amount(s.replacingOccurrences(of: #"[^\d.,]"#, with: "", options: .regularExpression))
        case let n as NSNumber: return Decimal(string: n.stringValue)
        default: return nil
        }
    }

    /// A semantic seat: its row and number together ("F7"), else its identifier, else its description.
    static func seat(_ seat: [String: Any]) -> String? {
        let row = AddLink.text(seat["seatRow"] as? String), number = AddLink.text(seat["seatNumber"] as? String)
        if !row.isEmpty, !number.isEmpty { return row + number }
        for key in ["seatIdentifier", "seatDescription", "seatNumber"] {
            let s = AddLink.text(seat[key] as? String)
            if !s.isEmpty { return s }
        }
        return nil
    }

    /// A seat field, or a row field and a seat field: "Row F, Seat 7", or "F" and "7", become "F7".
    static func seat(from fields: [Field]) -> String? {
        let front = fields.filter { !$0.isBack }
        let seatField = front.first { $0.means(.seat) }
        let rowField = front.first { $0.means(.row) && !$0.means(.seat) }
        if let rowField, let seatField, rowField.text.count <= 3, seatField.text.count <= 4 {
            return rowField.text + seatField.text
        }
        guard let seatField else { return nil }
        // "Row F Seat 7" or "F 7" in one field.
        let s = seatField.text
        if let m = s.firstMatch(of: /(?i)row\s*([A-Z]{1,2})\W+seat\s*(\d{1,3})/) { return String(m.1).uppercased() + String(m.2) }
        return s.replacingOccurrences(of: #"(?i)^seats?\s*"#, with: "", options: .regularExpression)
    }
}
