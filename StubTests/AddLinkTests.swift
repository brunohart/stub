import Testing
import Foundation
@testable import Stub

/// Add to Stub (BEDIP-220, ADR-021): the link's fields, read exactly, and bad input refused field by field rather than
/// guessed at.
struct AddLinkTests {
    private let auckland = TimeZone(identifier: "Pacific/Auckland")!
    private let newYork = TimeZone(identifier: "America/New_York")!

    private func read(_ link: String, in zone: TimeZone? = nil) throws -> AddLink.Handed {
        let url = try #require(URL(string: link))
        return try #require(AddLink.read(url, timeZone: zone ?? auckland))
    }

    private func utc(_ iso: String) -> Date { try! Date(iso, strategy: .iso8601) }

    @Test func theSpecsExampleReadsWhole() throws {
        let handed = try read("https://designedbybruno.net/stub/add#title=La%20Chimera&cinema=Academy%20Cinemas&at=2026-10-18T19:30%2B13:00&screen=2&seat=F7&price=19.50&currency=nzd&ref=AC-55120")
        let d = handed.draft
        #expect(d.title == "La Chimera")
        #expect(d.cinema == "Academy Cinemas")
        #expect(d.screenedAt == utc("2026-10-18T06:30:00Z"))
        #expect(d.screen == "2")
        #expect(d.seat == "F7")
        #expect(d.price == Decimal(string: "19.50"))
        #expect(d.currency == "NZD")
        #expect(d.readBy == "link" && d.confidence == 1)
        #expect(handed.unread.isEmpty)
        // The reference is kept where the person can see it, and printed nowhere else.
        #expect(handed.raw.contains("ref: AC-55120"))
        #expect(handed.raw.contains("at: 2026-10-18T19:30:00+13:00"))
    }

    /// The issue's form, with the fields in the query and the offset's `+` not encoded.
    @Test func theQueryWorksToo() throws {
        let d = try read("https://designedbybruno.net/stub/add?title=La%20Chimera&cinema=Academy%20Cinemas&at=2026-10-18T19:30+13:00&screen=2&seat=F7").draft
        #expect(d.title == "La Chimera")
        #expect(d.screenedAt == utc("2026-10-18T06:30:00Z"))
    }

    @Test func theFragmentWinsOverTheQuery() throws {
        let d = try read("https://designedbybruno.net/stub/add?title=Old&seat=A1#title=New").draft
        #expect(d.title == "New")
        #expect(d.seat == "A1")
    }

    /// `+` is a space in words (as a form encodes it) and `%2B` is a plus; in `at` a `+` is the offset's sign.
    @Test func plusIsASpaceInWordsAndASignInTime() throws {
        #expect(try read("https://designedbybruno.net/stub/add#title=Past+Lives").draft.title == "Past Lives")
        #expect(try read("https://designedbybruno.net/stub/add#title=Romeo%20%2B%20Juliet").draft.title == "Romeo + Juliet")
        // A space where the sign should be: a `+` that something form-decoded on the way.
        #expect(try read("https://designedbybruno.net/stub/add#title=x&at=2026-10-18T19:30%2013:00").draft.screenedAt == utc("2026-10-18T06:30:00Z"))
    }

    @Test(arguments: [
        ("2026-10-18T19:30+13:00", "2026-10-18T06:30:00Z"),
        ("2026-10-18T19:30+1300", "2026-10-18T06:30:00Z"),
        ("2026-10-18T06:30Z", "2026-10-18T06:30:00Z"),
        ("2026-10-18T06:30:00Z", "2026-10-18T06:30:00Z"),
        ("2026-10-18T06:30:00.250Z", "2026-10-18T06:30:00Z"),
        ("2026-10-18 19:30+13:00", "2026-10-18T06:30:00Z"),
        ("2026-03-24T20:30+01:00", "2026-03-24T19:30:00Z"),
        ("2026-10-18T09:30-04:00", "2026-10-18T13:30:00Z"),
        ("2026-10-18T19:30+05:45", "2026-10-18T13:45:00Z"),
    ])
    func offsetsAreExact(at: String, expected: String) throws {
        let encoded = at.replacingOccurrences(of: "+", with: "%2B").replacingOccurrences(of: " ", with: "%20")
        let handed = try read("https://designedbybruno.net/stub/add#title=x&at=\(encoded)")
        #expect(handed.draft.screenedAt == utc(expected), "\(at)")
        #expect(handed.unread.isEmpty)
    }

