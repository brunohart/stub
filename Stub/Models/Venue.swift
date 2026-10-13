import Foundation

/// Where a stub was seen, as a place rather than a string (BEDIP-219, ADR-024): the venue's name normalised, so
/// "EVENT CINEMAS QUEEN ST" and "Event Cinemas Queen St" are one room, and the circuit it belongs to. Derived on the
/// phone, from a pass's issuer when there is one, else from the cinema the reader read, against a small lookup of the
/// circuits of New Zealand and Australia and the independents the drawer has met. Nothing is asked of a server or of the
/// model: a chain is a fact, and a model asked for one would guess. What the lookup does not know stays unknown.
enum Venue {
    /// A circuit, and the words that name it at the start of a cinema's name or as a pass's issuer.
    struct Circuit: Sendable {
        let name: String
        let words: [String]
    }

    /// The chains, by the names on their tickets. "Event" is Event Cinemas, not its owner's other brands.
    static let circuits: [Circuit] = [
        Circuit(name: "Event", words: ["event cinemas", "event cinema"]),
        Circuit(name: "Hoyts", words: ["hoyts"]),
        Circuit(name: "Reading", words: ["reading cinemas", "reading cinema"]),
        Circuit(name: "Village", words: ["village cinemas", "village cinema"]),
        Circuit(name: "Palace", words: ["palace cinemas", "palace cinema"]),
        Circuit(name: "Dendy", words: ["dendy"]),
        Circuit(name: "Wallis", words: ["wallis cinemas"]),
        Circuit(name: "Rialto", words: ["rialto cinemas", "rialto cinema"]),
        Circuit(name: "Lighthouse", words: ["lighthouse cinema", "lighthouse cinemas"]),
        Circuit(name: "Berkeley", words: ["berkeley cinemas", "berkeley cinema"]),
        Circuit(name: "Silky Otter", words: ["silky otter"]),
        Circuit(name: "United", words: ["united cinemas"]),
    ]

    /// Single-screen and independent houses the drawer has met: a room that belongs to no chain.
    static let independents: [String] = [
        "embassy theatre", "the embassy", "the roxy cinema", "roxy cinema", "penthouse cinema", "academy cinemas",
        "bridgeway cinemas", "capitol cinema", "hollywood cinema", "the vic", "cinema nova", "the astor theatre",
        "ritz cinemas", "the lido", "lido cinemas", "cinéma du panthéon", "cinéma le champo",
    ]

    static let independent = "independent"

    /// The venue's name and its circuit, from the cinema as read and the pass's issuer when there is one.
    static func resolve(cinema: String?, organization: String? = nil) -> (venue: String?, circuit: String?) {
        let venue = cinema.flatMap(normalised)
        let circuit = circuit(of: cinema) ?? circuit(of: organization)
        return (venue, circuit)
    }

    /// The chain whose name the words start with, "independent" for a house the lookup knows, otherwise nil.
    static func circuit(of words: String?) -> String? {
        guard let words, let key = key(words) else { return nil }
        if let chain = circuits.first(where: { circuit in circuit.words.contains { key.hasPrefix(Self.key($0) ?? $0) } }) {
            return chain.name
        }
        if independents.contains(where: { key.hasPrefix(Self.key($0) ?? $0) }) { return independent }
        return nil
    }

    /// The name as it should be printed: one space between words, dashes made one, and a name that was shouted in capitals
    /// set in title case, except the words that are always capitals (IMAX, NZ).
    static func normalised(_ name: String) -> String? {
        var s = name.replacingOccurrences(of: #"[–—]"#, with: "-", options: .regularExpression)
        s = s.split(whereSeparator: \.isWhitespace).joined(separator: " ").trimmingCharacters(in: CharacterSet(charactersIn: " ,.-"))
        guard !s.isEmpty else { return nil }
        let letters = s.filter(\.isLetter)
        if !letters.isEmpty, letters == letters.uppercased() {
            s = s.lowercased().split(separator: " ").map { word in
                let w = String(word)
                if ["imax", "nz", "cbd"].contains(w) { return w.uppercased() }
                if ["du", "de", "la", "le", "of", "the", "and"].contains(w) { return w }
                return w.prefix(1).uppercased() + w.dropFirst()
            }.joined(separator: " ")
            s = s.prefix(1).uppercased() + s.dropFirst()
        }
        return s
    }

    /// The name folded for comparing: lower case, accents folded (a ticket printer without an é is the same cinema),
    /// "St" read as "Street", punctuation gone.
    static func key(_ name: String) -> String? {
        let folded = name.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en"))
            .replacingOccurrences(of: #"[^\p{L}\p{N} ]"#, with: " ", options: .regularExpression)
            .split(separator: " ")
            .map { $0 == "st" ? "street" : String($0) }
            .joined(separator: " ")
        return folded.isEmpty ? nil : folded
    }
}
