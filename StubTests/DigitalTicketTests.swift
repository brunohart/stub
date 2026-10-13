import Testing
import Foundation
import CoreGraphics
@testable import Stub

/// The tickets that never had paper (BEDIP-218, ADR-023): a Wallet pass read from its own fields, a PDF's first page and a
/// screenshot read as a photograph is, all handed over through the inbox. The passes in `fixtures/passes` are synthetic,
/// three shapes of Apple's pass format (`scripts/make-digital.swift`).
@MainActor
struct DigitalTicketTests {
    private func fixture(_ path: String) throws -> Data {
        try Data(contentsOf: EvalTests.repoRoot.appending(path: "fixtures/\(path)"))
    }

    private func utc(_ iso: String) -> Date { try! Date(iso, strategy: .iso8601) }

    // MARK: The zip

    @Test func aPassIsAZipWithPassJSONInIt() throws {
        let zip = try Zip(try fixture("passes/semantic-event.pkpass"))
        #expect(Set(zip.names).isSuperset(of: ["pass.json", "strip.png", "strip@2x.png", "manifest.json"]))
        let json = try #require(try zip.read("pass.json"))
        #expect(String(decoding: json, as: UTF8.self).contains("Conclave"))
        #expect(try zip.read("nothing.png") == nil)
    }

    /// A file that is not a zip, a zip cut short and a zip that claims an entry larger than any pass are all refused before
    /// anything is allocated for them.
    @Test func aHostileZipIsRefused() throws {
        #expect(throws: Zip.Failure.notAZip) { try Zip(Data(repeating: 0x41, count: 4000)) }
        var pass = try fixture("passes/french-strings.pkpass")
        #expect(throws: (any Error).self) { try Zip(pass.prefix(pass.count / 2)).read("pass.json") }
        // Find pass.json's central-directory entry and claim it inflates to 100 MB.
        let name = Data("pass.json".utf8)
        var at = pass.count - 22
        while at > 0, !(pass[at] == 0x50 && pass[at + 1] == 0x4b && pass[at + 2] == 0x01 && pass[at + 3] == 0x02
                        && pass.subdata(in: (at + 46)..<(at + 46 + name.count)) == name) { at -= 1 }
        #expect(at > 0, "no central-directory entry for pass.json")
        let huge = UInt32(100 << 20)
        for i in 0..<4 { pass[at + 24 + i] = UInt8((huge >> (8 * UInt32(i))) & 0xFF) }
        #expect(throws: Zip.Failure.tooLarge) { try Zip(pass) }
        #expect(throws: WalletPass.Failure.notAPass) { try WalletPass(pkpass: Data("not a pass".utf8)) }
    }

    // MARK: The passes

    /// Every fact stated as a semantic tag: read exactly, at full confidence, with the strip as the plate.
    @Test func aSemanticPassIsReadWhole() throws {
        let pass = try WalletPass(pkpass: try fixture("passes/semantic-event.pkpass"))
        #expect(pass.isMovie)
        #expect(pass.ticket.title == "Conclave")
        #expect(pass.ticket.cinema == "Event Cinemas Queen St")
        #expect(pass.ticket.at == utc("2025-01-30T05:40:00Z"))
        #expect(pass.ticket.screen == "Cinema 5")
        #expect(pass.ticket.seat == "H12")
        #expect(pass.ticket.price == Decimal(string: "21.50") && pass.ticket.currency == "NZD")
        #expect(pass.organization == "Event Cinemas")
        #expect(pass.stated == ["title", "cinema", "date", "screen", "seat", "price"])
        let plate = try #require(pass.plate)
        #expect(plate.count > 100_000, "the @2x strip, not the 1x")
        let (draft, raw) = pass.handed(fallback: HeuristicParser.parse(pass.reading))
        #expect(draft.readBy == "wallet-pass" && draft.confidence == 1)
        #expect(raw.contains("MOVIE: Conclave") && raw.contains("ref: EV-55031274"))
    }

    /// No semantic tags: the labels say it. The row and the seat in two fields make one seat; a "Cinema" field holding
    /// "Cinema 4" is the screen, and the building is on the back.
    @Test func aPassOfFieldsIsReadByItsLabels() throws {
        let pass = try WalletPass(pkpass: try fixture("passes/fields-only.pkpass"))
        #expect(pass.ticket.title == "Mickey 17")
        #expect(pass.ticket.cinema == "Hoyts Sylvia Park")
        #expect(pass.ticket.screen == "Cinema 4")
        #expect(pass.ticket.seat == "F7")
        #expect(pass.ticket.at == utc("2025-03-08T07:15:00Z"))
        #expect(pass.ticket.ref == "HY-7781203")
        #expect(pass.plate != nil, "the background stands in for a strip")
        #expect(pass.handed().draft.confidence == 1)
    }

