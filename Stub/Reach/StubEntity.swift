import AppIntents
import CoreSpotlight
import SwiftData
import OSLog

/// A stub as the system sees it (docs/decisions/002-surfaces.md): indexed in Spotlight on this phone, so "Anora" finds the
/// night it was seen and opens it, and offered to Siri and Shortcuts as something to find and open. The index is the
/// phone's own; nothing in it leaves the phone.
struct StubEntity: AppEntity, IndexedEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Stub"
    static let defaultQuery = StubQuery()

    var id: UUID
    var title: String
    var place: String
    var night: Date?

    var displayRepresentation: DisplayRepresentation {
        let when = night.map { $0.formatted(.dateTime.day().month(.abbreviated).year()) }
        let subtitle = [place.isEmpty ? nil : place, when].compactMap { $0 }.joined(separator: " · ")
        return DisplayRepresentation(title: "\(title)", subtitle: subtitle.isEmpty ? nil : "\(subtitle)",
                                     image: .init(systemName: "ticket"))
    }

    /// What Spotlight matches besides the title: the cinema, the circuit and the year, so "Rialto" and "2024" find stubs too.
    var attributeSet: CSSearchableItemAttributeSet {
        let set = defaultAttributeSet
        var words = [place]
        if let night { words.append(String(Calendar.current.component(.year, from: night))) }
        set.keywords = words.filter { !$0.isEmpty }
        set.contentCreationDate = night
        return set
    }

    @MainActor
    init(_ stub: Stub) {
        id = stub.id
        title = stub.title
        place = stub.venue ?? stub.cinema ?? ""
        night = stub.screenedAt
    }
}

/// Stubs by id, and the latest few to suggest, from the app's own drawer.
struct StubQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [StubEntity] {
        guard let context = Reach.shared.container?.mainContext else { return [] }
        let wanted = Set(identifiers)
        return ((try? context.fetch(FetchDescriptor<Stub>())) ?? []).filter { wanted.contains($0.id) }.map(StubEntity.init)
    }

    @MainActor
    func suggestedEntities() async throws -> [StubEntity] {
        guard let context = Reach.shared.container?.mainContext else { return [] }
        var latest = FetchDescriptor<Stub>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        latest.fetchLimit = 12
        return ((try? context.fetch(latest)) ?? []).map(StubEntity.init)
    }
}

/// Open a stub: from Spotlight, Siri or Shortcuts, the drawer opens on it.
struct OpenStubIntent: OpenIntent {
    static let title: LocalizedStringResource = "Open a stub"
    static let description = IntentDescription("Opens a stub in Stub's drawer.")

    @Parameter(title: "Stub")
    var target: StubEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        Reach.shared.wantsStub = target.id
        return .result()
    }
}

/// The drawer, in Spotlight's index on this phone: every stub, written again when the drawer changes. The whole type is
/// replaced each time, so a stub thrown away leaves the index with it.
enum Spotlight {
    static let log = Logger(subsystem: "com.designedbybruno.stub", category: "spotlight")

    @MainActor
    static func index(_ stubs: [Stub]) async {
        let entities = stubs.map(StubEntity.init)
        do {
            try await CSSearchableIndex.default().deleteAppEntities(ofType: StubEntity.self)
            try await CSSearchableIndex.default().indexAppEntities(entities)
            log.info("Spotlight: \(entities.count) stubs indexed")
        } catch {
            log.error("Spotlight: \(error.localizedDescription)")
        }
    }
}
