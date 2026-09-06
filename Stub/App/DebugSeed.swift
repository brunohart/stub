import Foundation
import SwiftData
import UIKit
import OSLog

#if DEBUG
/// Launch with `-seed` to run the bundled fixture stubs through the real reader and file them.
/// This is how the simulator gets a full drawer without a hand on the screen, and how the daily
/// build proves Vision and the on-device model still work end to end.
enum DebugSeed {
    static let log = Logger(subsystem: "com.designedbybruno.stub", category: "seed")

    static var requested: Bool { ProcessInfo.processInfo.arguments.contains("-seed") }

    @MainActor
    static func run(in container: ModelContainer) async {
        let context = container.mainContext
        let existing = (try? context.fetchCount(FetchDescriptor<Stub>())) ?? 0
        if ProcessInfo.processInfo.arguments.contains("-reset") {
            try? context.delete(model: Stub.self)
        } else if existing > 0 {
            log.info("Seed skipped: \(existing) stubs already in the drawer")
            return
        }
        log.info("Model status: \(StubReader.modelStatus)")
        let urls = (Bundle.main.urls(forResourcesWithExtension: "png", subdirectory: nil) ?? [])
            .filter { $0.lastPathComponent.hasPrefix("stub-") }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        for url in urls {
            guard let data = try? Data(contentsOf: url), let ui = UIImage(data: data), let cg = ui.cgImage else { continue }
            do {
                let result = try await StubReader.read(cg) { stage in
                    DebugSeed.log.info("\(url.lastPathComponent): \(String(describing: stage))")
                }
                let d = result.draft
                log.info("\(url.lastPathComponent) → '\(d.title)' @ \(d.cinema) seat \(d.seat) by \(d.readBy) (\(Int(d.confidence * 100))%)")
                let stub = Stub(
                    title: d.isUsable ? d.title : url.deletingPathExtension().lastPathComponent,
                    cinema: d.cinema.nilIfEmpty, screenedAt: d.screenedAt, screen: d.screen.nilIfEmpty,
                    seat: d.seat.nilIfEmpty, price: d.price, currency: d.currency.nilIfEmpty,
                    rawText: result.reading.text, imageData: ui.jpegData(compressionQuality: 0.82),
                    readBy: d.readBy, confidence: d.confidence
                )
                context.insert(stub)
            } catch {
                log.error("\(url.lastPathComponent) failed: \(error.localizedDescription)")
            }
        }
        try? context.save()
    }
}
#endif