    /// In French, the session a string only a person can read: the time comes from `relevantDate`, the seat from PLACE, the
    /// screen from SALLE, the price from a number with its currency, and the cinema from the issuer.
    @Test func aFrenchPassIsReadToo() throws {
        let pass = try WalletPass(pkpass: try fixture("passes/french-strings.pkpass"))
        #expect(pass.ticket.title == "Anatomie d'une chute")
        #expect(pass.ticket.screen == "Salle 2")
        #expect(pass.ticket.seat == "K14")
        #expect(pass.ticket.at == utc("2024-11-09T19:30:00Z"))
        #expect(pass.ticket.price == Decimal(string: "9.5") && pass.ticket.currency == "EUR")
        #expect(pass.ticket.cinema == "Cinéma Le Champo")
        #expect(!pass.stated.contains("cinema"), "the issuer is a fallback, not a statement")
    }

    /// When a pass leaves a field out, the heuristic parser's reading of the pass's own words fills it, and the stub says it
    /// was less sure.
    @Test func whatAPassLeavesOutTheHeuristicMayFill() throws {
        var pass = WalletPass()
        pass.ticket.title = "Perfect Days"
        pass.lines = ["Perfect Days", "Seat F7", "Screen 3"]
        var fallback = StubDraft()
        fallback.seat = "F7"
        let (draft, _) = pass.handed(fallback: fallback)
        #expect(draft.seat == "F7")
        #expect(draft.confidence == 0.8)
    }

    // MARK: The inbox and the app

    @Test func theInboxGivesBackWhatWasPutIn() throws {
        let container = FileManager.default.temporaryDirectory.appending(path: "inbox-\(UUID().uuidString)")
        let pdf = EvalTests.repoRoot.appending(path: "fixtures/stub-10-eticket.pdf")
        let pass = EvalTests.repoRoot.appending(path: "fixtures/passes/fields-only.pkpass")
        let first = try Inbox.put(pass, kind: .pass, in: container, at: Date(timeIntervalSince1970: 1))
        _ = try Inbox.put(pdf, kind: .pdf, in: container, at: Date(timeIntervalSince1970: 2))
        let items = Inbox.items(in: container)
        #expect(items.map(\.kind) == [.pass, .pdf], "oldest first")
        #expect(Inbox.take(first, in: container) == (try Data(contentsOf: pass)))
        #expect(Inbox.items(in: container).map(\.kind) == [.pdf], "taken out, nothing left behind")
        #expect(throws: Inbox.Failure.noGroup) { try Inbox.put(pdf, kind: .pdf, in: nil) }
        try? FileManager.default.removeItem(at: container)
    }

    /// A booking system's PDF is set in real type: its words come out as written, in reading order.
    @Test func aPDFIsReadFromItsOwnText() throws {
        let lines = PageImage.text(of: try fixture("stub-10-eticket.pdf"))
        #expect(lines.first == "LIGHTHOUSE CINEMA PETONE")
        #expect(lines.contains("Friday 11 April 2025, 7:00 pm") && lines.contains { $0.contains("Seat D9") })
        #expect(PageImage.text(of: Data("not a pdf".utf8)).isEmpty)
    }

    @Test func aPDFsFirstPageIsDrawnOnWhite() throws {
        let page = try #require(PageImage.firstPage(of: try fixture("stub-10-eticket.pdf")))
        #expect(page.width == 1190 && page.height == 1684, "A4 at two pixels a point: \(page.width)×\(page.height)")
        let pixels = Pixels(page)
        let corner = pixels.rgba(10, 10)
        #expect(corner.0 > 0.98 && corner.1 > 0.98 && corner.2 > 0.98)
        #expect(PageImage.firstPage(of: Data("%PDF-1.4 nothing".utf8)) == nil)
    }

    /// The app takes the inbox in order: a pass arrives known, with its strip; a PDF arrives as a page to read; a picture as
    /// a screenshot. Nothing is filed: each is an arrival on the import sheet.
    @Test func theAppTurnsTheInboxIntoArrivals() throws {
        let container = FileManager.default.temporaryDirectory.appending(path: "inbox-\(UUID().uuidString)")
        let root = EvalTests.repoRoot.appending(path: "fixtures")
        try Inbox.put(root.appending(path: "passes/semantic-event.pkpass"), kind: .pass, in: container, at: Date(timeIntervalSince1970: 1))
        try Inbox.put(root.appending(path: "stub-10-eticket.pdf"), kind: .pdf, in: container, at: Date(timeIntervalSince1970: 2))
        try Inbox.put(root.appending(path: "stub-11-screenshot.png"), kind: .image, in: container, at: Date(timeIntervalSince1970: 3))
        let reach = Reach()
        reach.drainInbox(in: container)
        let pass = try #require(reach.take()), page = try #require(reach.take()), shot = try #require(reach.take())
        #expect(reach.take() == nil)
        guard case .known(let draft, _, let plate) = pass.content else { Issue.record("the pass is not known"); return }
        #expect(pass.source == .pass && draft.title == "Conclave" && draft.readBy == "wallet-pass" && plate != nil)
        guard case .document(_, let lines) = page.content, case .page(_, false) = shot.content else { Issue.record("pages"); return }
        #expect(lines.contains("ALL WE IMAGINE AS LIGHT"), "the PDF's own text, not OCR")
        #expect(page.source == .pdf && shot.source == .screenshot)
        #expect(Inbox.items(in: container).isEmpty)
        try? FileManager.default.removeItem(at: container)
    }
}
