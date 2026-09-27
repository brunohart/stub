import Foundation

/// What the person chose at the press, laid over an edition as a difference (ADR-016). Not an image: a few bytes that
/// say which movement, inks and stock, and which take of which part. The same proof prints the same card on every
/// phone, because every take is a die forked from the release's seed.
///
/// Going back is deleting the proof. Nothing underneath is overwritten.
struct Proof: Codable, Equatable, Sendable {
    var release: String
    /// `nil`: the edition's own.
    var movement: Movement?
    var palette: Palette?
    var stock: Stock?
    /// Part id to take; absent means take 0. Keyed by the namespaced id, so switching from constructivist to riso and
    /// back keeps the constructivist takes.
    var takes: [Part.ID: Int] = [:]
    /// `nil` while it is still on the press.
    var pulledAt: Date?
    /// The `Genome.version` it was pulled against.
    var version: Int = Genome.version

    /// A person who wants take 100 wants a different movement.
    static let takeRange = 0...99

    init(release: String, movement: Movement? = nil, palette: Palette? = nil, stock: Stock? = nil,
         takes: [Part.ID: Int] = [:], pulledAt: Date? = nil, version: Int = Genome.version) {
        self.release = release; self.movement = movement; self.palette = palette; self.stock = stock
        self.takes = takes; self.pulledAt = pulledAt; self.version = version
    }

    /// Exactly what the press keeps, as it keeps it: sorted keys, dates in ISO 8601.
    var json: Data {
        (try? Self.encoder.encode(self)) ?? Data()
    }

    static var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        e.dateEncodingStrategy = .iso8601
        return e
    }

    static var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}

extension Edition {
    /// This edition with `proof` laid over it. A proof for another release, or none, changes nothing. Takes are kept
    /// only for the parts the resulting movement can turn, and only when they are not 0, so a proof that differs in
    /// nothing gives back this edition exactly, director and all. One that differs in anything is directed by you.
    func applying(_ proof: Proof?) -> Edition {
        guard let proof, proof.release == release else { return self }
        var applied = self
        applied.movement = proof.movement ?? movement
        applied.palette = proof.palette ?? palette
        applied.stock = proof.stock ?? stock
        let turnable = Set(applied.movement.parts.filter(\.turns).map(\.id))
        applied.takes = proof.takes
            .filter { turnable.contains($0.key) && $0.value != 0 }
            .mapValues { min(max($0, Proof.takeRange.lowerBound), Proof.takeRange.upperBound) }
        if applied.movement != movement || applied.palette != palette || applied.stock != stock || applied.takes != takes {
            applied.directedBy = .you
        }
        return applied
    }
}

extension Proof {
    /// A proof from words, as `-proof` takes them: `"disc=14,bars=3"`, `"movement=riso,inks=moss,register=4"`. A part
    /// may be named by its last word or its whole id; it is looked up in the movement the proof ends on. Anything that
    /// does not parse is left out and reported in `unread`.
    static func parsing(_ spec: String, over edition: Edition) -> (proof: Proof, unread: [String]) {
        var proof = Proof(release: edition.release, version: edition.version)
        var pairs: [(String, String)] = []
        var unread: [String] = []
        for item in spec.split(separator: ",") {
            let kv = item.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            guard kv.count == 2 else { unread.append(String(item)); continue }
            pairs.append((kv[0], kv[1]))
        }
        // The genome first, so the parts are looked up in the movement the proof ends on.
        for (key, value) in pairs {
            switch key {
            case "movement": if let m = Movement(rawValue: value) { proof.movement = m } else { unread.append("\(key)=\(value)") }
            case "palette", "inks": if let p = Palette(rawValue: value) { proof.palette = p } else { unread.append("\(key)=\(value)") }
            case "stock": if let s = Stock(rawValue: value) { proof.stock = s } else { unread.append("\(key)=\(value)") }
            default: break
            }
        }
        let movement = proof.movement ?? edition.movement
        for (key, value) in pairs where !["movement", "palette", "inks", "stock"].contains(key) {
            let part = movement.parts.first { $0.turns && ($0.id == key || $0.id.hasSuffix("/" + key)) }
            guard let part, let take = Int(value), Proof.takeRange.contains(take) else { unread.append("\(key)=\(value)"); continue }
            proof.takes[part.id] = take
        }
        return (proof, unread)
    }
}

/// Every pulled proof, one per release, in one dictionary in `UserDefaults` (declared in the privacy manifest under
/// CA92.1, as the printed editions are). Never pruned: deleting one is going back, and only the person does that.
enum ProofCache {
    static let keyName = "edition.proofs"

    static func all(in defaults: UserDefaults = .standard) -> [String: Proof] {
        guard let data = defaults.data(forKey: keyName),
              let proofs = try? Proof.decoder.decode([String: Proof].self, from: data) else { return [:] }
        return proofs
    }

    static func store(_ proof: Proof, in defaults: UserDefaults = .standard) {
        var proofs = all(in: defaults)
        proofs[proof.release] = proof
        save(proofs, in: defaults)
    }

    static func remove(release: String, in defaults: UserDefaults = .standard) {
        var proofs = all(in: defaults)
        proofs[release] = nil
        save(proofs, in: defaults)
    }

    static func clear(in defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: keyName)
    }

    private static func save(_ proofs: [String: Proof], in defaults: UserDefaults) {
        if let data = try? Proof.encoder.encode(proofs) { defaults.set(data, forKey: keyName) }
    }
}
