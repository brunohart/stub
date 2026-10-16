import Testing
import Foundation
@testable import Stub

/// A ticket's shape leaves; nothing it says does (docs/decisions/006-network-without-data.md).
struct TicketFormatTests {
    private let reading = StubReading(lines: [
        "THE KINGSWAY PICTURE HOUSE",
        "A Quiet Harbour",
        "Sat 6 Sep 2026 7:30PM",
        "SCREEN 2   SEAT H12",
        "ADULT $18.50",
        "Booking ref 8X2K9",
        "Customer: Jane Ngata",
    ])
    private let kept = StubDraft(title: "A Quiet Harbour", cinema: "The Kingsway Picture House", screen: "Screen 2", seat: "H12",
                                 price: Decimal(string: "18.50"), currency: "NZD")

    @Test func theShapeKeepsTheLabelsAndTheFields() {
        let shape = TicketFormat.of(reading, kept: kept)
        #expect(shape.lines[0] == "{cinema}")
        #expect(shape.lines[1] == "{title}")
        #expect(shape.text.contains("SCREEN {screen}"))
        #expect(shape.text.contains("SEAT {seat}"))
        #expect(shape.text.contains("ADULT"))
    }

    @Test func nothingTheTicketSaysLeaves() {
        let text = TicketFormat.of(reading, kept: kept).text
        for secret in ["Quiet", "Harbour", "Kingsway", "H12", "18.50", "8X2K9", "Jane", "Ngata", "2026", "7:30"] {
            #expect(!text.contains(secret), "\(secret) left in the shape")
        }
    }
}
