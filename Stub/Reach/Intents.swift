import AppIntents
import SwiftData
import Observation
import WidgetKit
import OSLog

/// What the outside can ask of the app: Siri, Spotlight, the Shortcuts app. Two verbs, nothing else.
/// "Log a stub" opens the drawer straight onto the import sheet; "How many films this year" answers out loud
/// without opening anything.
struct LogStubIntent: AppIntent {
    static let title: LocalizedStringResource = "Log a stub"
    static let description = IntentDescription("Opens Stub ready to read a ticket.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        Reach.shared.wantsImport = true
        Reach.log.info("LogStubIntent: opening the drawer onto import")
        return .result()
    }
}

struct FilmsThisYearIntent: AppIntent {
    static let title: LocalizedStringResource = "How many films this year"
    static let description = IntentDescription("Counts the stubs from this calendar year.")

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        let container = try Reach.shared.container ?? SharedStore.container()
        let count = SharedStore.filmsThisYear(in: container.mainContext)
        let sentence = Self.sentence(count)
        Reach.log.info("FilmsThisYearIntent: \(count) → \"\(sentence)\"")
        return .result(value: count, dialog: "\(sentence)")
    }

    /// Spoken, so the numbers are spelled out like the season's (ADR-006 is for the screen; Siri reads words).
    static func sentence(_ count: Int) -> String {
        switch count {
        case 0: return "No films this year yet."
        case 1: return "One film this year."
        default:
            let words = SeasonSummary.spelled(count)   // "twenty-three": only the first letter goes up, not every word
            return "\(words.prefix(1).uppercased() + words.dropFirst()) films this year."
        }
    }
}

struct StubShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogStubIntent(),
            phrases: ["Log a stub in \(.applicationName)", "Add a stub to \(.applicationName)"],
            shortTitle: "Log a stub",
            systemImageName: "ticket"
        )
        AppShortcut(
            intent: FilmsThisYearIntent(),
            phrases: ["How many films this year in \(.applicationName)", "Films this year in \(.applicationName)"],
            shortTitle: "Films this year",
            systemImageName: "film"
        )
    }
}

/// The bridge between an intent and the running app. An intent runs in the app's process (there is no
/// intents extension), so the table can watch `wantsImport` and the count can use the app's own container.
@MainActor @Observable
final class Reach {
    static let shared = Reach()
    static let log = Logger(subsystem: "com.designedbybruno.stub", category: "reach")

    /// Set by `LogStubIntent`; the table presents the import sheet and clears it.
    var wantsImport = false
    /// The app's container, lent at launch so an intent does not open a second one.
    var container: ModelContainer?

    /// The drawer changed; the widget should say so.
    static func refreshWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
