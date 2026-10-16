import Foundation

/// Add to Stub (BEDIP-220, ADR-021): a ticket handed over in a link that any booking confirmation can carry, or by the
/// `AddStubIntent` with the same fields. It opens the import sheet prefilled; nothing is filed until the person keeps it,
/// and nothing is fetched to open it: the fields live only in the link that was tapped. The spec is `docs/add-to-stub.md`.
///
///     https://designedbybruno.net/stub/add#title=La%20Chimera&cinema=Academy%20Cinemas&at=2026-10-18T19:30%2B13:00&seat=F7
///
/// The fields may be in the fragment (the spec's form: a fragment never reaches a server, even when Stub is not on the
/// phone and the link opens the web page) or in the query. Both are read; the fragment wins where both say something.
enum AddLink {
    static let hosts: Set<String> = ["designedbybruno.net", "www.designedbybruno.net"]
    static let path = "/stub/add"
    /// No field is longer than this. A title that is is cut, not refused.
    static let longest = 200

    enum Key: String, CaseIterable, Sendable {
        case title, cinema, at, screen, seat, price, currency, ref, poster
    }

    /// What a link (or a shortcut) handed over, in the shapes the import sheet takes.
    struct Ticket: Equatable, Sendable {
        var title = ""
        var cinema = ""
        var at: Date?
        /// Whether `at` carried a time of day. A date alone is filed at midnight, which the card prints as a date without one.
        var hasTime = false
        var screen = ""
        var seat = ""
        var price: Decimal?
        var currency = ""
        /// The booking's own reference. Kept in what the reader saw, never printed.
        var ref = ""
        /// The cinema's poster for the film: an https address on a public name, its query and fragment dropped (ADR-050).
        var poster: URL?
    }

    struct Handed: Equatable, Sendable {
        var draft: StubDraft
        /// What was handed over, a field a line: the stub's raw read, so the person can see exactly what the link said.
        var raw: String
        /// Fields that were there and could not be read (a date that is not a date). Said in the log, never guessed at.
        var unread: [String]
    }

    /// Whether `url` is an Add to Stub link.
    static func matches(_ url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "https",
              let host = components.host?.lowercased(), hosts.contains(host) else { return false }
        let path = components.path.hasSuffix("/") ? String(components.path.dropLast()) : components.path
        return path.lowercased() == Self.path
    }

