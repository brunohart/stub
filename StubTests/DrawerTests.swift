import Testing
import Foundation
import SwiftData
@testable import Stub

/// The drawer outlives the phone (BEDIP-219, ADR-024): a store made before the schema was versioned migrates with nothing
/// lost, the schema is one CloudKit can carry, a stub that arrives twice is kept once, every stub knows its venue and
/// circuit, and what the press keeps travels with the stubs.
@MainActor
struct DrawerTests {
    private func temporaryStore() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "drawer-\(UUID().uuidString)/Stub.store")
    }

    /// A drawer as the app kept it until 2026-10-13, unversioned, at version 1's shape, opened by today's app: every stub
    /// is there, with its id, its photograph and its tilt, and gets its venue the first time the drawer is opened.
    @Test func aDrawerFromBeforeMigratesWhole() throws {
        let url = temporaryStore()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let ids = [UUID(), UUID(), UUID()]
        let photo = Data(repeating: 0xAB, count: 300_000)
        do {
            let old = try ModelContainer(for: StubSchemaV1.Stub.self, configurations: ModelConfiguration(url: url, cloudKitDatabase: .none))
            let context = old.mainContext
            context.insert(StubSchemaV1.Stub(id: ids[0], title: "Past Lives", cinema: "PENTHOUSE CINEMA", seat: "K9", imageData: photo, tilt: 1.2))
            context.insert(StubSchemaV1.Stub(id: ids[1], title: "No Other Land", cinema: "Event Cinemas Queen St", tilt: -1.5))
            context.insert(StubSchemaV1.Stub(id: ids[2], title: "La Chimera", cinema: nil, readBy: "foundation-models", confidence: 0.9))
            try context.save()
        }
        let container = try SharedStore.container(at: url)
        let context = container.mainContext
        let stubs = try context.fetch(FetchDescriptor<Stub>())
        #expect(Set(stubs.map(\.id)) == Set(ids), "a stub was lost in the migration")
        let pastLives = try #require(stubs.first { $0.id == ids[0] })
        #expect(pastLives.imageData == photo && pastLives.tilt == 1.2 && pastLives.seat == "K9")
        #expect(stubs.first { $0.id == ids[2] }?.readBy == "foundation-models")
        #expect(stubs.allSatisfy { $0.venue == nil })
        #expect(Drawer.placeVenues(context) == 2, "the stub with no cinema has no venue to place")
        #expect(pastLives.venue == "Penthouse Cinema" && pastLives.circuit == Venue.independent)
        #expect(stubs.first { $0.id == ids[1] }?.circuit == "Event")
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    /// CloudKit refuses a schema with a unique attribute or a property with neither a default nor an optional; a container
    /// mirrored to the private database opens, so this one has neither.
    @Test func theSchemaIsOneCloudKitCanCarry() throws {
        let url = temporaryStore()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        SharedStore.syncFailure = nil
        let container = try SharedStore.container(sync: true, at: url)
        #expect(SharedStore.syncFailure == nil, "\(SharedStore.syncFailure ?? "")")
        #expect(SharedStore.isSyncing)
        container.mainContext.insert(Stub(title: "Conclave"))
        try container.mainContext.save()
        SharedStore.isSyncing = false
        // Kept open for the rest of the run: CloudKit's mirroring keeps working in the background (the simulator has no
        // iCloud account, so it is retrying), and a store pulled from under it is an exception on its queue.
        Self.mirrored.append(container)
    }

    private static var mirrored: [ModelContainer] = []

    /// The same stub twice (a restored phone, then a sync): the first filed is kept, with a photograph if either had one.
    @Test func aStubThatArrivesTwiceIsKeptOnce() throws {
        let container = try ModelContainer(for: SharedStore.schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let context = container.mainContext
        let id = UUID()
        context.insert(Stub(id: id, title: "Anora", createdAt: Date(timeIntervalSince1970: 100)))
        context.insert(Stub(id: id, title: "Anora", imageData: Data([1, 2, 3]), createdAt: Date(timeIntervalSince1970: 200)))
        context.insert(Stub(title: "Aftersun"))
        try context.save()
        #expect(Drawer.dedupe(context) == 1)
        let stubs = try context.fetch(FetchDescriptor<Stub>())
        #expect(stubs.count == 2)
        let anora = try #require(stubs.first { $0.id == id })
        #expect(anora.createdAt == Date(timeIntervalSince1970: 100) && anora.imageData == Data([1, 2, 3]))
        #expect(Drawer.dedupe(context) == 0)
    }

    /// The fixtures' cinemas, a pass's issuer, a shouted name, and a cinema the lookup does not know.
    @Test func everyCinemaHasAPlace() {
        let expected: [(String, String, String?)] = [
            ("Embassy Theatre", "Embassy Theatre", Venue.independent),
            ("Lighthouse Cinema Cuba", "Lighthouse Cinema Cuba", "Lighthouse"),
            ("THE ROXY CINEMA", "The Roxy Cinema", Venue.independent),
            ("Penthouse Cinema", "Penthouse Cinema", Venue.independent),
            ("EVENT CINEMAS QUEEN ST", "Event Cinemas Queen St", "Event"),
            ("Rialto Cinemas Newmarket", "Rialto Cinemas Newmarket", "Rialto"),
            ("Academy  Cinemas", "Academy Cinemas", Venue.independent),
            ("Cinéma du Panthéon", "Cinéma du Panthéon", Venue.independent),
            ("Hoyts Sylvia Park", "Hoyts Sylvia Park", "Hoyts"),
            ("Bijou Picturehouse", "Bijou Picturehouse", nil),
        ]
        for (cinema, venue, circuit) in expected {
            let place = Venue.resolve(cinema: cinema)
            #expect(place.venue == venue, "\(cinema)")
            #expect(place.circuit == circuit, "\(cinema)")
        }
        // A pass that names only a site still names its chain as its issuer.
        #expect(Venue.resolve(cinema: "Sylvia Park", organization: "HOYTS").circuit == "Hoyts")
        #expect(Venue.key("Event Cinemas Queen St.") == Venue.key("EVENT CINEMAS — QUEEN STREET"))
    }

    /// A proof pulled on one phone is on the other once their stores have synced; going back on one goes back on both.
    @Test func whatThePressKeepsTravelsWithTheStubs() throws {
        func phone() throws -> (ModelContainer, Editions, Signatures, UserDefaults) {
            let defaults = try #require(UserDefaults(suiteName: "ledger-\(UUID().uuidString)"))
            let container = try ModelContainer(for: SharedStore.schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
            let signatures = Signatures(url: FileManager.default.temporaryDirectory.appending(path: "sig-\(UUID().uuidString)"))
            return (container, Editions(defaults: defaults), signatures, defaults)
        }
        /// What CloudKit does, in a test: phone B's records become phone A's.
        func sync(_ from: ModelContainer, to: ModelContainer) throws {
            for record in try to.mainContext.fetch(FetchDescriptor<PressRecord>()) { to.mainContext.delete(record) }
            for record in try from.mainContext.fetch(FetchDescriptor<PressRecord>()) {
                to.mainContext.insert(PressRecord(kind: record.kind, key: record.key, data: record.data, updatedAt: record.updatedAt))
            }
            try to.mainContext.save()
        }

        let (a, editionsA, signaturesA, _) = try phone()
        let ledgerA = PressLedger(context: a.mainContext)
        ledgerA.attach(editionsA, signaturesA)
        let edition = Genome.floor(for: "The Brutalist")
        editionsA.store(edition)
        var proof = Proof(release: edition.release, version: edition.version)
        proof.takes[edition.movement.parts.first { $0.turns }!.id] = 14
        editionsA.pull(proof)
        #expect(editionsA.proof(for: "The Brutalist") != nil)

        let (b, editionsB, signaturesB, _) = try phone()
        try sync(a, to: b)
        PressLedger(context: b.mainContext).attach(editionsB, signaturesB)
        #expect(editionsB.underneath(for: "The Brutalist") == edition, "the same edition, not one decided again")
        #expect(editionsB.proof(for: "The Brutalist")?.takes == editionsA.proof(for: "The Brutalist")?.takes)

        editionsA.discardProof(release: edition.release)
        try sync(a, to: b)
        let ledgerB = try #require(editionsB.ledger)
        ledgerB.reconcile(editionsB, signaturesB)
        #expect(editionsB.proof(for: "The Brutalist") == nil, "going back on one phone goes back on the other")
        #expect(editionsB.underneath(for: "The Brutalist") == edition)
    }

    /// A store that lost its records (recreated, reset, migrated without them) is filled again from the phone's copies; it
    /// never empties the press.
    @Test func anEmptiedLedgerIsFilledAgainNotAdopted() throws {
        let defaults = try #require(UserDefaults(suiteName: "refill-\(UUID().uuidString)"))
        let editions = Editions(defaults: defaults)
        let signatures = Signatures(url: FileManager.default.temporaryDirectory.appending(path: "sig-\(UUID().uuidString)"))
        let first = try ModelContainer(for: SharedStore.schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        PressLedger(context: first.mainContext).attach(editions, signatures)
        let edition = Genome.floor(for: "Past Lives")
        editions.store(edition)
        // The same phone, a new store with nothing in it.
        let second = try ModelContainer(for: SharedStore.schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        PressLedger(context: second.mainContext).attach(editions, signatures)
        #expect(editions.underneath(for: "Past Lives") == edition, "the press kept its edition")
        let records = try second.mainContext.fetch(FetchDescriptor<PressRecord>())
        #expect(records.contains { $0.kind == "edition" && $0.key == edition.release }, "and the new store was filled from it")
    }

    /// The season counts the chains and the independents apart, and the front row.
    @Test func theSeasonCountsCircuits() {
        func stub(_ cinema: String, seat: String) -> Stub {
            let place = Venue.resolve(cinema: cinema)
            return Stub(title: "x", cinema: cinema, seat: seat, venue: place.venue, circuit: place.circuit)
        }
        let drawer = [stub("Event Cinemas Queen St", seat: "A4"), stub("Event Cinemas Westgate", seat: "F7"),
                      stub("Hoyts Sylvia Park", seat: "H2"), stub("Academy Cinemas", seat: "A10"), stub("Embassy Theatre", seat: "K9")]
        let summary = SeasonSummary(stubs: drawer)
        #expect(summary.circuits.map(\.name) == ["Event", "Hoyts"])
        #expect(summary.independents == 2 && summary.frontRow == 2)
        #expect(summary.brief.contains("Cinema chains: 2 (Event ×2, Hoyts ×1)"))
        #expect(summary.brief.contains("Nights at independent cinemas: 2"))
        #expect(summary.brief.contains("Nights in the front row: 2"))
        #expect(summary.handSentence == "Five stubs across five cinemas and two circuits.")
        #expect(SeasonRules.judge(summary.handSentence) == .accepted(summary.handSentence))
    }

    @Test func syncIsOnUntilThePersonTurnsItOff() throws {
        let defaults = try #require(UserDefaults(suiteName: "sync-\(UUID().uuidString)"))
        #expect(Drawer.wantsSync(defaults, environment: [:]))
        defaults.set(false, forKey: Drawer.syncKey)
        #expect(!Drawer.wantsSync(defaults, environment: [:]))
        defaults.set(true, forKey: Drawer.syncKey)
        #expect(!Drawer.wantsSync(defaults, environment: ["XCTestConfigurationFilePath": "x"]), "the tests never reach iCloud")
    }
}
