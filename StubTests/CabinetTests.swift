import Testing
import Foundation
import SwiftData
@testable import Stub

/// The cabinet (ADR-026): every drawer filed by year, newest first; within a year, the person's order; drawers they make,
/// filed by the night; and the store that keeps all of it, migrated from version 2 with nothing lost.
@MainActor
struct CabinetTests {
    private func day(_ s: String) -> Date { ISO8601DateFormatter().date(from: s + "T19:30:00Z")! }

    private func drawer(_ stubs: [Stub]) throws -> ModelContainer {
        let container = try ModelContainer(for: SharedStore.schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        stubs.forEach { container.mainContext.insert($0) }
        return container
    }

    private var sample: [Stub] {
        [Stub(title: "Anora", screenedAt: day("2025-02-19"), createdAt: day("2025-02-20")),
         Stub(title: "Aftersun", screenedAt: day("2024-06-02"), createdAt: day("2024-06-03")),
         Stub(title: "No Other Land", screenedAt: day("2025-03-04"), createdAt: day("2025-03-05")),
         Stub(title: "Past Lives", screenedAt: day("2024-02-09"), createdAt: day("2024-02-10")),
         Stub(title: "Undated", createdAt: day("2025-01-01"))]
    }

    @Test func theYearsAreNewestFirstAndEachYearNewestNightFirst() {
        let ordered = Cabinet.order(sample, in: nil).map(\.title)
        #expect(ordered == ["No Other Land", "Anora", "Undated", "Aftersun", "Past Lives"])
        let years = Cabinet.sections(Cabinet.order(sample, in: nil))
        #expect(years.map(\.year) == [2025, 2024])
        #expect(years.map(\.stubs.count) == [3, 2])
    }

    @Test func aStubMovesOnlyWithinItsYear() {
        let stubs = sample
        let ids = Cabinet.order(stubs, in: nil).map(\.id)
        let year = Dictionary(uniqueKeysWithValues: stubs.map { ($0.id, Cabinet.year(of: $0)) })
        let same: (UUID, UUID) -> Bool = { year[$0] == year[$1] }
        // "Undated" (2025) to where "No Other Land" (2025) stands: it goes to the front of the year.
        let moved = Cabinet.move(ids[2], to: ids[0], in: ids, sameYear: same)
        #expect(moved == [ids[2], ids[0], ids[1], ids[3], ids[4]])
        // Down the year: after the target.
        #expect(Cabinet.move(ids[0], to: ids[2], in: ids, sameYear: same) == [ids[1], ids[2], ids[0], ids[3], ids[4]])
        // Across a divider: nothing moves.
        #expect(Cabinet.move(ids[0], to: ids[3], in: ids, sameYear: same) == ids)
    }

    @Test func theOrderAHandMadeIsKeptAndANewStubStandsAtTheFrontOfItsYear() throws {
        let stubs = sample
        let container = try drawer(stubs)
        let ids = Cabinet.order(stubs, in: nil).map(\.id)
        let reversed2025 = [ids[2], ids[1], ids[0], ids[3], ids[4]]
        #expect(Cabinet.commit(reversed2025, stubs: stubs, in: nil) == 5, "every stub gets its place the first time")
        #expect(Cabinet.order(stubs, in: nil).map(\.id) == reversed2025)
        #expect(Cabinet.commit(reversed2025, stubs: stubs, in: nil) == 0, "the same order writes nothing")
        let kept = Stub(title: "Conclave", screenedAt: day("2025-11-01"))
        container.mainContext.insert(kept)
        #expect(Cabinet.order(stubs + [kept], in: nil).first?.id == kept.id)
    }

    @Test func aDrawerFilesByTheNightAndKeepsItsOwnOrder() throws {
        let stubs = sample
        let festival = StubDrawer(name: "Festival")
        for stub in stubs.shuffled() { Cabinet.file(stub, in: festival, among: stubs) }
        #expect(festival.stubIDs.compactMap { id in stubs.first { $0.id == id }?.title }
            == ["No Other Land", "Anora", "Undated", "Aftersun", "Past Lives"], "filed newest night first, whatever the order they came")
        Cabinet.file(stubs[0], in: festival, among: stubs)
        #expect(festival.stubIDs.count == 5, "filing twice files once")
        // Shown: 2024 only. Its order is written; 2025's stubs keep their place at the back.
        let shown2024 = [stubs[3].id, stubs[1].id]
        #expect(Cabinet.commit(shown2024, stubs: stubs, in: festival) == 1)
        #expect(festival.stubIDs.prefix(2) == ArraySlice(shown2024) && festival.stubIDs.count == 5)
        Cabinet.takeOut(stubs[1].id, of: festival)
        #expect(!festival.stubIDs.contains(stubs[1].id))
        #expect(Cabinet.members(of: festival, among: stubs).count == 4)
        #expect(Cabinet.members(of: nil, among: stubs).count == 5)
    }

    @Test func aDrawerNameIsTypedClean() {
        #expect(Cabinet.name("  With Mum \n") == "With Mum")
        #expect(Cabinet.name("   ") == nil)
        #expect(Cabinet.name(String(repeating: "a", count: 50))?.count == 32)
    }

