import Testing
import Foundation
@testable import Stub

struct HeuristicParserTests {
    @Test func readsAnEmbassyStub() {
        let reading = StubReading(lines: [
            "EMBASSY THEATRE",
            "THE BRUTALIST",
            "Sat 6 Sep 2026 7:30PM",
            "SCREEN 1",
            "SEAT H12",
            "ADULT $18.50",
            "Booking ref 8X2K9",
        ])
        let d = HeuristicParser.parse(reading)
        #expect(d.title == "The Brutalist")
        #expect(d.cinema == "Embassy Theatre")
        #expect(d.screen == "Screen 1")
        #expect(d.seat == "H12")
        #expect(d.price == Decimal(string: "18.50"))
        #expect(d.currency == "NZD")
        #expect(d.screenedAt != nil)
        #expect(d.confidence >= 0.9)
    }

    @Test func stripsFormatSuffixes() {
        #expect(HeuristicParser.stripFormats("DUNE PART TWO IMAX") == "DUNE PART TWO")
        #expect(HeuristicParser.stripFormats("Perfect Days (M)") == "Perfect Days")
    }

    @Test func findsLoneSeat() {
        let d = HeuristicParser.parse(StubReading(lines: ["LIGHTHOUSE CINEMA", "PAST LIVES", "F7", "12/03/2024 18:15"]))
        #expect(d.seat == "F7")
        #expect(d.title == "Past Lives")
        #expect(d.screenedAt != nil)
    }

    @Test func numericDateWithTime() {
        let date = HeuristicParser.date(in: "DATE 12/03/2024 18:15")
        #expect(date != nil)
        let comps = Calendar.current.dateComponents([.day, .month, .year, .hour], from: date!)
        #expect(comps.day == 12 && comps.month == 3 && comps.year == 2024 && comps.hour == 18)
    }

    @Test func emptyReadingIsNotUsable() {
        let d = HeuristicParser.parse(StubReading(lines: ["$12.00", "ADMIT ONE"]))
        #expect(!d.isUsable)
    }
}
