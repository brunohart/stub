import Foundation

/// A design movement: the grammar an edition's poster is laid out in. The palette gives the inks, the stock
/// gives the surface; the movement decides where they go (ADR-015).
enum Movement: String, CaseIterable, Codable, Sendable {
    /// International Typographic Style. A huge flush-left title on a strict grid, one bar of colour.
    case swiss
    /// Diagonals, bands and a circle; the title runs up the diagonal.
    case constructivist
    /// Symmetry, a sunburst, stepped borders, the title centred in foil.
    case deco
    /// Cut paper after Saul Bass: torn shapes on one bold field, the title set crooked.
    case cutout
    /// Risograph: two inks overprinted and a little out of register, a halftone falling off.
    case riso
    /// Letterpress on cotton: deep type, one ink, generous margins, a single rule.
    case letterpress
    /// A technical drawing: a fine grid, dimension lines, coordinates, all in the mono.
    case blueprint
    /// Night: a dark field, venetian-blind light across it, the title low and silver.
    case noir
}

/// What the edition is printed on. It decides how the light falls on the card and how it feels under a finger.
enum Stock: String, CaseIterable, Codable, Sendable {
    /// Thick, soft, uncoated. The ink sinks in deepest; the finger drags.
    case cotton
    /// Smooth satin card. A soft sheen follows the light.
    case coated
    /// Coated card with a metal foil stamp.
    case foil
    /// Coated card with a holographic film stamp that changes colour as it turns.
    case holographic
}

/// A closed set of inks, named for what they feel like rather than for a film. The colours live in
/// `PaletteInks.swift`; the names are all the model is ever shown.
enum Palette: String, CaseIterable, Codable, Sendable {
    case sand, night, ember, tide, moss, chalk, bruise, oxide, cobalt, citrus, blush, smoke
}

/// Who chose the movement, the palette and the stock, and the takes.
enum Director: String, Codable, Sendable {
    /// The release's hash. Always there, the same on every phone.
    case hash
    /// The on-device model, choosing from the same lists, judged on the way out.
    case model
    /// The person who kept the stub, choosing between drawings at the press (ADR-016). Only an applied `Proof`
    /// directs this way; the edition underneath keeps its own director, so going back is exact.
    case you

    /// The detail's machinery line: "drawn from the title".
    var words: String {
        switch self {
        case .hash: "drawn from the title"
        case .model: "chosen by the on-device model"
        case .you: "pulled by you"
        }
    }

    /// The colophon on the back of the card: "Drawn from the title."
    var sentence: String {
        switch self {
        case .hash: "Drawn from the title."
        case .model: "Chosen by the on-device model."
        case .you: "Pulled by you."
        }
    }
}

/// The design of one release. Every stub of the release prints this; each copy adds its own facts.
struct Edition: Hashable, Codable, Sendable {
    var release: String
    var movement: Movement
    var palette: Palette
    var stock: Stock
    /// The release's hash. Every composition choice under the movement is rolled from it, never by the model.
    var seed: UInt64
    var directedBy: Director
    var version: Int = Genome.version
    /// Which take of each part is drawn: part id to take, absent meaning take 0, the drawing the title rolls. Only a
    /// proof sets these (ADR-016); an edition as the hash or the model printed it has none.
    var takes: [Part.ID: Int] = [:]

    init(release: String, movement: Movement, palette: Palette, stock: Stock, seed: UInt64, directedBy: Director,
         version: Int = Genome.version, takes: [Part.ID: Int] = [:]) {
        self.release = release; self.movement = movement; self.palette = palette; self.stock = stock
        self.seed = seed; self.directedBy = directedBy; self.version = version; self.takes = takes
    }

    private enum CodingKeys: String, CodingKey {
        case release, movement, palette, stock, seed, directedBy, version, takes
    }