    /// The link's fields, read. `nil` when it is not an Add to Stub link. `timeZone` is where a time without an offset is
    /// taken to be: the phone's, which is the best guess at the cinema's.
    static func read(_ url: URL, timeZone: TimeZone = .current) -> Handed? {
        guard matches(url), let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        var fields: [Key: String] = [:]
        for part in [components.percentEncodedQuery, components.percentEncodedFragment] {
            for (key, value) in pairs(part) { fields[key] = value }
        }
        var ticket = Ticket()
        var unread: [String] = []
        ticket.title = text(fields[.title])
        ticket.cinema = text(fields[.cinema])
        ticket.screen = text(fields[.screen])
        ticket.seat = text(fields[.seat])
        ticket.ref = text(fields[.ref])
        if let at = fields[.at], !at.isEmpty {
            if let read = date(at, timeZone: timeZone) { (ticket.at, ticket.hasTime) = read } else { unread.append("at=\(at)") }
        }
        if let price = fields[.price], !price.isEmpty {
            if let read = amount(price) { ticket.price = read } else { unread.append("price=\(price)") }
        }
        if let poster = fields[.poster], !poster.isEmpty {
            if let url = posterURL(poster) { ticket.poster = url } else { unread.append("poster") }
        }
        if let currency = fields[.currency], !currency.isEmpty {
            let code = currency.trimmingCharacters(in: .whitespaces).uppercased()
            if code.range(of: #"^[A-Z]{3}$"#, options: .regularExpression) != nil { ticket.currency = code } else { unread.append("currency=\(currency)") }
        }
        var handed = handed(ticket, readBy: "link", timeZone: timeZone)
        handed.unread = unread
        return handed
    }

    /// A ticket as the import sheet takes it: the draft, at full confidence (nothing was guessed), and the raw read.
    static func handed(_ ticket: Ticket, readBy: String, timeZone: TimeZone = .current) -> Handed {
        var draft = StubDraft()
        draft.title = text(ticket.title)
        draft.cinema = text(ticket.cinema)
        draft.screenedAt = ticket.at
        draft.screen = text(ticket.screen)
        draft.seat = text(ticket.seat)
        draft.price = ticket.price
        draft.currency = ticket.price == nil ? "" : ticket.currency
        draft.readBy = readBy
        draft.confidence = 1
        draft.poster = ticket.poster
        var lines: [String] = []
        func line(_ key: Key, _ value: String) { if !value.isEmpty { lines.append("\(key.rawValue): \(value)") } }
        line(.title, draft.title)
        line(.cinema, draft.cinema)
        if let at = ticket.at { line(.at, stamp(at, hasTime: ticket.hasTime, timeZone: timeZone)) }
        line(.screen, draft.screen)
        line(.seat, draft.seat)
        if let price = ticket.price { line(.price, "\(price)") }
        line(.currency, draft.currency)
        line(.ref, text(ticket.ref))
        if let poster = ticket.poster { line(.poster, String(poster.absoluteString.prefix(longest))) }
        return Handed(draft: draft, raw: lines.joined(separator: "\n"), unread: [])
    }

    // MARK: The poster

    /// A poster's address as Stub will fetch it, or `nil`: https on the standard port, a public domain name (no address
    /// in numbers, no `localhost`, nothing on the local network), no user or password, a path to a file, and no more than
    /// 2,048 characters. Its query and fragment are dropped, so the address is the same for everyone who is handed it and
    /// cannot carry anything about the person.
    static func posterURL(_ value: String) -> URL? {
        let s = value.trimmingCharacters(in: .whitespaces)
        guard s.count <= 2048, var components = URLComponents(string: s), isPublicHTTPS(components) else { return nil }
        guard components.path.count > 1 else { return nil }
        components.query = nil
        components.fragment = nil
        return components.url
    }

    /// Whether an address is https to a public name: the rule for the poster and for every redirect on the way to it.
    static func isPublicHTTPS(_ url: URL) -> Bool {
        URLComponents(url: url, resolvingAgainstBaseURL: false).map(isPublicHTTPS) ?? false
    }

    private static func isPublicHTTPS(_ c: URLComponents) -> Bool {
        guard c.scheme?.lowercased() == "https", c.user == nil, c.password == nil, c.port == nil || c.port == 443,
              let host = c.host?.lowercased(), !host.isEmpty else { return false }
        // A name, not an address: no IPv4 in numbers, no IPv6 at all.
        if host.contains(":") || host.range(of: #"^[0-9.]+$"#, options: .regularExpression) != nil { return false }
        let local = ["localhost", ".localhost", ".local", ".internal", ".lan", ".home.arpa", ".test", ".invalid", ".example"]
        if local.contains(where: { $0.hasPrefix(".") ? host.hasSuffix($0) : host == $0 }) { return false }
        // A public name has a dot, and only the letters, digits and hyphens a name is made of.
        return host.contains(".") && host.range(of: #"^[a-z0-9.-]+$"#, options: .regularExpression) != nil
    }

    // MARK: Reading the fields

    /// `key=value` pairs from a query or a fragment, form-decoded: `+` is a space in every field but `at`, where it is the
    /// sign of the offset (a sender who wrote `+13:00` without encoding it meant the offset). Unknown keys are ignored;
    /// a key given twice keeps its last value.
    static func pairs(_ encoded: String?) -> [(Key, String)] {
        guard let encoded, !encoded.isEmpty else { return [] }
        return encoded.split(separator: "&").compactMap { pair in
            let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard let name = parts.first.flatMap({ String($0).removingPercentEncoding?.lowercased() }),
                  let key = Key(rawValue: name) else { return nil }
            var value = parts.count > 1 ? String(parts[1]) : ""
            if key != .at { value = value.replacingOccurrences(of: "+", with: " ") }
            return (key, value.removingPercentEncoding ?? value)
        }
    }

    /// A field as words: control and format characters gone, runs of space one space, trimmed, and no longer than
    /// `longest`. The joiners stay: they hold an emoji family or a Devanagari conjunct together, and are not a trick.
    static func text(_ value: String?) -> String {
        guard let value else { return "" }
        let joiners: Set<UInt32> = [0x200C, 0x200D]
        let visible = String(String.UnicodeScalarView(value.unicodeScalars.map {
            (CharacterSet.controlCharacters.contains($0) && !joiners.contains($0.value)) || CharacterSet.newlines.contains($0) ? " " : $0
        }))
        let collapsed = visible.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return String(collapsed.prefix(longest))
    }

    /// `2026-10-18T19:30+13:00`, `…+1300`, `…Z`, `…:00`, a space for the `T`, or a date alone. Without an offset the time is
    /// the phone's; a date alone is midnight there. A day that does not exist (30 February), or a year before cinema or
    /// long after, is not a date.
    static func date(_ value: String, timeZone: TimeZone) -> (Date, hasTime: Bool)? {
        let s = value.trimmingCharacters(in: .whitespaces)
        let pattern = #"^(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2})(?::(\d{2})(?:\.\d+)?)?(Z|[+\- ]\d{2}:?\d{2})?)?$"#
        guard let match = s.firstMatch(of: try! Regex(pattern)) else { return nil }
        func int(_ i: Int) -> Int? { match.output[i].substring.flatMap { Int($0) } }
        guard let year = int(1), let month = int(2), let day = int(3), (1895...2100).contains(year) else { return nil }
        let hasTime = match.output[4].substring != nil
        var zone = timeZone
        if let offset = match.output[7].substring.map(String.init) {
            if offset == "Z" {
                zone = TimeZone(secondsFromGMT: 0)!
            } else {
                let sign = offset.hasPrefix("-") ? -1 : 1
                let digits = offset.dropFirst().replacingOccurrences(of: ":", with: "")
                guard digits.count == 4, let hh = Int(digits.prefix(2)), let mm = Int(digits.suffix(2)), hh <= 14, mm < 60,
                      let fixed = TimeZone(secondsFromGMT: sign * (hh * 3600 + mm * 60)) else { return nil }
                zone = fixed
            }
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let wanted = DateComponents(year: year, month: month, day: day, hour: int(4) ?? 0, minute: int(5) ?? 0, second: int(6) ?? 0)
        guard let date = calendar.date(from: wanted) else { return nil }
        // `date(from:)` rolls 30 February into March; a date that does not come back as itself was never a date.
        let back = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        guard back.year == year, back.month == month, back.day == day, back.hour == wanted.hour, back.minute == wanted.minute,
              back.second == wanted.second else { return nil }
        return (date, hasTime)
    }

    /// `18.50`, `18`, `1,234.50`: a number, never negative, never a symbol. "€12.50" is not a price; `currency=EUR` is.
    static func amount(_ value: String) -> Decimal? {
        let s = value.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "")
        guard s.range(of: #"^\d{1,6}(\.\d{1,2})?$"#, options: .regularExpression) != nil else { return nil }
        return Decimal(string: s, locale: Locale(identifier: "en_US_POSIX"))
    }

    /// The date as the raw read says it: what the link said, in ISO form, in the zone it was read in.
    static func stamp(_ date: Date, hasTime: Bool, timeZone: TimeZone) -> String {
        var style = Date.ISO8601FormatStyle(timeZone: timeZone)
        style = hasTime ? style.year().month().day().time(includingFractionalSeconds: false).timeZone(separator: .colon)
                        : style.year().month().day()
        return date.formatted(style)
    }
}
