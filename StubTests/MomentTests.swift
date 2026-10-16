import Testing
import Foundation
@testable import Stub

/// The moment (docs/decisions/001-the-moment.md): the rules' draft is kept at once, the model improves it in place without
/// undoing a hand, and the model is let go at its deadline even when it does not stop.
struct MomentTests {
    private let floor = StubDraft(title: "Anora", cinema: "Academy Cinemas", screenedAt: Date(timeIntervalSince1970: 1_740_000_000),
                                  screen: "Screen 2", seat: "C8", price: 19, currency: "NZD", confidence: 0.6, readBy: "heuristic")

    @Test func theModelsAnswerKeepsTheRulesWhereItIsEmpty() {
        let model = StubDraft(title: "Anora", cinema: "", screenedAt: nil, screen: "Screen 2", seat: "", price: nil,
                              currency: "", confidence: 0.9, readBy: "foundation-models")
        let merged = model.over(floor)
        #expect(merged.cinema == "Academy Cinemas")
        #expect(merged.screenedAt == floor.screenedAt)
        #expect(merged.seat == "C8")
        #expect(merged.price == 19 && merged.currency == "NZD")
        #expect(merged.readBy == "foundation-models")
    }

    @Test func theModelsAnswerWinsWhereItDisagrees() {
        let model = StubDraft(title: "Anora", cinema: "Academy Cinemas Auckland", screen: "Screen 3", seat: "C9",
                              confidence: 0.9, readBy: "foundation-models")
        let merged = model.over(floor)
        #expect(merged.cinema == "Academy Cinemas Auckland")
        #expect(merged.screen == "Screen 3")
        #expect(merged.seat == "C9")
    }

    @Test func aLaterAnswerNeverUndoesAHand() {
        var onScreen = floor
        onScreen.seat = "C10"   // the person corrected the seat while the model was still reading
        let later = StubDraft(title: "Anora", cinema: "Academy Cinemas Auckland", screenedAt: floor.screenedAt,
                              screen: "Screen 2", seat: "C8", price: 19, currency: "NZD", confidence: 0.9, readBy: "foundation-models")
        let next = onScreen.adopting(later, unchangedFrom: floor)
        #expect(next.seat == "C10", "the person's seat stays")
        #expect(next.cinema == "Academy Cinemas Auckland", "an untouched field takes the later answer")
        #expect(next.readBy == "foundation-models")
    }

    @Test func theDeadlineLetsGoOfWorkThatWillNotStop() async {
        let clock = ContinuousClock()
        let started = clock.now
        // Work that ignores cancellation, as a model's stream winding down on a busy phone can.
        let outcome = await Deadline.race(.milliseconds(200)) { () -> Int in
            Self.block(1.5)
            return 1
        }
        let waited = started.duration(to: clock.now)
        guard case .timedOut = outcome else { Issue.record("expected the deadline to win, got \(outcome)"); return }
        #expect(waited < .milliseconds(800), "returned \(waited) after a 200 ms deadline")
    }

    @Test func theDeadlineKeepsWorkThatFinishes() async {
        let outcome = await Deadline.race(.seconds(2)) { () -> String in "read" }
        guard case .finished(let value) = outcome else { Issue.record("expected the work to finish first"); return }
        #expect(value == "read")
    }

    /// A thread held without regard for cancellation.
    private static func block(_ seconds: TimeInterval) { Thread.sleep(forTimeInterval: seconds) }
}
