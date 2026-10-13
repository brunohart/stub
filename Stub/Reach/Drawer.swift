import Foundation
import SwiftData
import OSLog

/// Housekeeping the drawer needs once it can sync (ADR-024). CloudKit cannot promise that an id is unique, so the app
/// does: when the same stub arrives twice (a phone restored from a backup and then synced, two phones filing before they
/// met), the first copy filed is kept and the others go. And a stub filed before venues existed is given its venue and
/// circuit the first time the drawer is opened after.
@MainActor
enum Drawer {
    static let log = Logger(subsystem: "com.designedbybruno.stub", category: "drawer")

    /// Deletes every copy of a stub but the first one filed; returns how many went. The one kept keeps its photograph if
    /// any copy has one.
    @discardableResult
    static func dedupe(_ context: ModelContext) -> Int {
        guard let stubs = try? context.fetch(FetchDescriptor<Stub>(sortBy: [SortDescriptor(\.createdAt)])) else { return 0 }
        var seen: [UUID: Stub] = [:]
        var gone = 0
        for stub in stubs {
            if let kept = seen[stub.id] {
                if kept.imageData == nil, let photo = stub.imageData { kept.imageData = photo }
                context.delete(stub)
                gone += 1
            } else {
                seen[stub.id] = stub
            }
        }
        if gone > 0 {
            try? context.save()
            log.notice("Drawer: \(gone) copies of stubs already in the drawer removed")
        }
        return gone
    }

    /// Gives every stub with a cinema and no venue its venue and circuit; returns how many it gave.
    @discardableResult
    static func placeVenues(_ context: ModelContext) -> Int {
        let missing = FetchDescriptor<Stub>(predicate: #Predicate { $0.venue == nil && $0.cinema != nil })
        guard let stubs = try? context.fetch(missing), !stubs.isEmpty else { return 0 }
        for stub in stubs {
            let place = Venue.resolve(cinema: stub.cinema)
            stub.venue = place.venue
            stub.circuit = place.circuit
        }
        try? context.save()
        log.info("Drawer: venues placed for \(stubs.count) stubs")
        return stubs.count
    }

    /// The setting in Settings › Stub: keep the drawer in the person's private iCloud. On unless they turn it off.
    static let syncKey = "drawer.iCloud"

    /// Whether to mirror the drawer to iCloud this launch: the setting, and never when the app is only hosting the tests.
    static func wantsSync(_ defaults: UserDefaults = .standard, environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        guard environment["XCTestConfigurationFilePath"] == nil else { return false }
        return defaults.object(forKey: syncKey) as? Bool ?? true
    }
}
