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

    @Test func hintKeepsTheRowTheModelDropped() {
        var hint = StubDraft()
        hint.title = "La Chimera"; hint.seat = "F12"
        // Day 4: the model read "PLACE 12" off the French stub with the hint saying F12, and the drawer filed "PLACE 12".
        #expect(ModelParser.draft(title: "La Chimera", cinema: "", screenedAt: "", screen: "", seat: "PLACE 12", price: "", currency: "", hint: hint).seat == "F12")
        #expect(ModelParser.draft(title: "La Chimera", cinema: "", screenedAt: "", screen: "", seat: "12", price: "", currency: "", hint: hint).seat == "F12")
        // A seat with its row is the model's own, even when it disagrees with the hint.
        #expect(ModelParser.draft(title: "La Chimera", cinema: "", screenedAt: "", screen: "", seat: "G12", price: "", currency: "", hint: hint).seat == "G12")
        // Nothing said is nothing filed: the eval table should see the miss.
        #expect(ModelParser.draft(title: "La Chimera", cinema: "", screenedAt: "", screen: "", seat: "", price: "", currency: "", hint: hint).seat == "")
        // No hint, or a hint with no row of its own, changes nothing.
        #expect(ModelParser.draft(title: "La Chimera", cinema: "", screenedAt: "", screen: "", seat: "PLACE 12", price: "", currency: "").seat == "PLACE 12")
        hint.seat = "12"
        #expect(ModelParser.draft(title: "La Chimera", cinema: "", screenedAt: "", screen: "", seat: "PLACE 12", price: "", currency: "", hint: hint).seat == "PLACE 12")
        #expect(ModelParser.hasRow("H12") && ModelParser.hasRow("AA3") && !ModelParser.hasRow("PLACE 12") && !ModelParser.hasRow("12") && !ModelParser.hasRow(""))
    }

    @Test func hintKeepsTheTitleTheModelMisspelt() {
        var hint = StubDraft()
        hint.title = "Aftersun"
        // Days 5, 28 and 30: the hinted model wrote "Aftrsun" off the low-contrast stub, with "Aftersun" in its hint.
        #expect(ModelParser.draft(title: "Aftrsun", cinema: "", screenedAt: "", screen: "", seat: "", price: "", currency: "", hint: hint).title == "Aftersun")
        #expect(ModelParser.draft(title: "Aftersum", cinema: "", screenedAt: "", screen: "", seat: "", price: "", currency: "", hint: hint).title == "Aftersun")
        #expect(ModelParser.draft(title: "Afftersun", cinema: "", screenedAt: "", screen: "", seat: "", price: "", currency: "", hint: hint).title == "Aftersun")
        // Two letters away is a different reading, and the model's own; so is a title with no hint.
        #expect(ModelParser.draft(title: "Aftrsn", cinema: "", screenedAt: "", screen: "", seat: "", price: "", currency: "", hint: hint).title == "Aftrsn")
        #expect(ModelParser.draft(title: "Aftrsun", cinema: "", screenedAt: "", screen: "", seat: "", price: "", currency: "").title == "Aftrsun")
        // Casing and accents are not letters: the model's accent stays the model's.
        hint.title = "La Chimera"
        #expect(ModelParser.draft(title: "La Chiméra", cinema: "", screenedAt: "", screen: "", seat: "", price: "", currency: "", hint: hint).title == "La Chiméra")
        #expect(!ModelParser.oneEditApart("Dune Part Two", "DUNE PART TWO"))
        #expect(ModelParser.oneEditApart("Past Lives", "Past Live") && ModelParser.oneEditApart("Anora", "Anura"))
        #expect(!ModelParser.oneEditApart("", "Anora") && !ModelParser.oneEditApart("Up", "Us Two"))
        // A title not yet streamed is not one letter from a one-letter hint.
        #expect(!ModelParser.oneEditApart("", "M"))
    }

    @Test func hintShapesTheScreenTheNormaliserCouldNot() {
        var hint = StubDraft()
        hint.title = "La Chimera"; hint.screen = "Screen 2"
        func screen(_ raw: String, _ hint: StubDraft?) -> String {
            ModelParser.draft(title: "La Chimera", cinema: "", screenedAt: "", screen: raw, seat: "", price: "", currency: "", hint: hint).screen
        }
        // Days 5 and 30: the hinted model wrote "Salée 2" for SALLE 2, and the hint said Screen 2.
        #expect(screen("Salée 2", hint) == "Screen 2")
        // Another number, or none, is the model's own reading; so is an unshaped screen with no hint.
        #expect(screen("Salée 3", hint) == "Salée 3")
        #expect(screen("IMAX", hint) == "IMAX")
        #expect(screen("", hint) == "")
        #expect(screen("Salée 2", nil) == "Salée 2")
        // A screen the normaliser shapes is never second-guessed.
        #expect(screen("SALLE 4", hint) == "Screen 4")
    }

    /// Days 4 and 5: a probe that timed out locked the session to heuristics until the next launch. A cold model on
    /// a phone can take that long for its first answer; slow is not broken.
    @available(iOS 26.0, *)
    @Test func aSlowProbeStillLetsTheModelRead() {
        #expect(ModelProbe.Outcome.slow("timeout").allowsModel)
        #expect(ModelProbe.Outcome.slow("timeout").statusLine.contains("asking it anyway"))
        #expect(!ModelProbe.Outcome.failed("1026").allowsModel)
        #expect(!ModelProbe.Outcome.unavailable("off").allowsModel)
    }

    @Test func shoutedAnswersGetTheHeuristicsCasing() {
        // Day 4: "AFTERSUN" and "RIALTO CINEMAS NEWMARKET" came back in capitals on one run.
        let d = ModelParser.draft(title: "AFTERSUN", cinema: "RIALTO CINEMAS NEWMARKET", screenedAt: "", screen: "", seat: "", price: "", currency: "")
        #expect(d.title == "Aftersun" && d.cinema == "Rialto Cinemas Newmarket")
        // A cased answer is the model's choice and is left alone; so is a title with no letters to case.
        #expect(ModelParser.cased("Cinéma du Panthéon") == "Cinéma du Panthéon")
        #expect(ModelParser.cased("Dune Part Two") == "Dune Part Two")
        #expect(ModelParser.cased("THE ROXY CINEMA") == "The Roxy Cinema")
        #expect(ModelParser.cased("1917") == "1917")
        #expect(ModelParser.cased("  ") == "")
    }

    @Test func promptCarriesTheHint() {
        var hint = StubDraft()
        hint.title = "Past Lives"; hint.seat = "K9"
        let reading = StubReading(lines: ["PENTHOUSE CINEMA", "PAST LIVES"])
        let cold = ModelParser.prompt(reading, hint: nil)
        let warm = ModelParser.prompt(reading, hint: hint)
        #expect(!cold.contains("First pass"))
        #expect(warm.contains("First pass") && warm.contains("title: Past Lives") && warm.contains("seat: K9"))
        // A bare $ is NZD, as the heuristic files it; only the cold prompt needs telling (2026-09-30).
        #expect(cold.hasSuffix(ModelParser.bareDollar) && !warm.contains(ModelParser.bareDollar))
        var empty = StubDraft()
        empty.seat = "K9"
        #expect(!ModelParser.prompt(reading, hint: empty).contains("First pass"), "a hint with no title is no hint")
    }
}
