import Foundation
import SwiftData
import UIKit
import OSLog

#if DEBUG || PERF
/// Staging for the measured runs (docs/decisions/004-budgets.md). The UI and performance tests launch the app with these, in
/// Debug and in the Performance configuration (Release's optimiser with these hooks compiled in); a Release build has none.
///
/// - `-stage-drawer N`: the drawer emptied and filled with N stubs at once, read by nobody. No two are alike (ADR-043): the
///   ten bundled fixtures first, then tickets drawn here for invented films at invented cinemas, each its own night, seat,
///   paper and tilt. Invented, so a screenshot never carries a real film or cinema's name past the fixtures.
/// - `-stage-rules`: the rules read and the hash chooses; the model is never asked. The rule path's budget, and the only
///   path the oldest phones have.
/// - `-stage-tilt`: a hand turning the phone, for the simulator, which has none: the light swept across the card at 60 Hz
///   for four seconds once a stub is open, as one `Tilt` animation interval.
enum Stage {
    static let log = Logger(subsystem: Signposts.subsystem, category: "stage")
    private static let args = ProcessInfo.processInfo.arguments

    static let drawer: Int? = {
        guard let i = args.firstIndex(of: "-stage-drawer"), i + 1 < args.count else { return nil }
        return Int(args[i + 1]).map { max(0, $0) }
    }()
    static var rulesOnly: Bool { args.contains("-stage-rules") }
    static var tilts: Bool { args.contains("-stage-tilt") }

    /// The fixtures' truths (`fixtures/expected.json`), enough to file a stub without reading one.
    private static let truths: [(file: String, title: String, cinema: String, at: String, screen: String, seat: String, price: String, currency: String)] = [
        ("stub-1-the-brutalist.png", "The Brutalist", "Embassy Theatre", "2026-09-06 19:30", "Screen 1", "H12", "18.50", "NZD"),
        ("stub-2-perfect-days.png", "Perfect Days", "Lighthouse Cinema Cuba", "2024-03-12 18:15", "Screen 3", "F7", "15.00", "NZD"),
        ("stub-3-dune-part-two-imax.png", "Dune Part Two", "The Roxy Cinema", "2024-03-14 20:45", "Screen 2", "D4", "21.00", "NZD"),
        ("stub-4-past-lives.png", "Past Lives", "Penthouse Cinema", "2024-02-09 18:00", "Screen 4", "K9", "14.00", "NZD"),
        ("stub-5-rotated.png", "No Other Land", "Event Cinemas Queen St", "2025-03-04 18:45", "Screen 7", "J14", "22.00", "NZD"),
        ("stub-6-low-contrast.png", "Aftersun", "Rialto Cinemas Newmarket", "2024-06-02 16:15", "Screen 3", "E11", "19.50", "NZD"),
        ("stub-7-thermal.png", "Anora", "Academy Cinemas", "2025-02-19 20:15", "Screen 2", "C8", "19.00", "NZD"),
        ("stub-8-european.png", "La Chimera", "Cinéma du Panthéon", "2024-03-24 20:30", "Screen 2", "F12", "12.50", "EUR"),
        ("stub-9-dune-again.png", "Dune Part Two", "The Roxy Cinema", "2024-03-30 13:10", "Screen 1", "G11", "21.00", "NZD"),
        ("stub-11-screenshot.png", "The Room Next Door", "Academy Cinemas", "2025-01-26 17:30", "Screen 1", "G4", "19.00", "NZD"),
    ]