    // The seed is kept as hex: a UInt64 past 2^53 is a number JSON readers are allowed to round, and a rounded
    // seed would draw a different card.
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        release = try c.decode(String.self, forKey: .release)
        movement = try c.decode(Movement.self, forKey: .movement)
        palette = try c.decode(Palette.self, forKey: .palette)
        stock = try c.decode(Stock.self, forKey: .stock)
        let hex = try c.decode(String.self, forKey: .seed)
        guard let seed = UInt64(hex, radix: 16) else {
            throw DecodingError.dataCorruptedError(forKey: .seed, in: c, debugDescription: "seed '\(hex)' is not hex")
        }
        self.seed = seed
        directedBy = try c.decode(Director.self, forKey: .directedBy)
        version = try c.decode(Int.self, forKey: .version)
        takes = try c.decodeIfPresent([Part.ID: Int].self, forKey: .takes) ?? [:]
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(release, forKey: .release)
        try c.encode(movement, forKey: .movement)
        try c.encode(palette, forKey: .palette)
        try c.encode(stock, forKey: .stock)
        try c.encode(String(seed, radix: 16), forKey: .seed)
        try c.encode(directedBy, forKey: .directedBy)
        try c.encode(version, forKey: .version)
        if !takes.isEmpty { try c.encode(takes, forKey: .takes) }
    }

    /// The die for one take of one part, and the only way a part gets a die, so no movement can roll it differently
    /// (ADR-016). Take 0 is the part's own die, forked from the release's seed by the part's id: the drawing that
    /// comes from the title. Take n is that die forked again by "take n", so every take of a part is a die of its
    /// own and no take of one part can move another.
    func dice(_ part: Part.ID, take: Int) -> Dice {
        let own = Dice(seed: seed).fork(part)
        return take == 0 ? own : own.fork("take \(take)")
    }

    /// "Constructivist, on holographic stock": the colophon's words for what this is.
    var described: String {
        let stockWords: String = switch stock {
        case .cotton: "on cotton"
        case .coated: "on coated card"
        case .foil: "foil on coated card"
        case .holographic: "holographic film on coated card"
        }
        return "\(movement.rawValue.capitalized), \(palette.rawValue) inks, \(stockWords)"
    }
}

/// The floor: an edition drawn from the release's hash alone, before and without the model.
///
/// The lists are frozen at `version`. Growing the vocabulary means a new version, so that an edition already
/// printed never reprints itself (ADR-015). They are also the model's vocabulary, word for word.
///
/// Version 2 split every movement into parts, each rolled from its own die (ADR-016). The lists and `floor` did not
/// change, so every release kept its movement, palette and stock; the compositions under them did. Version 1's
/// arrangement was retired rather than frozen, because nothing had shipped: a v1 edition in the cache is redrawn
/// at version 2 on first sight (`Editions`).
enum Genome {
    static let version = 2

    static let movements: [Movement] = [.swiss, .constructivist, .deco, .cutout, .riso, .letterpress, .blueprint, .noir]
    static let palettes: [Palette] = [.sand, .night, .ember, .tide, .moss, .chalk, .bruise, .oxide, .cobalt, .citrus, .blush, .smoke]
    static let stocks: [Stock] = [.cotton, .coated, .foil, .holographic]

    static func floor(for title: String) -> Edition {
        let key = Release.key(for: title)
        let seed = Release.seed(for: key)
        var dice = Dice(seed: seed).fork("genome")
        return Edition(
            release: key,
            movement: dice.pick(movements),
            palette: dice.pick(palettes),
            stock: dice.pick(stocks),
            seed: seed,
            directedBy: .hash
        )
    }
}

/// What one stub prints on its copy of the edition. The film's, the night's, the seat's: nothing invented.
struct Copy: Equatable, Sendable {
    var title: String
    var cinema: String?
    /// "22 MAR 2024".
    var date: String?
    /// "19:30". Absent when the ticket printed no time (a date at midnight is a date without one).
    var time: String?
    /// "2", from "Screen 2". Anything that is not "Screen n" is kept as printed ("IMAX").
    var screen: String?
    var seat: String?
    var price: String?
    /// 1 for the first time this release is in the drawer, 2 for the second.
    var viewing: Int
    /// How many stubs of this release the drawer holds: "viewing 1 of 2".
    var viewings: Int
    var year: Int?

