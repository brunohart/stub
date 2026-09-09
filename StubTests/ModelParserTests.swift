import Testing
import Foundation
@testable import Stub

/// What happens to the model's answer after it arrives. No model needed: these are the shapes the drawer files.
struct ModelParserTests {
    @Test func datesAreWallClockNotUTC() throws {
        let d = try #require(ModelParser.wallClock("2024-03-12T18:15:00Z"))
        let c = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: d)
        #expect(c.year == 2024 && c.month == 3 && c.day == 12 && c.hour == 18 && c.minute == 15)

        let offset = try #require(ModelParser.wallClock("2026-09-06T19:30:00+12:00"))
        #expect(Calendar.current.component(.hour, from: offset) == 19)

        let dateOnly = try #require(ModelParser.wallClock("2026-09-06"))
        #expect(Calendar.current.component(.hour, from: dateOnly) == 0)
        #expect(ModelParser.wallClock("") == nil)
        #expect(ModelParser.wallClock("not a date") == nil)
    }

    @Test func screensAndSeatsTakeTheDrawersShape() {
        #expect(ModelParser.normalisedScreen("SCR 2") == "Screen 2")
        #expect(ModelParser.normalisedScreen("Cinema 3") == "Screen 3")
        #expect(ModelParser.normalisedScreen("Salle 2") == "Screen 2")
        #expect(ModelParser.normalisedScreen("4") == "Screen 4")
        #expect(ModelParser.normalisedScreen("The Grand") == "The Grand")
        #expect(ModelParser.normalisedScreen("") == "")

        #expect(ModelParser.normalisedSeat("SEAT D 4") == "D4")
        #expect(ModelParser.normalisedSeat("RANG F PLACE 12") == "F12")
        #expect(ModelParser.normalisedSeat("h12") == "H12")
        #expect(ModelParser.normalisedSeat("K-9") == "K9")
        #expect(ModelParser.normalisedSeat("") == "")
    }

    @Test func draftStripsFormatsAndReadsCommaPrices() {
        let d = ModelParser.draft(title: "Dune Part Two IMAX", cinema: " The Roxy Cinema ", screenedAt: "2024-03-14T20:45:00Z",
                                  screen: "SCR 2", seat: "SEAT D 4", price: "12,50", currency: "eur")
        #expect(d.title == "Dune Part Two")
        #expect(d.cinema == "The Roxy Cinema")
        #expect(d.screen == "Screen 2")
        #expect(d.seat == "D4")
        #expect(d.price == Decimal(string: "12.50"))
        #expect(d.currency == "EUR")
        #expect(d.readBy == "foundation-models")
        #expect(d.confidence == 1.0)
    }

    @Test func promptCarriesTheHint() {
        var hint = StubDraft()
        hint.title = "Past Lives"; hint.seat = "K9"
        let reading = StubReading(lines: ["PENTHOUSE CINEMA", "PAST LIVES"])
        let cold = ModelParser.prompt(reading, hint: nil)
        let warm = ModelParser.prompt(reading, hint: hint)
        #expect(!cold.contains("First pass"))
        #expect(warm.contains("First pass") && warm.contains("title: Past Lives") && warm.contains("seat: K9"))
        var empty = StubDraft()
        empty.seat = "K9"
        #expect(!ModelParser.prompt(reading, hint: empty).contains("First pass"), "a hint with no title is no hint")
    }
}