    /// Empty the drawer and file `count` stubs: the fixtures (Dune Part Two among them twice, a release seen more than once,
    /// as a real drawer has), then invented tickets across the years since 2019, every one different.
    @MainActor
    static func fill(_ context: ModelContext, count: Int) {
        try? context.delete(model: Stub.self)
        try? context.delete(model: PressRecord.self)
        try? context.delete(model: StubDrawer.self)
        SeasonCache.clear(); EditionCache.clear(); ProofCache.clear()
        let format = DateFormatter()
        format.locale = Locale(identifier: "en_NZ")
        format.dateFormat = "yyyy-MM-dd HH:mm"
        var photos: [String: Data] = [:]
        for n in 0..<count {
            guard n < truths.count else {
                let made = invented(n - truths.count)
                let place = Venue.resolve(cinema: made.cinema)
                context.insert(Stub(
                    title: made.title, cinema: made.cinema, screenedAt: made.night, screen: made.screen, seat: made.seat,
                    price: made.price, currency: "NZD", rawText: "", imageData: made.photo, readBy: "heuristic", confidence: 1,
                    createdAt: Date(timeIntervalSince1970: 1_700_000_000 + Double(count - n) * 60),
                    venue: place.venue, circuit: place.circuit))
                continue
            }
            let truth = truths[n]
            if photos[truth.file] == nil,
               let url = Bundle.main.url(forResource: truth.file, withExtension: nil),
               let data = try? Data(contentsOf: url),
               let cg = PlateImage.decode(data, maxPixelSize: PlateImage.intake) {
                photos[truth.file] = UIImage(cgImage: cg).jpegData(compressionQuality: 0.82)
            }
            let night = format.date(from: truth.at)
            let place = Venue.resolve(cinema: truth.cinema)
            context.insert(Stub(
                title: truth.title, cinema: truth.cinema, screenedAt: night, screen: truth.screen, seat: truth.seat,
                price: Decimal(string: truth.price), currency: truth.currency, rawText: "", imageData: photos[truth.file],
                readBy: "heuristic", confidence: 1, createdAt: Date(timeIntervalSince1970: 1_700_000_000 + Double(count - n) * 60),
                venue: place.venue, circuit: place.circuit))
        }
        try? context.save()
        log.info("stage: drawer filled with \(count) stubs")
    }

    /// Invented films and cinemas: plausible, and as far as we know nobody's. Past the list's end a film comes back as its
    /// sequel, so even a drawer of hundreds repeats nothing.
    private static let films = [
        "Salt in the Orchard", "A Quiet Arithmetic", "Northbound, Slowly", "The Cartographer's Dog", "Every Small Hour",
        "Glass Harbour", "The Kestrel Road Winters", "Margins of the Tide", "Lantern Season", "The Weight of Paper Boats",
        "Copper Valley", "Nine Rooms, One Window", "The Understudy's Summer", "Ash and Marigold", "The Long Pause",
        "Light Borrowed from Sundays", "Teeth of the Mountain", "Small Hours at the Baths", "The Ferry Keeper",
        "Orchard of Clocks", "Signal Hill Radio", "Morning at Pike Lane", "The Ninth Lighthouse", "Winter Pears",
        "A Map Folded Wrong", "Eleven Kinds of Rain", "The Glass Orchestra", "Flood Year", "The Last Tram to Kelburn",
        "Paper Kites over Harlow", "The Apiarist's Notebook", "Red Thread, Blue Hour", "Velvet Static", "Quarry Lake",
        "Strangers at the Matinee", "The Projectionist's Son", "Under the Marquee", "Hollow Bell Bay",
        "Juniper Street Choir", "The Saltmarsh Letters", "Moth Season", "A Harbour of Small Boats", "The Tin Astronomer",
        "Second Reel", "Twelve Lamps", "Overnight to Elsewhere", "The Weatherman's Garden", "Midsummer, Indoors",
        "The Orchard Wars", "Wake of the Swans", "The Lending Library", "Fog over Ferncliff",
    ]
    private static let cinemas = [
        "The Kestrel Picture House", "Ferncliff Picturedrome", "Harbour Lane Pictures", "The Orrery Cinema",
        "Saltmarsh Picture Palace", "Northgate Electric Theatre", "The Quarry Cinema", "Juniper Hall Pictures",
        "The Signal Box Cinema", "Marigold Picture Rooms", "The Gaslight Screen", "Copper Street Cinema",
    ]

    private struct Invented {
        let title: String, cinema: String, night: Date, screen: String, seat: String, price: Decimal, photo: Data?
    }

