import SwiftUI
import SwiftData

@main
struct StubApp: App {
    let container: ModelContainer

    init() {
        #if DEBUG
        // A reset drawer gets a fresh sentence, not yesterday's: cleared before the table's first task can
        // read the cache for the drawer that is about to be emptied.
        if DebugSeed.resets { SeasonCache.clear() }
        #endif
        // The drawer lives where the widget can read it (Day 5). A pre-Day-5 drawer is moved across once.
        SharedStore.migrateIfNeeded()
        do {
            container = try SharedStore.container()
        } catch {
            fatalError("Stub could not open its drawer: \(error)")
        }
        Reach.shared.container = container
        #if DEBUG
        // Empty the drawer here, not in the seed: the seed waits for the probe, and in those seconds the
        // table would otherwise count yesterday's drawer and start phrasing it.
        if DebugSeed.resets { try? container.mainContext.delete(model: Stub.self) }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            TableView()
                .modelContainer(container)
                .preferredColorScheme(.light) // Day 0: parchment only. Dark drawer is a later decision.
                .task {
                    #if DEBUG
                    FontAudit.run()
                    #endif
                    // One small question, once, so the import screen's status line is what happened.
                    if #available(iOS 26.0, *) { await ModelProbe.run() }
                    #if DEBUG
                    if DebugSeed.requested { await DebugSeed.run(in: container) }
                    #endif
                }
        }
    }
}
