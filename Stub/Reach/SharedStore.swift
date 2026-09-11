import Foundation
import SwiftData

/// The drawer's store, where the app and the widget can both open it: one App Group, one file.
///
/// A host without the group (a simulator whose build carries no entitlement, a device whose profile lacks it)
/// keeps the app's own Application Support. The app works as before, the widget honestly shows an empty
/// drawer, and `isShared` says which it was. Compiled into the app and the widget; nothing here may need UIKit.
enum SharedStore {
    static let group = "group.com.designedbybruno.stub"
    static let filename = "Stub.store"

    /// The App Group container when there is one, otherwise the app's own Application Support.
    static var url: URL {
        (groupContainer ?? URL.applicationSupportDirectory).appending(path: filename)
    }

    static var groupContainer: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)
    }

    static var isShared: Bool { groupContainer != nil }

    /// The container at `url`. The widget opens it read-only: one writer, one file, no argument.
    static func container(readOnly: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(url: url, allowsSave: !readOnly)
        return try ModelContainer(for: Stub.self, configurations: configuration)
    }

    /// Days 0–4 kept the drawer at SwiftData's default path. The first launch that knows about the group moves
    /// the three SQLite files across, once, so a drawer filled before Day 5 is not left behind. Returns whether
    /// anything moved.
    @discardableResult
    static func migrateIfNeeded(from legacy: URL = URL.applicationSupportDirectory.appending(path: "default.store"),
                                to destination: URL = url) -> Bool {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: destination.path), fm.fileExists(atPath: legacy.path) else { return false }
        try? fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        var moved = false
        for suffix in ["", "-shm", "-wal"] {
            let from = URL(filePath: legacy.path + suffix)
            guard fm.fileExists(atPath: from.path) else { continue }
            let to = URL(filePath: destination.path + suffix)
            if (try? fm.moveItem(at: from, to: to)) != nil { moved = true }
        }
        return moved
    }

    /// The stub most recently kept. What the widget prints.
    static func lastStub(in context: ModelContext) -> Stub? {
        var descriptor = FetchDescriptor<Stub>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    /// Stubs screened in the calendar year of `now`. A stub without a date is not a film this year, or any year.
    static func filmsThisYear(in context: ModelContext, now: Date = .now) -> Int {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: now)
        let stubs = (try? context.fetch(FetchDescriptor<Stub>())) ?? []
        return stubs.filter { stub in
            guard let date = stub.screenedAt else { return false }
            return calendar.component(.year, from: date) == year
        }.count
    }
}

/// What the widget prints: the last stub as four strings. A value, so a timeline entry is `Sendable` and the
/// tests need no store.
struct LastStub: Equatable, Sendable {
    var title: String
    var cinema: String?
    /// "09 FEB 24", the card's date.
    var date: String?
    var seat: String?

    init(title: String, cinema: String? = nil, date: String? = nil, seat: String? = nil) {
        self.title = title; self.cinema = cinema; self.date = date; self.seat = seat
    }

    init(_ stub: Stub) {
        self.init(title: stub.title, cinema: stub.cinema?.nilIfEmpty, date: stub.displayDate, seat: stub.seat?.nilIfEmpty)
    }

    /// "09 FEB 24 · K9": the numbers on one line, whichever of them the stub has.
    var numbers: String? {
        [date, seat].compactMap { $0 }.joined(separator: " · ").nilIfEmpty
    }

    /// What the widget gallery shows before a drawer exists.
    static let placeholder = LastStub(title: "Past Lives", cinema: "Penthouse Cinema", date: "09 FEB 24", seat: "K9")
}
