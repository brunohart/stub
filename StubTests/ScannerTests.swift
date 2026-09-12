import Testing
import Foundation
@testable import Stub

/// The camera path without a camera: the live scanner's lines are put in reading order and handed to the
/// same parsers a photograph goes through (Day 6). The ordering and the hand-off are what can be proved here.
struct ScannerTests {
    typealias Line = StubScanner.Line

    @Test func linesAreReadTopToBottomThenLeftToRight() {
        // The scanner noticed the seat first, the venue last; the ticket prints them the other way round.
        let seen = [
            Line(text: "SEAT H12", top: 300, left: 40),
            Line(text: "THE BRUTALIST", top: 120, left: 40),
            Line(text: "SCREEN 1", top: 302, left: 260),
            Line(text: "EMBASSY THEATRE", top: 40, left: 40),
            Line(text: "Sat 6 Sep 2026 7:30PM", top: 200, left: 40),
        ]
        #expect(StubScanner.ordered(seen) == ["EMBASSY THEATRE", "THE BRUTALIST", "Sat 6 Sep 2026 7:30PM", "SEAT H12", "SCREEN 1"])
    }

    @Test func repeatsAndBlanksAreDropped() {
        let seen = [
            Line(text: "  ", top: 10, left: 0),
            Line(text: "PERFECT DAYS", top: 20, left: 0),
            Line(text: "PERFECT DAYS", top: 21, left: 0),   // lost and found again
            Line(text: "F7", top: 80, left: 0),
        ]
        #expect(StubScanner.ordered(seen) == ["PERFECT DAYS", "F7"])
    }

    @Test func scannedLinesReachTheHeuristicParser() async {
        let reading = StubReading(lines: ["EMBASSY THEATRE", "THE BRUTALIST", "Sat 6 Sep 2026 7:30PM", "SCREEN 1", "SEAT H12", "ADULT $18.50"])
        var stages: [StubReader.Stage] = []
        let draft = await StubReader.understand(reading, using: HeuristicParser(), progress: { stage in
            stages.append(stage)
        })
        #expect(draft.title == "The Brutalist")
        #expect(draft.cinema == "Embassy Theatre")
        #expect(draft.seat == "H12")
        #expect(draft.readBy == "heuristic")
        #expect(stages == [.understanding(parser: "heuristic"), .done], "no cropping and no Vision on the camera path")
    }

    @Test func aStubSaysWhatItKnowsWhenReadAloud() {
        let when = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 6, hour: 19, minute: 30))!
        let full = Stub(title: "The Brutalist", cinema: "Embassy Theatre", screenedAt: when, seat: "H12")
        #expect(full.spokenLabel == "The Brutalist, 6 September 2026, Embassy Theatre, seat H12")
        let bare = Stub(title: "Past Lives")
        #expect(bare.spokenLabel == "Past Lives")
        #expect(full.spokenDate?.contains("SEP") == false, "the printed date is uppercase and abbreviated; the spoken one is not")
    }
}