    init(title: String, cinema: String? = nil, date: String? = nil, time: String? = nil, screen: String? = nil,
         seat: String? = nil, price: String? = nil, viewing: Int = 1, viewings: Int? = nil, year: Int? = nil) {
        self.title = title; self.cinema = cinema; self.date = date; self.time = time; self.screen = screen
        self.seat = seat; self.price = price; self.viewing = viewing; self.viewings = max(viewings ?? viewing, viewing)
        self.year = year
    }

    /// The copy a stub prints, counted against the drawer it is in.
    init(stub: Stub, among stubs: [Stub]) {
        let (viewing, viewings) = Self.viewings(of: stub, among: stubs)
        self.init(stub: stub, viewing: viewing, viewings: viewings)
    }

    init(stub: Stub, viewing: Int, viewings: Int? = nil) {
        var time: String?
        var date: String?
        var year: Int?
        if let at = stub.screenedAt {
            let c = Calendar.current.dateComponents([.year, .hour, .minute], from: at)
            if c.hour != 0 || c.minute != 0 { time = Self.clock.string(from: at) }
            date = Self.day.string(from: at).uppercased()
            year = c.year
        }
        self.init(
            title: stub.title,
            cinema: stub.cinema,
            date: date,
            time: time,
            screen: stub.screen.map { $0.replacingOccurrences(of: "Screen ", with: "") },
            seat: stub.seat,
            price: stub.displayPrice,
            viewing: viewing,
            viewings: viewings,
            year: year
        )
    }

    /// A poster prints one format whatever the phone's settings: the day, the month's short name, the year;
    /// the time on a twenty-four hour clock, the way the ticket printed it. Made per call, like `wallClock`'s:
    /// a shared formatter is mutable state that Swift 6 will not let two actors hold.
    private static var day: DateFormatter {
        let f = DateFormatter()
        f.locale = .current
        f.dateFormat = "dd MMM yyyy"
        return f
    }

    private static var clock: DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        return f
    }

    /// Which viewing of its release a stub was: the drawer's stubs of the same release, in the order they were
    /// seen (the screening, or when it was kept if the ticket printed no date).
    static func viewing(of stub: Stub, among stubs: [Stub]) -> Int {
        viewings(of: stub, among: stubs).viewing
    }

    /// Which viewing, and of how many.
    static func viewings(of stub: Stub, among stubs: [Stub]) -> (viewing: Int, of: Int) {
        let key = Release.key(for: stub.title)
        let same = stubs
            .filter { Release.key(for: $0.title) == key }
            .sorted { ($0.screenedAt ?? $0.createdAt, $0.createdAt) < ($1.screenedAt ?? $1.createdAt, $1.createdAt) }
        let viewing = (same.firstIndex { $0.id == stub.id } ?? 0) + 1
        return (viewing, max(same.count, viewing))
    }

    /// "Screen 2 · D4": the numbers the strip prints on its second line.
    var place: String? {
        [screen.map { $0.allSatisfy(\.isNumber) ? "Screen \($0)" : $0 }, seat].compactMap { $0 }.joined(separator: " · ").nilIfEmpty
    }

    /// "22 MAR 2024 · 19:30".
    var when: String? {
        [date, time].compactMap { $0 }.joined(separator: " · ").nilIfEmpty
    }

    /// "First viewing", "Second viewing". Words, like the season's (ADR-011): it is a phrase, not a figure.
    /// Past the tenth it is a figure again; a drawer with eleven of one film has earned the number.
    var viewingWords: String {
        Self.ordinals[viewing].map { "\($0) viewing" } ?? "Viewing \(viewing)"
    }

    private static let ordinals: [Int: String] = [
        1: "First", 2: "Second", 3: "Third", 4: "Fourth", 5: "Fifth",
        6: "Sixth", 7: "Seventh", 8: "Eighth", 9: "Ninth", 10: "Tenth",
    ]

    /// What the Aztec code on the back encodes: exactly what the strip prints, one field a line.
    var message: String {
        [title, cinema, when, place, price, "Viewing \(viewing)"].compactMap { $0 }.joined(separator: "\n")
    }
}
