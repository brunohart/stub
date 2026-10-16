import Foundation
import SwiftData
import PencilKit
import OSLog

/// What the press keeps, kept in the drawer's store so it syncs with the stubs (ADR-024): every release's printed edition,
/// its pulled proof, the proof left on the press, the owner's signature, and the poster a cinema handed over (ADR-050), as
/// `PressRecord`s. `Editions` and `Signatures`
/// keep their own fast copies (`UserDefaults`, Application Support) and write through to the ledger; when another phone's
/// records arrive, `reconcile` makes the copies match the ledger. Deleting a proof (going back) deletes its record, so going
/// back on one phone goes back on all of them.
@MainActor
final class PressLedger {
    enum Kind: String { case edition, proof, press, signature, ledger, poster }

    static let log = Logger(subsystem: "com.designedbybruno.stub", category: "ledger")

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// Whether this store's ledger has been filled: a marker record in the store itself, never a flag beside it. A store
    /// that is new, recreated, or migrated without its records has no marker and is filled again from the phone's copies
    /// before anything is adopted from it, so an empty ledger can never empty the press (2026-10-13: a flag in
    /// `UserDefaults` outlived a store's records, and the press adopted nothing).
    private var isFilled: Bool { record(.ledger, "filled") != nil }

    /// Joins the press to the ledger. The first time on a phone, whatever the phone printed, pulled and signed before the
    /// ledger existed goes into it (without overwriting what another phone already put there); then the copies are made
    /// to match it.
    func attach(_ editions: Editions, _ signatures: Signatures) {
        editions.ledger = self
        signatures.ledger = self
        Posters.shared.ledger = self
        if !isFilled {
            let encoder = JSONEncoder()
            for (key, edition) in editions.printed where record(.edition, key) == nil {
                if let data = try? encoder.encode(edition) { insert(.edition, key, data) }
            }
            for (key, proof) in editions.proofs where record(.proof, key) == nil { insert(.proof, key, proof.json) }
            for (key, proof) in editions.onPress where record(.press, key) == nil { insert(.press, key, proof.json) }
            if let drawing = signatures.drawing, record(.signature, "owner") == nil {
                insert(.signature, "owner", drawing.dataRepresentation())
            }
            insert(.ledger, "filled", Data())
            try? context.save()
            Self.log.info("Ledger filled from this phone: \(editions.printed.count) editions, \(editions.proofs.count) proofs")
        }
        reconcile(editions, signatures)
    }

    /// Makes the press's copies match the ledger: the newest record for each kind and key, extra copies of a record removed.
    func reconcile(_ editions: Editions, _ signatures: Signatures) {
        // Names and dates only: a record's bytes (a poster's are a few hundred kilobytes) are read when they are wanted.
        var everything = FetchDescriptor<PressRecord>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        everything.propertiesToFetch = [\.kind, \.key, \.updatedAt]
        let all = (try? context.fetch(everything)) ?? []
        var newest: [String: PressRecord] = [:]
        var extra = 0
        for record in all {
            let id = "\(record.kind)/\(record.key)"
            if newest[id] == nil { newest[id] = record } else { context.delete(record); extra += 1 }
        }
        if extra > 0 { try? context.save() }
        func records(_ kind: Kind) -> [String: Data] {
            Dictionary(uniqueKeysWithValues: newest.values.filter { $0.kind == kind.rawValue }.map { ($0.key, $0.data) })
        }
        let decoder = JSONDecoder()
        let printed = records(.edition).compactMapValues { try? decoder.decode(Edition.self, from: $0) }
        let proofs = records(.proof).compactMapValues { try? Proof.decoder.decode(Proof.self, from: $0) }
        let press = records(.press).compactMapValues { try? Proof.decoder.decode(Proof.self, from: $0) }
        editions.adopt(printed: printed, proofs: proofs, onPress: press)
        signatures.adopt(records(.signature)["owner"].flatMap { try? PKDrawing(data: $0) })
        let posters = Set(newest.values.filter { $0.kind == Kind.poster.rawValue }.map(\.key))
        Posters.shared.adopt(posters) { newest["\(Kind.poster.rawValue)/\($0)"]?.data }
    }

    /// Keeps `data` as the record for a kind and key, replacing any older one.
    func put(_ kind: Kind, _ key: String, _ data: Data?) {
        guard let data else { return }
        if let existing = record(kind, key) {
            existing.data = data
            existing.updatedAt = .now
        } else {
            insert(kind, key, data)
        }
        try? context.save()
    }

    /// Removes the record for a kind and key, everywhere the ledger reaches.
    func remove(_ kind: Kind, _ key: String) {
        let k = kind.rawValue
        let matching = FetchDescriptor<PressRecord>(predicate: #Predicate { $0.kind == k && $0.key == key })
        for record in (try? context.fetch(matching)) ?? [] { context.delete(record) }
        try? context.save()
    }

    private func record(_ kind: Kind, _ key: String) -> PressRecord? {
        let k = kind.rawValue
        var descriptor = FetchDescriptor<PressRecord>(predicate: #Predicate { $0.kind == k && $0.key == key },
                                                      sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    private func insert(_ kind: Kind, _ key: String, _ data: Data) {
        context.insert(PressRecord(kind: kind.rawValue, key: key, data: data))
    }
}
