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
    /// A ticket handed over from outside (ADR-021). The table opens the import sheet on it and clears it.
    var arrival: Arrival?
    /// The app's container, lent at launch so an intent does not open a second one.
    var container: ModelContainer?

    /// The drawer changed; the widget should say so.
    static func refreshWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Hand a ticket to the table, which opens the import sheet on it.
    func arrive(_ arrival: Arrival) {
        Self.log.info("Arrival from \(arrival.source.rawValue)")
        self.arrival = arrival
    }

    /// A URL the app was opened with. An Add to Stub link becomes an arrival; anything else is said in the log and left.
    /// Returns whether it was one.
    @discardableResult
    func open(_ url: URL) -> Bool {
        guard let handed = AddLink.read(url) else {
            Self.log.notice("Opened with a URL that is not an Add to Stub link; ignored")
            return false
        }
        if !handed.unread.isEmpty { Self.log.notice("Add to Stub: could not read \(handed.unread.joined(separator: ", "))") }
        arrive(Arrival(content: .known(handed.draft, raw: handed.raw, plate: nil), source: .link))
        return true
    }
}

/// The same door as the link, for Shortcuts and for any app that prefers an intent to a URL (BEDIP-220). Opens Stub on the
/// import sheet with the ticket filled in; the person keeps it or lets it go.
struct AddStubIntent: AppIntent {
    static let title: LocalizedStringResource = "Keep a ticket"
    static let description = IntentDescription("Opens Stub with a ticket filled in, to keep or let go. Nothing is sent anywhere.")
    static let openAppWhenRun = true

    @Parameter(title: "Film") var film: String
    @Parameter(title: "Cinema") var cinema: String?
    @Parameter(title: "Screening") var screening: Date?
    @Parameter(title: "Screen") var screen: String?
    @Parameter(title: "Seat") var seat: String?
    @Parameter(title: "Price") var price: Double?
    @Parameter(title: "Currency", description: "Three letters: NZD, AUD, EUR.") var currency: String?
    @Parameter(title: "Booking reference") var reference: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Keep \(\.$film) in Stub") {
            \.$cinema
            \.$screening
            \.$screen
            \.$seat
            \.$price
            \.$currency
            \.$reference
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        Reach.shared.arrive(Arrival(content: Self.handed(film: film, cinema: cinema, screening: screening, screen: screen,
                                                         seat: seat, price: price, currency: currency, reference: reference),
                                    source: .shortcut))
        return .result()
    }

    /// The intent's fields as the link's would be: the same cleaning, the same raw read, read by a shortcut.
    static func handed(film: String, cinema: String?, screening: Date?, screen: String?, seat: String?, price: Double?,
                       currency: String?, reference: String?) -> Arrival.Content {
        var ticket = AddLink.Ticket()
        ticket.title = film
        ticket.cinema = cinema ?? ""
        ticket.at = screening
        ticket.hasTime = screening != nil
        ticket.screen = screen ?? ""
        ticket.seat = seat ?? ""
        if let price, price >= 0, let amount = AddLink.amount(String(format: "%.2f", price)) { ticket.price = amount }
        if let code = currency?.trimmingCharacters(in: .whitespaces).uppercased(), code.range(of: #"^[A-Z]{3}$"#, options: .regularExpression) != nil {
            ticket.currency = code
        }
        ticket.ref = reference ?? ""
        let handed = AddLink.handed(ticket, readBy: "shortcut")
        return .known(handed.draft, raw: handed.raw, plate: nil)
    }
}
