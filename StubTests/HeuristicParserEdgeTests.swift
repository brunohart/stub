import Testing
import Foundation
@testable import Stub

/// Day 1 edge cases: the folklore that the first four fixtures did not exercise.
struct HeuristicParserEdgeTests {
    @Test func priceWithComma() {
        let p = HeuristicParser.price(in: "ADULT €12,50")
        #expect(p?.amount == Decimal(string: "12.50"))
        #expect(p?.currency == "EUR")
    }

    @Test func priceWithTrailingEuro() {
        let p = HeuristicParser.price(in: "Preis 9,00 €")
        #expect(p?.amount == Decimal(string: "9.00"))
        #expect(p?.currency == "EUR")
    }

    @Test func priceWithIsoCode() {
        let p = HeuristicParser.price(in: "TOTAL GBP 14.00")
        #expect(p?.amount == Decimal(string: "14.00"))
        #expect(p?.currency == "GBP")
    }

    @Test func rowAndSeatOnOneLine() {
        #expect(HeuristicParser.seat(in: "Row H Seat 12") == "H12")
        #expect(HeuristicParser.seat(in: "ROW: K, SEAT: 9") == "K9")
        #expect(HeuristicParser.seat(in: "Seat: F-7") == "F7")
        #expect(HeuristicParser.seat(in: "ADMIT ONE") == nil)
    }

    @Test func rowAndSeatClaimsTheLine() {
        let d = HeuristicParser.parse(StubReading(lines: ["THE ROXY CINEMA", "PERFECT DAYS", "Row H Seat 12", "12/03/2024 18:15"]))
        #expect(d.seat == "H12")
        #expect(d.title == "Perfect Days")
    }

    @Test func dateWithoutYearTakesThisYearWhenPast() {
        let cal = Calendar.current
        let now = cal.date(from: DateComponents(year: 2026, month: 9, day: 7, hour: 12))!
        let d = HeuristicParser.date(in: "Sat 6 Sep 7:30PM", now: now)
        #expect(d != nil)
        let c = cal.dateComponents([.year, .month, .day, .hour, .minute], from: d!)
        #expect(c.year == 2026 && c.month == 9 && c.day == 6 && c.hour == 19 && c.minute == 30)
    }

    @Test func dateWithoutYearRollsBackWhenFuture() {
        let cal = Calendar.current
        let now = cal.date(from: DateComponents(year: 2026, month: 9, day: 7, hour: 12))!
        let d = HeuristicParser.date(in: "14 Dec 20:45", now: now)
        #expect(d != nil)
        let c = cal.dateComponents([.year, .month, .day, .hour], from: d!)
        #expect(c.year == 2025 && c.month == 12 && c.day == 14 && c.hour == 20)
    }

    @Test func europeanDottedDate() {
        let d = HeuristicParser.date(in: "12.03.2024 18:15")
        #expect(d != nil)
        let c = Calendar.current.dateComponents([.year, .month, .day], from: d!)
        #expect(c.year == 2024 && c.month == 3 && c.day == 12)
    }

    @Test func fullYearStillWinsOverYearless() {
        let d = HeuristicParser.date(in: "Sat 6 Sep 2026 7:30PM")
        #expect(Calendar.current.component(.year, from: d!) == 2026)
    }

    // Day 3: the four harder fixtures.

    @Test func frenchAndGermanSeats() {
        #expect(HeuristicParser.seat(in: "RANG F PLACE 12") == "F12")
        #expect(HeuristicParser.seat(in: "Reihe H Platz 3") == "H3")
        #expect(HeuristicParser.seat(in: "Siège: K9") == "K9")
        #expect(HeuristicParser.seat(in: "FILA C ASIENTO 14") == "C14")
    }

    @Test func europeanScreenWords() {
        let d = HeuristicParser.parse(StubReading(lines: ["CINÉMA DU PANTHÉON", "LA CHIMERA", "24.03.2024 20:30", "SALLE 2", "RANG F PLACE 12", "TARIF PLEIN 12,50 €", "Billet n° 4471"]))
        #expect(d.title == "La Chimera")
        #expect(d.cinema == "Cinéma du Panthéon")
        #expect(d.screen == "Screen 2")
        #expect(d.seat == "F12")
        #expect(d.price == Decimal(string: "12.50"))
        #expect(d.currency == "EUR")
        #expect(d.screenedAt != nil)
    }

    @Test func accentedVenueIsStillAVenue() {
        #expect(HeuristicParser.looksLikeVenue("CINÉMA DU PANTHÉON".folding(options: .diacriticInsensitive, locale: nil)))
        #expect(HeuristicParser.titleCase("CINÉMA DU PANTHÉON") == "Cinéma du Panthéon")
    }

    @Test func addressLineIsNotATitle() {
        let d = HeuristicParser.parse(StubReading(lines: [
            "ACADEMY CINEMAS", "44 LORNE ST AUCKLAND", "--------------------", "ANORA",
            "Wed 19 Feb 2025 8:15PM", "CINEMA 2   SEAT C8", "ADULT        $19.00", "GST INCL      $2.48",
            "TOTAL        $19.00", "TRANS 004512", "ADMIT ONE",
        ]))
        #expect(d.title == "Anora")
        #expect(d.cinema == "Academy Cinemas")
        #expect(d.screen == "Screen 2")
        #expect(d.seat == "C8")
        #expect(d.price == Decimal(string: "19.00"))
    }

    @Test func numberedTitlesAreNotAddresses() {
        let d = HeuristicParser.parse(StubReading(lines: ["EMBASSY THEATRE", "12 ANGRY MEN", "SEAT B2", "$12.00"]))
        #expect(d.title == "12 Angry Men")
    }

    /// The tickets that never had paper (BEDIP-218): an e-ticket's dates with the weekday and the month in full and a comma,
    /// an app's with a middle dot and a spaced "pm", and the small print that is longer than the title.
    @Test func digitalTicketsDatesAndSmallPrint() {
        let calendar = Calendar.current
        func parts(_ d: Date?) -> DateComponents? { d.map { calendar.dateComponents([.year, .month, .day, .hour, .minute], from: $0) } }
        let pdf = parts(HeuristicParser.date(in: "Friday 11 April 2025, 7:00 pm"))
        #expect(pdf?.year == 2025 && pdf?.month == 4 && pdf?.day == 11 && pdf?.hour == 19 && pdf?.minute == 0)
        let app = parts(HeuristicParser.date(in: "Sun 26 Jan 2025 · 5:30 pm"))
        #expect(app?.year == 2025 && app?.month == 1 && app?.day == 26 && app?.hour == 17 && app?.minute == 30)
        let dotted = parts(HeuristicParser.date(in: "Sat 8 Mar 2025, 8.15 p.m."))
        #expect(dotted == nil || dotted?.day == 8, "a time it cannot read is no date rather than a wrong one")
        let page = HeuristicParser.parse(StubReading(lines: [
            "LIGHTHOUSE CINEMA PETONE", "Your e-ticket", "ALL WE IMAGINE AS LIGHT", "Friday 11 April 2025, 7:00 pm",
            "Cinema 1 Seat D9", "Adult $18.00", "Booking LH-20871", "Please arrive 10 minutes before the session.",
            "This ticket admits one. Show it on your phone or printed.", "Lighthouse Cinema, 52 Beach Street, Petone.",
        ]))
        #expect(page.title == "All We Imagine as Light")
        #expect(page.seat == "D9" && page.screen == "Screen 1")
    }
}
