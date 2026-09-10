import Testing
import Foundation
@testable import Stub

/// The season is counted by hand and phrased by the model. These test the hand: the numbers, the sentence
/// the drawer falls back to, the hash the cache keys on, and the rules the model's sentence has to keep.
struct SeasonTests {
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d, hour: 19))!
    }

    private var drawer: [Stub] {
        [
            Stub(title: "The Brutalist", cinema: "Embassy Theatre", screenedAt: date(2024, 3, 8), price: 22, currency: "NZD"),
            Stub(title: "Perfect Days", cinema: "Lighthouse Cinema Cuba", screenedAt: date(2024, 3, 15), price: 18.5, currency: "NZD"),
            Stub(title: "Dune Part Two", cinema: "Embassy Theatre", screenedAt: date(2024, 3, 22), price: 26, currency: "NZD"),
            Stub(title: "Past Lives", cinema: "Penthouse Cinema", screenedAt: date(2024, 4, 5), price: 12.5, currency: "EUR"),
        ]
    }

    @Test func countsTheDrawer() {
        let s = SeasonSummary(stubs: drawer)
        #expect(s.films == 4)
        #expect(s.cinemas.count == 3)
        #expect(s.mostVisited == SeasonSummary.Tally(name: "Embassy Theatre", count: 2))
        #expect(s.busiestMonth?.name == "March 2024" && s.busiestMonth?.count == 3)
        #expect(s.busiestWeekday?.name == "Friday" && s.busiestWeekday?.count == 4)
        #expect(s.paid.map(\.currency) == ["EUR", "NZD"])
        #expect(s.paid.first { $0.currency == "NZD" }?.amount == Decimal(string: "66.5"))
    }

    @Test func handSentenceIsTheFloor() {
        #expect(SeasonSummary(stubs: []).handSentence.hasPrefix("Nothing in the drawer yet"))
        #expect(SeasonSummary(stubs: [drawer[0]]).handSentence == "One stub. The drawer has started.")
        #expect(SeasonSummary(stubs: drawer).handSentence == "Four stubs across three cinemas, most of them in March.")
        let one = SeasonSummary(stubs: [drawer[0], drawer[2]])
        #expect(one.handSentence == "Two stubs across one cinema.", "one month is not a 'most'")
        // The hand keeps the model's rules too.
        for stubs in [[], [drawer[0]], drawer] {
            #expect(SeasonRules.judge(SeasonSummary(stubs: stubs).handSentence) != .rejected("digits"))
        }
    }

    @Test func keyIsStableAndOrderBlind() {
        let a = SeasonSummary(stubs: drawer)
        let b = SeasonSummary(stubs: drawer.reversed())
        #expect(a.key == b.key)
        #expect(a.key == SeasonSummary(stubs: drawer).key)
        #expect(a.key != SeasonSummary(stubs: Array(drawer.dropLast())).key)
        #expect(SeasonSummary(stubs: []).key == "be95501fad8e2328", "FNV-1a of 'Stubs: 0'; the cache survives a relaunch")
    }

    @Test func briefIsFactsOnly() {
        let brief = SeasonSummary(stubs: drawer).brief
        #expect(brief.contains("Stubs: 4"))
        #expect(brief.contains("Cinemas: 3 (Embassy Theatre ×2, "))
        #expect(brief.contains("Months: March 2024 ×3, April 2024 ×1"))
        #expect(brief.contains("Paid: EUR 12.5, NZD 66.5"))
    }

    @Test func rulesAreChecked() {
        #expect(SeasonRules.judge("  Four films, three cinemas, and March did most of the work ") == .accepted("Four films, three cinemas, and March did most of the work."))
        #expect(SeasonRules.judge("“Mostly Fridays at the Embassy.”") == .accepted("Mostly Fridays at the Embassy."))
        #expect(SeasonRules.judge("What a season!") == .rejected("exclamation mark"))
        #expect(SeasonRules.judge("Four films in 2024.") == .rejected("digits"))
        #expect(SeasonRules.judge("Four films 🎬") == .rejected("emoji"))
        #expect(SeasonRules.judge("Four films. Three cinemas.") == .rejected("more than one sentence"))
        #expect(SeasonRules.judge("") == .rejected("empty"))
        let long = Array(repeating: "word", count: 20).joined(separator: " ")
        #expect(SeasonRules.judge(long) == .rejected("20 words"))
        #expect(SeasonRules.judge("Twelve point five euros is not a digit.") == .accepted("Twelve point five euros is not a digit."))
    }

    @Test func cacheIsKeyedOnTheDrawer() {
        let defaults = UserDefaults(suiteName: "season-tests-\(UUID().uuidString)")!
        defer { SeasonCache.clear(in: defaults) }
        #expect(SeasonCache.sentence(for: "abc", in: defaults) == nil)
        SeasonCache.store("Four stubs.", for: "abc", in: defaults)
        #expect(SeasonCache.sentence(for: "abc", in: defaults) == "Four stubs.")
        #expect(SeasonCache.sentence(for: "abd", in: defaults) == nil, "a changed drawer is a new sentence")
        SeasonCache.store("Five stubs.", for: "abd", in: defaults)
        #expect(SeasonCache.sentence(for: "abc", in: defaults) == nil, "one drawer, one present")
    }

    @Test func spellsAndCounts() {
        #expect(SeasonSummary.spelled(8) == "eight")
        #expect(SeasonSummary.spelled(21) == "twenty-one")
        #expect(SeasonSummary.times(1) == "once")
        #expect(SeasonSummary.times(2) == "twice")
        #expect(SeasonSummary.times(3) == "three times")
    }
}
