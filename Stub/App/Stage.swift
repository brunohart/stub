import Foundation
import SwiftData
import UIKit
import OSLog

#if DEBUG || PERF
/// Staging for the measured runs (docs/decisions/004-budgets.md). The UI and performance tests launch the app with these, in
/// Debug and in the Performance configuration (Release's optimiser with these hooks compiled in); a Release build has none.
///
/// - `-stage-drawer N`: the drawer emptied and filled with N stubs at once, from the bundled fixtures, read by nobody.
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

    /// Empty the drawer and file `count` stubs: the fixtures in turn, each pass a year further back, so a big drawer has
    /// many years and a release seen more than once, as a real one would.
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
        let calendar = Calendar.current
        for n in 0..<count {
            let truth = truths[n % truths.count]
            let pass = n / truths.count
            if photos[truth.file] == nil,
               let url = Bundle.main.url(forResource: truth.file, withExtension: nil),
               let data = try? Data(contentsOf: url),
               let cg = PlateImage.decode(data, maxPixelSize: PlateImage.intake) {
                photos[truth.file] = UIImage(cgImage: cg).jpegData(compressionQuality: 0.82)
            }
            let night = format.date(from: truth.at).flatMap { calendar.date(byAdding: .year, value: -pass, to: $0) }
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