    /// A drawer kept at version 2 opens at version 3 with every stub and every record, and takes a drawer.
    @Test func aVersionTwoDrawerMigratesWhole() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "v2-\(UUID().uuidString)/Stub.store")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let id = UUID()
        do {
            let schema = Schema(versionedSchema: StubSchemaV2.self)
            let old = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none))
            old.mainContext.insert(StubSchemaV2.Stub(id: id, title: "Past Lives", cinema: "Penthouse Cinema", tilt: 1.2, venue: "Penthouse Cinema"))
            old.mainContext.insert(StubSchemaV2.PressRecord(kind: "edition", key: "past lives", data: Data([1, 2])))
            try old.mainContext.save()
        }
        let container = try SharedStore.container(at: url)
        let stubs = try container.mainContext.fetch(FetchDescriptor<Stub>())
        #expect(stubs.map(\.id) == [id] && stubs.first?.tilt == 1.2 && stubs.first?.venue == "Penthouse Cinema")
        #expect(stubs.first?.handOrder == nil)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<PressRecord>()) == 1)
        let mum = StubDrawer(name: "With Mum", stubIDs: [id])
        container.mainContext.insert(mum)
        try container.mainContext.save()
        #expect(try container.mainContext.fetch(FetchDescriptor<StubDrawer>()).first?.stubIDs == [id])
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    @Test func theDrawerAsASpreadsheetEscapesWhatNeedsIt() {
        let stub = Stub(title: "Dune: Part Two, IMAX", cinema: "The \"Roxy\"", screenedAt: day("2024-03-30"), seat: "G11", price: 21, currency: "NZD")
        let drawer = StubDrawer(name: "Festival", stubIDs: [stub.id])
        let csv = DrawerExport.csv(stubs: [stub], drawers: [drawer])
        let lines = csv.split(separator: "\n")
        #expect(lines.first == "Film,Cinema,Venue,Circuit,Screened,Screen,Seat,Price,Currency,Read by,Drawers")
        #expect(lines.last?.hasPrefix(#""Dune: Part Two, IMAX","The ""Roxy""",,,2024-03-3"#) == true)
        #expect(lines.last?.hasSuffix(",G11,21,NZD,manual,Festival") == true)
    }

    @Test func aWidgetLinkOpensItsStub() {
        let id = UUID()
        #expect(StubLink.id(in: StubLink.url(for: id)) == id)
        #expect(StubLink.id(in: URL(string: "https://designedbybruno.net/stub")!) == nil)
    }
}

/// The widget's deck (ADR-027): newest kept first, the edition from what the press keeps, dealt and turned in place.
@MainActor
struct DeckTests {
    @Test func theEditionIsThePressesNewestWithItsProofOverIt() throws {
        let floor = Genome.floor(for: "Anora")
        var older = floor
        older.movement = .swiss
        var newer = floor
        newer.movement = .noir
        var proof = Proof(release: floor.release, version: floor.version)
        proof.palette = .ember
        let records = [
            PressRecord(kind: "edition", key: floor.release, data: try JSONEncoder().encode(older), updatedAt: Date(timeIntervalSince1970: 10)),
            PressRecord(kind: "edition", key: floor.release, data: try JSONEncoder().encode(newer), updatedAt: Date(timeIntervalSince1970: 20)),
            PressRecord(kind: "proof", key: floor.release, data: proof.json),
        ]
        let edition = Deck.edition(for: "ANORA", in: records)
        #expect(edition.movement == .noir && edition.palette == .ember && edition.directedBy == .you)
        #expect(Deck.edition(for: "Aftersun", in: records) == Genome.floor(for: "Aftersun"), "no record: the title's own")
    }

    @Test func theDeckDealsTurnsAndStartsAgainWhenAStubIsKept() throws {
        let defaults = try #require(UserDefaults(suiteName: "deck-\(UUID().uuidString)"))
        let container = try ModelContainer(for: SharedStore.schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let context = container.mainContext
        for (i, title) in ["Past Lives", "Aftersun", "Anora"].enumerated() {
            context.insert(Stub(title: title, createdAt: Date(timeIntervalSince1970: Double(i) * 100)))
        }
        try context.save()
        #expect(Deck.current(in: context, defaults: defaults).card?.title == "Anora", "the newest kept first")
        Deck.deal(defaults)
        Deck.turn(defaults)
        let (card, turned) = Deck.current(in: context, defaults: defaults)
        #expect(card?.title == "Aftersun" && card?.position == 1 && card?.count == 3 && turned)
        Deck.deal(defaults)
        #expect(Deck.current(in: context, defaults: defaults).turned == false, "a stub is dealt face up")
        Deck.deal(defaults)
        #expect(Deck.current(in: context, defaults: defaults).card?.title == "Anora", "round again")
        Deck.deal(defaults)
        context.insert(Stub(title: "Conclave", createdAt: Date(timeIntervalSince1970: 1000)))
        try context.save()
        #expect(Deck.current(in: context, defaults: defaults).card?.title == "Conclave", "a stub kept starts the deck again")
    }
}
