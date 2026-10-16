import Foundation
import SwiftData
import ImageIO
import UniformTypeIdentifiers

/// What the widget deals (ADR-027): one stub at a time from the drawer, newest kept first, drawn as its edition from the
/// edition's own marks, never as a picture of it. "Another" deals the next; "Turn it over" shows the ticket as it was kept.
/// Compiled into the app and the widget; the widget reads the drawer's store and what the press keeps in it, and the place
/// in the deck is kept in the App Group, where both can see it.
enum Deck {
    static let offsetKey = "deck.offset"
    static let turnedKey = "deck.turned"
    /// How many stubs there were when the deck was last dealt: one kept since, and the deck starts again at the newest.
    static let countKey = "deck.count"

    static var defaults: UserDefaults { UserDefaults(suiteName: AppGroup.id) ?? .standard }

    /// One stub, ready to draw: its edition composed for its copy, and the ticket as kept, small enough for a widget.
    struct Card: Sendable {
        let id: UUID
        let composition: Composition
        let title: String
        let cinema: String?
        let numbers: String?
        let photo: Data?
        let position: Int
        let count: Int
    }

    /// The stubs in the order the deck deals them.
    static func order(_ stubs: [Stub]) -> [Stub] {
        stubs.sorted { $0.createdAt > $1.createdAt }
    }

    /// The release's edition as the press keeps it in the drawer's store (ADR-024): the newest record of it, its pulled
    /// proof laid over it, drawn at the genome's current version. The title's own when the press has none.
    static func edition(for title: String, in records: [PressRecord]) -> Edition {
        let key = Release.key(for: title)
        func newest(_ kind: String) -> Data? {
            records.filter { $0.kind == kind && $0.key == key }.max { $0.updatedAt < $1.updatedAt }?.data
        }
        var edition = newest("edition").flatMap { try? JSONDecoder().decode(Edition.self, from: $0) } ?? Genome.floor(for: title)
        if edition.version < Genome.version { edition.version = Genome.version }
        let proof = newest("proof").flatMap { try? Proof.decoder.decode(Proof.self, from: $0) }
        return edition.applying(proof)
    }

    /// The card the deck is on, and whether it is turned over.
    static func current(in context: ModelContext, defaults: UserDefaults = defaults, photoSize: Int = 640) -> (card: Card?, turned: Bool) {
        let stubs = order((try? context.fetch(FetchDescriptor<Stub>())) ?? [])
        guard !stubs.isEmpty else { return (nil, false) }
        if defaults.integer(forKey: countKey) != stubs.count {
            defaults.set(stubs.count, forKey: countKey)
            defaults.set(0, forKey: offsetKey)
            defaults.set(false, forKey: turnedKey)
        }
        let position = ((defaults.integer(forKey: offsetKey) % stubs.count) + stubs.count) % stubs.count
        let stub = stubs[position]
        let records = (try? context.fetch(FetchDescriptor<PressRecord>())) ?? []
        let composition = Composition(edition: edition(for: stub.title, in: records), copy: Copy(stub: stub, among: stubs))
        let card = Card(id: stub.id, composition: composition, title: stub.title, cinema: stub.venue ?? stub.cinema,
                        numbers: [stub.displayDate, stub.seat].compactMap { $0 }.joined(separator: " · ").nilIfEmpty,
                        photo: stub.imageData.flatMap { thumbnail($0, size: photoSize) }, position: position, count: stubs.count)
        return (card, defaults.bool(forKey: turnedKey))
    }

    /// The next stub, face up.
    static func deal(_ defaults: UserDefaults = defaults) {
        defaults.set(defaults.integer(forKey: offsetKey) + 1, forKey: offsetKey)
        defaults.set(false, forKey: turnedKey)
    }

    /// Over, or back.
    static func turn(_ defaults: UserDefaults = defaults) {
        defaults.set(!defaults.bool(forKey: turnedKey), forKey: turnedKey)
    }

    /// A widget has little memory: the photograph, read small, straight from its file.
    static func thumbnail(_ data: Data, size: Int) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true,
                  kCGImageSourceThumbnailMaxPixelSize: size,
              ] as CFDictionary) else { return nil }
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
        return CGImageDestinationFinalize(dest) ? out as Data : nil
    }
}

/// `stub://stub/<id>`: the drawer opens that stub. The widget's card says where it goes this way.
/// `stub://keep`: Keep a stub's viewfinder, from the Lock Screen's control (docs/decisions/002-surfaces.md).
enum StubLink {
    static func url(for id: UUID) -> URL { URL(string: "stub://stub/\(id.uuidString)")! }
    static let keep = URL(string: "stub://keep")!
    static func isKeep(_ url: URL) -> Bool { url.scheme == "stub" && url.host() == "keep" }

    static func id(in url: URL) -> UUID? {
        guard url.scheme == "stub", url.host() == "stub" else { return nil }
        return UUID(uuidString: url.lastPathComponent)
    }
}