    /// The `index`th invented stub, and a photograph of its ticket drawn as the fixtures are (`scripts/make-fixtures.swift`):
    /// a card on a dark table, at its own tilt, on its own paper.
    private static func invented(_ index: Int) -> Invented {
        var dice = Dice(seed: Release.fnv("stage/\(index)"))
        let round = index / films.count
        let title = films[index % films.count] + (round == 0 ? "" : " " + ["II", "III", "IV", "V", "VI"][min(round - 1, 4)])
        let cinema = cinemas[(index * 5 + round) % cinemas.count]
        let year = Calendar.current.component(.year, from: .now) - (index % 8)
        let night = Calendar.current.date(from: DateComponents(
            year: year, month: 1 + dice.index(12), day: 1 + dice.index(28), hour: [13, 16, 18, 19, 20, 21][dice.index(6)],
            minute: [0, 10, 15, 30, 45][dice.index(5)])) ?? .now
        let screen = "Screen \(1 + dice.index(9))"
        let seat = "\(Array("ABCDEFGHJKLM")[dice.index(12)])\(1 + dice.index(18))"
        let printed = ["14.50", "16.00", "17.50", "18.50", "19.00", "21.00", "22.50"][dice.index(7)]
        let price = Decimal(string: printed) ?? 18
        let paper = UIColor(hue: dice.between(0.08, 0.13), saturation: dice.between(0.06, 0.16), brightness: dice.between(0.88, 0.97),
                            alpha: 1)
        let when = night.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).year().hour().minute())
        let photo = ticket(film: title.uppercased(), venue: cinema.uppercased(), when: when, screen: screen.uppercased(),
                           seat: "SEAT \(seat)", price: "ADULT $\(printed)", ref: "Booking ref \(String(dice.next() % 99_999, radix: 36).uppercased())",
                           paper: paper, tilt: dice.between(-2.6, 2.6))
        return Invented(title: title, cinema: cinema, night: night, screen: screen, seat: seat, price: price, photo: photo)
    }

    private static func ticket(film: String, venue: String, when: String, screen: String, seat: String, price: String,
                               ref: String, paper: UIColor, tilt: Double) -> Data? {
        let size = CGSize(width: 1200, height: 700)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { renderer in
            let ctx = renderer.cgContext
            UIColor(red: 0.22, green: 0.20, blue: 0.18, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            ctx.translateBy(x: size.width / 2, y: size.height / 2)
            ctx.rotate(by: tilt * .pi / 180)
            let card = CGRect(x: -490, y: -210, width: 980, height: 420)
            ctx.setShadow(offset: CGSize(width: 6, height: 8), blur: 18, color: UIColor.black.withAlphaComponent(0.5).cgColor)
            paper.setFill()
            UIBezierPath(roundedRect: card, cornerRadius: 8).fill()
            ctx.setShadow(offset: .zero, blur: 0, color: nil)
            let ink = UIColor(red: 0.12, green: 0.12, blue: 0.13, alpha: 1)
            func text(_ s: String, _ size: CGFloat, _ x: CGFloat, _ y: CGFloat, bold: Bool = false, mono: Bool = true) {
                let font = mono ? UIFont.monospacedSystemFont(ofSize: size, weight: .regular)
                    : UIFont.systemFont(ofSize: size, weight: bold ? .bold : .regular)
                NSAttributedString(string: s, attributes: [.font: font, .foregroundColor: ink])
                    .draw(at: CGPoint(x: card.minX + x, y: card.minY + y - size))
            }
            UIColor(white: 0.25, alpha: 1).setFill()
            var y = card.minY + 14
            while y < card.maxY { ctx.fillEllipse(in: CGRect(x: card.maxX - 184, y: y, width: 8, height: 8)); y += 22 }
            text(venue, 26, 40, 60)
            text(film, film.count > 22 ? 40 : 54, 40, 140, bold: true, mono: false)
            text(when, 28, 40, 200)
            text(screen, 28, 40, 250)
            text(seat, 28, 340, 250)
            text(price, 28, 40, 300)
            text(ref, 20, 40, 350)
            text("ADMIT", 22, card.width - 150, 120)
            text("ONE", 22, card.width - 150, 150)
            text(seat.replacingOccurrences(of: "SEAT ", with: ""), 30, card.width - 150, 260)
        }
        return image.jpegData(compressionQuality: 0.82)
    }

    /// The light swept across the card for four seconds, at sixty updates a second, as one animation interval: the tilt
    /// view's memory, energy and hitches, measured without a gyroscope.
    @MainActor
    static func sweep() async {
        do { try await Task.sleep(for: .seconds(1.5)) } catch { return }
        let state = Signposts.motion.beginAnimationInterval(Signposts.tilt)
        log.info("stage: tilt")
        for frame in 0..<240 {
            let a = Double(frame) / 240 * 4 * .pi
            DebugDrive.shared.tilt = CGPoint(x: sin(a) * 0.85, y: -sin(a * 0.5) * 0.4)
            do { try await Task.sleep(for: .milliseconds(16)) } catch { break }
        }
        DebugDrive.shared.tilt = nil
        Signposts.motion.endInterval(Signposts.tilt, state)
        log.info("stage: tilt done")
    }
}
#endif
