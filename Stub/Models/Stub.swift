import Foundation
import SwiftData

/// One ticket stub. One night in a room with strangers. The current version of the drawer's schema (ADR-024).
typealias Stub = StubSchemaV2.Stub
/// What the press keeps, kept with the stubs so it goes where they go (ADR-024).
typealias PressRecord = StubSchemaV2.PressRecord

/// The drawer as it was from Day 0 to 2026-10-13: one model, an id SwiftData kept unique, nothing defaulted. Frozen
/// exactly, so a store made by those builds is recognised as this version and migrated, never reopened as something else.
enum StubSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [Stub.self] }

    @Model
    final class Stub {
        @Attribute(.unique) var id: UUID
        var title: String
        var cinema: String?
        var screenedAt: Date?
        var screen: String?
        var seat: String?
        var price: Decimal?
        var currency: String?
        var rawText: String
        @Attribute(.externalStorage) var imageData: Data?
        var readBy: String
        var confidence: Double
        var tilt: Double
        var createdAt: Date

        init(id: UUID = UUID(), title: String, cinema: String? = nil, screenedAt: Date? = nil, screen: String? = nil,
             seat: String? = nil, price: Decimal? = nil, currency: String? = nil, rawText: String = "", imageData: Data? = nil,
             readBy: String = "manual", confidence: Double = 1, tilt: Double = -0.8, createdAt: Date = .now) {
            self.id = id; self.title = title; self.cinema = cinema; self.screenedAt = screenedAt; self.screen = screen
            self.seat = seat; self.price = price; self.currency = currency; self.rawText = rawText; self.imageData = imageData
            self.readBy = readBy; self.confidence = confidence; self.tilt = tilt; self.createdAt = createdAt
        }
    }
}

/// The drawer from 2026-10-13 (ADR-024): what CloudKit can carry to the person's own private iCloud. Every property is
/// optional or has a default, nothing is marked unique (CloudKit cannot promise it; `Drawer.dedupe` does, in the app), and
/// each stub knows its venue and its circuit. The press's proofs, the printed editions and the owner's signature are
/// records beside the stubs, so they sync with them.
enum StubSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] { [Stub.self, PressRecord.self] }

    @Model
    final class Stub {
        var id: UUID = UUID()
        var title: String = ""
        var cinema: String?
        var screenedAt: Date?
        var screen: String?
        var seat: String?
        var price: Decimal?
        var currency: String?

        /// Everything the reader saw, verbatim. Kept so the human can correct the machine.
        var rawText: String = ""
        @Attribute(.externalStorage) var imageData: Data?

        /// Who produced the structured fields: `foundation-models`, `heuristic`, `wallet-pass`, `link`, `shortcut` or `manual`.
        var readBy: String = "manual"
        var confidence: Double = 1

        /// Authored imperfection. Fixed at creation so the stub never fidgets on its own.
        var tilt: Double = -0.8
        var createdAt: Date = Date.now

        /// The cinema's name, normalised: the same room however a ticket spelt it (ADR-024). The raw `cinema` is kept.
        var venue: String?
        /// The chain the venue belongs to ("Event", "Hoyts", "Lighthouse"), "independent", or nil when Stub does not know.
        var circuit: String?

        init(
            id: UUID = UUID(),
            title: String,
            cinema: String? = nil,
            screenedAt: Date? = nil,
            screen: String? = nil,
            seat: String? = nil,
            price: Decimal? = nil,
            currency: String? = nil,
            rawText: String = "",
            imageData: Data? = nil,
            readBy: String = "manual",
            confidence: Double = 1,
            tilt: Double = Stub.randomTilt(),
            createdAt: Date = .now,
            venue: String? = nil,
            circuit: String? = nil
        ) {
            self.id = id
            self.title = title
            self.cinema = cinema
            self.screenedAt = screenedAt
            self.screen = screen
            self.seat = seat
            self.price = price
            self.currency = currency
            self.rawText = rawText
            self.imageData = imageData
            self.readBy = readBy
            self.confidence = confidence
            self.tilt = tilt
            self.createdAt = createdAt
            self.venue = venue
            self.circuit = circuit
        }

        /// Between -1.5° and 1.5°, never level. Rounded so two stubs rarely share a tilt.
        static func randomTilt() -> Double {
            let candidates: [Double] = [-1.5, -1.1, -0.8, -0.5, 0.4, 0.7, 1.2]
            return candidates.randomElement() ?? -0.8
        }
    }

    /// One thing the press keeps, as bytes under a name: a release's printed edition, its pulled proof, the proof left on
    /// the press, or the owner's signature (`kind` and `key`). The newest `updatedAt` for a kind and key is the one.
    @Model
    final class PressRecord {
        var kind: String = ""
        var key: String = ""
        var data: Data = Data()
        var updatedAt: Date = Date.distantPast

        init(kind: String, key: String, data: Data, updatedAt: Date = .now) {
            self.kind = kind; self.key = key; self.data = data; self.updatedAt = updatedAt
        }
    }
}

/// Version 1 to version 2 is lightweight: a uniqueness constraint dropped, defaults added, two optional properties and a
/// new model. Every stub is kept with its id, its photograph and its tilt.
enum StubMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [StubSchemaV1.self, StubSchemaV2.self] }
    static var stages: [MigrationStage] { [.lightweight(fromVersion: StubSchemaV1.self, toVersion: StubSchemaV2.self)] }
}

extension Stub {
    var displayDate: String? {
        guard let screenedAt else { return nil }
        return screenedAt.formatted(.dateTime.day(.twoDigits).month(.abbreviated).year(.twoDigits))
            .uppercased()
    }

    var displayPrice: String? {
        guard let price else { return nil }
        let code = currency ?? "NZD"
        return price.formatted(.currency(code: code).precision(.fractionLength(2)))
    }

    var seatLine: String? {
        [screen, seat].compactMap { $0 }.joined(separator: " · ").nilIfEmpty
    }

    /// The date as VoiceOver should say it: "6 September 2026", not "06 SEP 26" letter by letter.
    var spokenDate: String? {
        guard let screenedAt else { return nil }
        return screenedAt.formatted(.dateTime.day().month(.wide).year())
    }

    /// What a card says when it is read aloud: the film, the date, the cinema, the seat. Nothing it does
    /// not know, and no label for the number (a seat sounds like a seat).
    var spokenLabel: String {
        var parts = [title]
        if let spokenDate { parts.append(spokenDate) }
        if let cinema { parts.append(cinema) }
        if let seat { parts.append("seat \(seat)") }
        return parts.joined(separator: ", ")
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
