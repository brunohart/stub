import SwiftUI
import SwiftData

@main
struct StubApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: Stub.self)
        } catch {
            fatalError("Stub could not open its drawer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            TableView()
                .modelContainer(container)
                .preferredColorScheme(.light) // Day 0: parchment only. Dark drawer is a later decision.
                .task {
                    #if DEBUG
                    FontAudit.run()
                    if DebugSeed.requested { await DebugSeed.run(in: container) }
                    #endif
                }
        }
    }
}
