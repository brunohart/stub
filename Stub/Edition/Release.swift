import Foundation

/// The one name every stub of a film's release shares. "Dune: Part Two (IMAX)", "DUNE PART TWO" and
/// "Dune Part Two 2D" are one release, so they are one edition (ADR-015).
enum Release {
    /// Formats stripped, diacritics, case and punctuation folded, "&" read as "and", whitespace collapsed.
    /// Folded, not translated: "La Chimera" and "The Chimera" are two releases, and the drawer cannot know better.
    static func key(for title: String) -> String {
        var bare = title.trimmingCharacters(in: .whitespacesAndNewlines)
        // A ticket can print more than one format after the title ("Dune Part Two IMAX 2D"); strip until none is left.
        for _ in 0..<3 {
            let stripped = HeuristicParser.stripFormats(bare)
            if stripped == bare { break }
            bare = stripped
        }
        let folded = bare
            .folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
            .replacingOccurrences(of: "&", with: " and ")
        let kept = folded.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? Character($0) : " " }
        return String(kept).split(separator: " ").joined(separator: " ")
    }

    /// FNV-1a over the key. The same release hashes the same on every phone and every launch: `Hashable` is
    /// seeded per process (ADR-011), and an edition that reprinted itself on relaunch would not be an edition.
    static func seed(for key: String) -> UInt64 {
        fnv(key)
    }

    static func fnv(_ s: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in s.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }
}

/// SplitMix64. Seeded, so an edition draws the same composition every time it is drawn; our own, so a change
/// to the standard library's `random(in:using:)` can never reprint an edition that already exists.
struct Dice: Sendable {
    let seed: UInt64
    private var state: UInt64

    init(seed: UInt64) {
        self.seed = seed
        self.state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    /// In [0, 1). The top 53 bits, so every value a `Double` can hold in that range is reachable.
    mutating func unit() -> Double {
        Double(next() >> 11) * 0x1p-53
    }

    mutating func between(_ low: Double, _ high: Double) -> Double {
        low + (high - low) * unit()
    }

    mutating func index(_ count: Int) -> Int {
        precondition(count > 0, "nothing to pick from")
        return Int(next() % UInt64(count))
    }

    mutating func pick<T>(_ items: [T]) -> T {
        items[index(items.count)]
    }

    mutating func chance(_ p: Double) -> Bool {
        unit() < p
    }

    /// -1 or 1.
    mutating func sign() -> Double {
        chance(0.5) ? -1 : 1
    }

    /// A die of its own for one part of the drawing. Forked from the seed, not from where this die has got to,
    /// so adding a roll to one part of a composition never moves any other part.
    func fork(_ label: String) -> Dice {
        Dice(seed: seed ^ Release.fnv(label))
    }
}
