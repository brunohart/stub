import Testing
import Foundation
import SwiftData
@testable import Stub

/// What Siri and the widget are told. The store is in memory; the counting and the card are the same code.
@MainActor
struct ReachTests {
    private func drawer() throws -> ModelContainer {
        let container = try ModelContainer(for: Stub.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let calendar = Calendar.current
        let year = calendar.component(.year, from: .now)
        func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
            calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 19))!
        }
        let stubs = [
            Stub(title: "Past Lives", cinema: "Penthouse Cinema", screenedAt: day(year - 2, 2, 9), seat: "K9", createdAt: day(year - 2, 2, 10)),
            Stub(title: "Anora", cinema: "Academy Cinemas", screenedAt: day(year, 2, 19), seat: "C8", createdAt: day(year, 2, 20)),
            Stub(title: "No Other Land", cinema: "Event Cinemas Queen St", screenedAt: day(year, 3, 4), seat: "J14", createdAt: day(year, 3, 5)),
            Stub(title: "stub-9-undated", createdAt: day(year, 3, 6)),
        ]
        for stub in stubs { container.mainContext.insert(stub) }
        try container.mainContext.save()
        return container
    }

    @Test func countsTheFilmsThisYear() throws {
        let container = try drawer()
        #expect(SharedStore.filmsThisYear(in: container.mainContext) == 2, "one is two years old, one has no date")
        let empty = try ModelContainer(for: Stub.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        #expect(SharedStore.filmsThisYear(in: empty.mainContext) == 0)
    }

    @Test func theAnswerIsSpokenInWords() {
        #expect(FilmsThisYearIntent.sentence(0) == "No films this year yet.")
        #expect(FilmsThisYearIntent.sentence(1) == "One film this year.")
        #expect(FilmsThisYearIntent.sentence(2) == "Two films this year.")
        #expect(FilmsThisYearIntent.sentence(23) == "Twenty-three films this year.")
        for n in [0, 1, 2, 23] {
            let spoken = FilmsThisYearIntent.sentence(n)
            #expect(!spoken.contains { $0.isNumber }, "Siri reads words, not digits")
        }
    }

    @Test func theWidgetGetsTheLastCard() throws {
        let container = try drawer()
        let last = try #require(SharedStore.lastStub(in: container.mainContext))
        #expect(last.title == "stub-9-undated", "the most recently kept, not the most recently screened")
        let card = LastStub(last)
        #expect(card.numbers == nil && card.cinema == nil)

        let all = try container.mainContext.fetch(FetchDescriptor<Stub>())
        let anora = try #require(all.first { $0.title == "Anora" })
        let printed = LastStub(anora)
        #expect(printed.title == "Anora" && printed.cinema == "Academy Cinemas" && printed.seat == "C8")
        #expect(printed.date == "19 FEB \(String(Calendar.current.component(.year, from: .now)).suffix(2))")
        #expect(printed.numbers == "\(printed.date!) · C8")
        #expect(LastStub(title: "Aftersun", seat: "E11").numbers == "E11")

        let empty = try ModelContainer(for: Stub.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        #expect(SharedStore.lastStub(in: empty.mainContext) == nil)
    }

    @Test func theStoreMovesOnceIntoTheGroup() throws {
        let dir = URL.temporaryDirectory.appending(path: "stub-migrate-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let legacy = dir.appending(path: "default.store")
        let shared = dir.appending(path: "group").appending(path: SharedStore.filename)
        #expect(SharedStore.migrateIfNeeded(from: legacy, to: shared) == false, "nothing to move")
        try Data("drawer".utf8).write(to: legacy)
        try Data("wal".utf8).write(to: URL(filePath: legacy.path + "-wal"))
        #expect(SharedStore.migrateIfNeeded(from: legacy, to: shared) == true)
        #expect(FileManager.default.fileExists(atPath: shared.path))
        #expect(FileManager.default.fileExists(atPath: shared.path + "-wal"))
        #expect(!FileManager.default.fileExists(atPath: legacy.path))
        try Data("later".utf8).write(to: legacy)
        #expect(SharedStore.migrateIfNeeded(from: legacy, to: shared) == false, "moved once; a second legacy store never overwrites the shared one")
        let kept = try Data(contentsOf: shared)
        #expect(String(decoding: kept, as: UTF8.self) == "drawer")
        #expect(SharedStore.url.lastPathComponent == SharedStore.filename)
    }
}