    /// Without an offset the time is the phone's, the best guess at the cinema's; a date alone is midnight there, which the
    /// card prints as a date without a time.
    @Test func noOffsetIsThePhonesTime() throws {
        let local = try read("https://designedbybruno.net/stub/add#title=x&at=2026-10-18T19:30", in: newYork).draft
        #expect(local.screenedAt == utc("2026-10-18T23:30:00Z"))
        let dateOnly = try read("https://designedbybruno.net/stub/add#title=x&at=2026-10-18", in: auckland)
        #expect(dateOnly.draft.screenedAt == utc("2026-10-17T11:00:00Z"))
        #expect(dateOnly.raw.contains("at: 2026-10-18\n") || dateOnly.raw.hasSuffix("at: 2026-10-18"))
        // Across the change to daylight time in Auckland (27 September 2026): the offset is the one that day had.
        let spring = try read("https://designedbybruno.net/stub/add#title=x&at=2026-09-26T19:30", in: auckland).draft
        let summer = try read("https://designedbybruno.net/stub/add#title=x&at=2026-09-28T19:30", in: auckland).draft
        #expect(spring.screenedAt == utc("2026-09-26T07:30:00Z"))
        #expect(summer.screenedAt == utc("2026-09-28T06:30:00Z"))
    }

    @Test(arguments: ["2026-02-30T19:30", "2026-13-01", "2026-10-18T24:30", "2026-10-18T19:61", "tomorrow", "18/10/2026",
                      "1066-10-14", "2026-10-18T19:30+15:00", "2026-10-18T19:30+13", ""])
    func aDateThatIsNotADateIsLeftOut(at: String) throws {
        let handed = try read("https://designedbybruno.net/stub/add#title=La%20Chimera&seat=F7&at=\(at.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? at)")
        #expect(handed.draft.screenedAt == nil, "\(at)")
        #expect(handed.draft.title == "La Chimera" && handed.draft.seat == "F7", "the other fields stay")
        #expect(handed.unread == (at.isEmpty ? [] : ["at=\(at)"]))
    }

    @Test func priceAndCurrencyAreNumbersAndCodes() throws {
        let symbol = try read("https://designedbybruno.net/stub/add#title=x&price=%E2%82%AC12.50&currency=euros")
        #expect(symbol.draft.price == nil && symbol.draft.currency == "")
        #expect(symbol.unread == ["price=€12.50", "currency=euros"])
        let negative = try read("https://designedbybruno.net/stub/add#title=x&price=-3")
        #expect(negative.draft.price == nil)
        let plain = try read("https://designedbybruno.net/stub/add#title=x&price=18&currency=AUD").draft
        #expect(plain.price == 18 && plain.currency == "AUD")
        // A currency with no price is nothing to print.
        #expect(try read("https://designedbybruno.net/stub/add#title=x&currency=AUD").draft.currency == "")
    }

    @Test func wordsAreCleanedAndCut() throws {
        let long = String(repeating: "Very Long Title ", count: 40)
        let handed = try read("https://designedbybruno.net/stub/add#title=\(long.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!)&cinema=%20Academy%0A%0ACinemas%09&seat=%00F7")
        #expect(handed.draft.title.count == AddLink.longest)
        #expect(handed.draft.cinema == "Academy Cinemas")
        #expect(handed.draft.seat == "F7")
        #expect(!handed.raw.contains("\u{0}"))
    }

    /// A link with no title still opens the sheet with what it has; Keep waits for a title, as it does for a photograph.
    @Test func noTitleIsNotYetUsable() throws {
        let handed = try read("https://designedbybruno.net/stub/add#cinema=Academy%20Cinemas&seat=F7&unknown=1")
        #expect(!handed.draft.isUsable)
        #expect(handed.draft.cinema == "Academy Cinemas")
        #expect(!handed.raw.contains("unknown"))
    }

    @Test(arguments: [
        "http://designedbybruno.net/stub/add#title=x",
        "https://designedbybruno.net.evil.example/stub/add#title=x",
        "https://example.com/stub/add#title=x",
        "https://designedbybruno.net/stub/added#title=x",
        "https://designedbybruno.net/stub#title=x",
        "stub://add?title=x",
    ])
    func onlyTheDoorOpensTheDoor(link: String) throws {
        let url = try #require(URL(string: link))
        #expect(AddLink.read(url) == nil, "\(link)")
    }

    @Test func theDoorAcceptsWwwAndATrailingSlash() throws {
        #expect(AddLink.matches(URL(string: "https://www.designedbybruno.net/stub/add/#title=x")!))
        #expect(AddLink.matches(URL(string: "https://DesignedByBruno.net/stub/add")!))
    }

    /// The intent's fields go through the same cleaning and come out the same shape, read by a shortcut.
    @Test func theIntentIsTheSameDoor() throws {
        let at = utc("2026-10-18T06:30:00Z")
        let content = AddStubIntent.handed(film: "  La   Chimera ", cinema: "Academy Cinemas", screening: at, screen: "2",
                                           seat: "F7", price: 19.5, currency: "nzd", reference: "AC-55120")
        guard case .known(let draft, let raw, let plate) = content else { Issue.record("not known"); return }
        #expect(draft.title == "La Chimera" && draft.screenedAt == at && draft.price == Decimal(string: "19.50"))
        #expect(draft.currency == "NZD" && draft.readBy == "shortcut" && plate == nil)
        #expect(raw.contains("ref: AC-55120"))
    }
}
