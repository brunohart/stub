import SwiftUI
import SwiftData
import CoreData

@main
struct StubApp: App {
    let container: ModelContainer
    let ledger: PressLedger

    init() {
        #if DEBUG
        // A reset drawer gets a fresh sentence, not yesterday's: cleared before the table's first task can
        // read the cache for the drawer that is about to be emptied.
        // The editions go with it, their proofs and the signature: a reset drawer's releases are chosen and printed again.
        if DebugSeed.resets { SeasonCache.clear(); EditionCache.clear(); ProofCache.clear(); Signatures.shared.redo() }
        // `-signed`: the fixture signature, so the back of a proof can be screenshotted signed.
        if DebugDrive.wantsSigned, !Signatures.shared.isSigned { Signatures.shared.keep(Signatures.fixture()) }
        #endif
        // The drawer lives where the widget can read it (Day 5). A pre-Day-5 drawer is moved across once. It is opened at
        // the current schema, migrating a version 1 store, and mirrored to the person's private iCloud unless they said
        // to keep it on this phone (ADR-024).
        SharedStore.migrateIfNeeded()
        do {
            container = try SharedStore.container(sync: Drawer.wantsSync())
        } catch {
            fatalError("Stub could not open its drawer: \(error)")
        }
        if let why = SharedStore.syncFailure { Drawer.log.notice("Drawer: on this phone only; iCloud could not be set up: \(why)") }
        Reach.shared.container = container
        let context = container.mainContext
        #if DEBUG
        // Empty the drawer here, not in the seed: the seed waits for the probe, and in those seconds the
        // table would otherwise count yesterday's drawer and start phrasing it. The press's ledger goes with it, before
        // the press is joined to it, or yesterday's editions would come back from the store.
        if DebugSeed.resets {
            try? context.delete(model: Stub.self)
            try? context.delete(model: PressRecord.self)
            try? context.delete(model: StubDrawer.self)
            try? context.save()
        }
        #endif
        Drawer.dedupe(context)
        Drawer.placeVenues(context)
        // What the press keeps rides in the same store (ADR-024).
        let ledger = PressLedger(context: context)
        ledger.attach(Editions.shared, Signatures.shared)
        self.ledger = ledger
        #if DEBUG
        // `-inbox path`: as if the share extension had left this file, before the table first looks.
        if let path = DebugDrive.inboxFile {
            let url = URL(fileURLWithPath: path)
            let kind: Inbox.Kind = switch url.pathExtension.lowercased() { case "pkpass": .pass; case "pdf": .pdf; default: .image }
            do { try Inbox.put(url, kind: kind) } catch { Inbox.log.error("Inbox: -inbox \(path) failed: \(String(describing: error))") }
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            TableView()
                .modelContainer(container)
                .preferredColorScheme(.light) // Day 0: parchment only. Dark drawer is a later decision.
                // Another phone's stubs and proofs arriving from iCloud: one copy of each stub, and the press made to match.
                .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange).receive(on: RunLoop.main)) { _ in
                    Drawer.dedupe(container.mainContext)
                    Drawer.placeVenues(container.mainContext)
                    ledger.reconcile(Editions.shared, Signatures.shared)
                }
                .task {
                    #if DEBUG
                    FontAudit.run()
                    #endif
                    // The edition's shaders before the first card, share or room map needs them.
                    try? await EditionShaders.prepare()
                    // One small question, once, so the import screen's status line is what happened.
                    if #available(iOS 26.0, *) { await ModelProbe.run() }
                    #if DEBUG
                    if DebugSeed.requested { await DebugSeed.run(in: container) }
                    #endif
                }
        }
    }
}
