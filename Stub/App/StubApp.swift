import SwiftUI
import SwiftData
import CoreData

@main
struct StubApp: App {
    let container: ModelContainer
    let ledger: PressLedger

    init() {
        #if DEBUG || PERF
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
        // What the system measures of Stub on this phone, kept on this phone (decision 004).
        FieldMetrics.shared.start()
        SharedStore.migrateIfNeeded()
        do {
            container = try SharedStore.container(sync: Drawer.wantsSync())
        } catch {
            fatalError("Stub could not open its drawer: \(error)")
        }
        if let why = SharedStore.syncFailure { Drawer.log.notice("Drawer: on this phone only; iCloud could not be set up: \(why)") }
        Reach.shared.container = container
        let context = container.mainContext
        #if DEBUG || PERF
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
        #if DEBUG || PERF
        // The measured runs' drawer and reader (decision 004).
        if let count = Stage.drawer { Stage.fill(context, count: count) }
        if Stage.rulesOnly, #available(iOS 26.0, *) { ModelProbe.stageRulesOnly() }
        #endif
        Drawer.dedupe(context)
        Drawer.placeVenues(context)
        // What the press keeps rides in the same store (ADR-024).
        let ledger = PressLedger(context: context)
        ledger.attach(Editions.shared, Signatures.shared)
        self.ledger = ledger
        #if DEBUG || PERF
        // `-inbox path`: as if the share extension had left this file, before the table first looks.
        if let path = DebugDrive.inboxFile {
            let url = URL(fileURLWithPath: path)
            let kind: Inbox.Kind = switch url.pathExtension.lowercased() { case "pkpass": .pass; case "pdf": .pdf; case "txt": .text; default: .image }
            do { try Inbox.put(url, kind: kind) } catch { Inbox.log.error("Inbox: -inbox \(path) failed: \(String(describing: error))") }
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            TableView()
                .modelContainer(container)
                .preferredColorScheme(.light) // Day 0: parchment only. Dark drawer is a later decision.
                #if DEBUG || PERF
                .fullScreenCover(isPresented: .constant(ProcessInfo.processInfo.arguments.contains("-a11y-lab"))) { ContrastLab() }
                .sheet(isPresented: .constant(ProcessInfo.processInfo.arguments.contains("-a11y-lab-sheet"))) { ContrastLab() }
                #endif
                // Another phone's stubs and proofs arriving from iCloud: one copy of each stub, and the press made to match.
                .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange).receive(on: RunLoop.main)) { _ in
                    Drawer.dedupe(container.mainContext)
                    Drawer.placeVenues(container.mainContext)
                    ledger.reconcile(Editions.shared, Signatures.shared)
                }
                .task {
                    #if DEBUG || PERF
                    FontAudit.run()
                    #endif
                    // The edition's shaders before the first card or share needs them, and CoreImage's filters for the code on
                    // a card's back, in the background (decision 004).
                    try? await EditionShaders.prepare()
                    Aztec.prewarm()
                    // One small question, once, so the import screen's status line is what happened. Asked once the launch has
                    // settled, not during it: opened from the Lock Screen at the cinema door, the first photograph is read in
                    // these seconds, and loading the model beside Vision slowed the read (decision 004, measured).
                    #if DEBUG || PERF
                    let settle: Duration = DebugSeed.requested ? .zero : .seconds(8)
                    #else
                    let settle: Duration = .seconds(8)
                    #endif
                    try? await Task.sleep(for: settle)
                    if #available(iOS 26.0, *) { await ModelProbe.run() }
                    #if DEBUG || PERF
                    if DebugSeed.requested { await DebugSeed.run(in: container) }
                    #endif
                }
        }
    }
}
