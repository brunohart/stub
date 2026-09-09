import Foundation

/// The parser that always works. Regular expressions and cinema-ticket folklore.
/// It is the floor the on-device model is measured against, and the fallback when the model is absent.
struct HeuristicParser: StubParsing {
    let name = "heuristic"

    func parse(_ reading: StubReading) async throws -> StubDraft {
        Self.parse(reading)
    }

    static func parse(_ reading: StubReading) -> StubDraft {
        var draft = StubDraft()
        var claimed = Set<Int>()
        let lines = reading.lines

        for (i, line) in lines.enumerated() {
            // Folded so CINÉMA is CINEMA to the folklore; the line itself keeps its accents.
            let upper = line.uppercased().folding(options: .diacriticInsensitive, locale: nil)

            if draft.screenedAt == nil, let date = Self.date(in: line) {
                draft.screenedAt = date
                claimed.insert(i)
            }
            if draft.seat.isEmpty, let seat = Self.seat(in: line) {
                draft.seat = seat
                claimed.insert(i)
            }
            if draft.screen.isEmpty, let screen = Self.match(#"(?i)\b(?:SCREEN|SCR|CINEMA|AUDITORIUM|AUD|HALL|THEATRE|THEATER|SALLE|SAAL|SALA)\s*[:#]?\s*(\d{1,2})\b"#, in: line) {
                draft.screen = "Screen \(screen)"
                claimed.insert(i)
            }
            if draft.price == nil, let price = Self.price(in: line) {
                draft.price = price.amount
                draft.currency = price.currency
                claimed.insert(i)
            }
            if draft.cinema.isEmpty, Self.looksLikeVenue(upper) {
                draft.cinema = Self.titleCase(line)
                claimed.insert(i)
            }
        }

        // Seat printed without the word, e.g. a lone "H12" line.
        if draft.seat.isEmpty {
            for (i, line) in lines.enumerated() where !claimed.contains(i) {
                if let seat = Self.match(#"^\s*([A-Z]{1,2}\s?\d{1,3})\s*$"#, in: line) {
                    draft.seat = seat.replacingOccurrences(of: " ", with: "")
                    claimed.insert(i)
                    break
                }
            }
        }

        // Title: the longest unclaimed line that is mostly letters and not boilerplate.
        let boilerplate = try! NSRegularExpression(pattern: #"(?i)\b(ADMIT|ADULT|CHILD|STUDENT|SENIOR|TICKET|ADMISSION|GST|TAX|TOTAL|RECEIPT|THANK|ENJOY|BOOKING|REF|WWW|\.COM|\.CO\.|ORDER|TRANS|NO REFUNDS?)\b"#)
        // A street address is the cinema's, never the film's: a number, then a street word somewhere after it.
        let address = try! NSRegularExpression(pattern: #"(?i)^\s*\d{1,5}[A-Z]?\s+\S.*\b(ST|STREET|RD|ROAD|AVE|AVENUE|LANE|LN|TERRACE|TCE|QUAY|BLVD|BOULEVARD|STRASSE|STRAßE|RUE)\b"#)
        let candidates = lines.enumerated()
            .filter { !claimed.contains($0.offset) }
            .map { $0.element }
            .filter { line in
                let letters = line.filter(\.isLetter).count
                let range = NSRange(line.startIndex..., in: line)
                return letters >= 3 && Double(letters) / Double(max(line.count, 1)) > 0.5
                    && boilerplate.firstMatch(in: line, range: range) == nil
                    && address.firstMatch(in: line, range: range) == nil
            }
        if let best = candidates.max(by: { $0.count < $1.count }) {
            draft.title = Self.titleCase(Self.stripFormats(best))
        }

        var score = 0.0
        if draft.isUsable { score += 0.4 }
        if draft.screenedAt != nil { score += 0.2 }
        if !draft.seat.isEmpty { score += 0.15 }
        if !draft.cinema.isEmpty { score += 0.15 }
        if draft.price != nil { score += 0.1 }
        draft.confidence = (score * 100).rounded() / 100   // Summed tenths land at 0.9999999999999999 in binary and the label would say 99%
        draft.readBy = "heuristic"
        return draft
    }

    // MARK: - Pieces

    static func match(_ pattern: String, in line: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(line.startIndex..., in: line)
        guard let m = regex.firstMatch(in: line, range: range), m.numberOfRanges > 1,
              let r = Range(m.range(at: 1), in: line) else { return nil }
        return String(line[r])
    }

    /// "SEAT H12", "Seat: H-12", "Row H Seat 12", "ROW H, SEAT 12", "RANG F PLACE 12", "Reihe F Platz 12".
    /// Always normalised to "H12".
    static let rowWords = "ROW|RANG|REIHE|FILA"
    static let seatWords = "SEAT|PLACE|PLATZ|SIEGE|ASIENTO|POSTO"

    static func seat(in line: String) -> String? {
        let line = line.folding(options: .diacriticInsensitive, locale: nil)
        if let row = match(#"(?i)\b(?:\#(rowWords))\s*[:#]?\s*([A-Z]{1,2})\b[\s,.\-]*(?:\#(seatWords))\s*[:#]?\s*(\d{1,3})\b"#, in: line),
           let number = match(#"(?i)\b(?:\#(rowWords))\s*[:#]?\s*[A-Z]{1,2}\b[\s,.\-]*(?:\#(seatWords))\s*[:#]?\s*(\d{1,3})\b"#, in: line) {
            return row.uppercased() + number
        }
        if let seat = match(#"(?i)\b(?:\#(seatWords))\s*[:#]?\s*([A-Z]{1,2}\s?-?\d{1,3})\b"#, in: line) {
            return seat.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "").uppercased()
        }
        return nil
    }

    static func price(in line: String) -> (amount: Decimal, currency: String)? {
        guard let raw = match(#"(?:\$|NZ\$|AU\$|US\$|£|€|EUR|GBP|USD|AUD|NZD)\s?(\d{1,3}(?:[.,]\d{2}))\b"#, in: line)
                ?? match(#"\b(\d{1,3}(?:[.,]\d{2}))\s?(?:€|\b(?:EUR|GBP|USD|AUD|NZD)\b)"#, in: line)
                ?? match(#"(?i)\b(?:PRICE|TOTAL|AMOUNT|PAID)\s*[:$]?\s*(\d{1,3}(?:[.,]\d{2}))\b"#, in: line)
        else { return nil }
        let amount = Decimal(string: raw.replacingOccurrences(of: ",", with: ".")) ?? 0
        let upper = line.uppercased()
        let currency: String
        if line.contains("£") || upper.contains("GBP") { currency = "GBP" }
        else if line.contains("€") || upper.contains("EUR") { currency = "EUR" }
        else if upper.contains("USD") { currency = "USD" }
        else if upper.contains("AUD") { currency = "AUD" }
        else if line.uppercased().contains("US$") { currency = "USD" }
        else if line.uppercased().contains("AU$") { currency = "AUD" }
        else { currency = "NZD" }
        return (amount, currency)
    }

    static let dateFormats: [String] = [
        "EEE d MMM yyyy h:mma", "EEE d MMM yyyy HH:mm", "EEE d MMM yyyy",
        "d MMM yyyy h:mma", "d MMM yyyy HH:mm", "d MMM yyyy", "d MMMM yyyy",
        "dd/MM/yyyy HH:mm", "dd/MM/yyyy h:mma", "dd/MM/yyyy", "dd/MM/yy HH:mm", "dd/MM/yy",
        "dd-MM-yyyy HH:mm", "dd-MM-yyyy", "yyyy-MM-dd HH:mm", "yyyy-MM-dd",
        "d MMM yy HH:mm", "d MMM yy", "MMM d, yyyy h:mm a", "MMM d, yyyy",
        "dd.MM.yyyy HH:mm", "dd.MM.yyyy",
    ]

    /// Stubs that leave the year off. The year is filled in from `now`, and a date that lands in the future
    /// is taken to be last year's: nobody keeps a stub for a film they have not seen yet.
    static let yearlessFormats: [String] = [
        "EEE d MMM h:mma", "EEE d MMM HH:mm", "EEE d MMM",
        "d MMM h:mma", "d MMM HH:mm", "d MMM",
        "EEE MMM d h:mma", "MMM d h:mma", "MMM d HH:mm", "MMM d",
    ]

    static func date(in line: String, now: Date = .now) -> Date? {
        let cleaned = line
            .replacingOccurrences(of: #"(?i)\b(DATE|TIME|SESSION|SHOWING|SHOWTIME)\s*[:]?"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?<=\d)(ST|ND|RD|TH|st|nd|rd|th)\b"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespaces)
        guard cleaned.range(of: #"\d"#, options: .regularExpression) != nil else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_NZ")
        formatter.timeZone = .current
        formatter.isLenient = false
        if let d = first(of: dateFormats, in: cleaned, using: formatter) { return d }

        formatter.defaultDate = now
        guard let guessed = first(of: yearlessFormats, in: cleaned, using: formatter) else { return nil }
        if guessed > now.addingTimeInterval(24 * 60 * 60) {
            return Calendar.current.date(byAdding: .year, value: -1, to: guessed)
        }
        return guessed
    }

    private static func first(of formats: [String], in cleaned: String, using formatter: DateFormatter) -> Date? {
        for format in formats {
            formatter.dateFormat = format
            if let d = formatter.date(from: cleaned) { return d }
            // Try the date as a substring by trimming trailing tokens.
            var tokens = cleaned.split(separator: " ").map(String.init)
            while tokens.count > 1 {
                tokens.removeLast()
                if let d = formatter.date(from: tokens.joined(separator: " ")) { return d }
            }
        }
        return nil
    }

    static func looksLikeVenue(_ upper: String) -> Bool {
        upper.range(of: #"\b(CINEMA|CINEMAS|THEATRE|THEATER|PICTURES|PICTUREHOUSE|MOVIES|EMBASSY|LIGHTHOUSE|ROXY|PENTHOUSE|EVENT|HOYTS|READING|IMAX|MULTIPLEX|FILMHOUSE)\b"#, options: .regularExpression) != nil
            && upper.range(of: #"\b(SCREEN|SCR|AUD|HALL)\s*\d"#, options: .regularExpression) == nil
    }

    static func stripFormats(_ title: String) -> String {
        title.replacingOccurrences(of: #"(?i)\s*\(?\b(2D|3D|IMAX|4DX|ATMOS|DOLBY|VMAX|GOLD CLASS|OC|CC|M|PG|R13|R16|R18|G)\b\)?\s*$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }

    static func titleCase(_ s: String) -> String {
        let small: Set<String> = ["of", "the", "and", "a", "an", "in", "on", "at", "to", "for", "by", "or",
                                  "du", "de", "des", "der", "von", "van", "di", "del"]
        let words = s.lowercased().split(separator: " ").map(String.init)
        return words.enumerated().map { i, w in
            (i > 0 && small.contains(w)) ? w : w.prefix(1).uppercased() + w.dropFirst()
        }.joined(separator: " ")
    }
}
