import Foundation
import SwiftData

/// One ticket stub. One night in a room with strangers.
@Model
final class Stub {
    @Attribute(.unique) var id: UUID
    var title: String
    var cinema: String?
    var screenedAt: Date?
    var screen: String?
    var seat: String?
    var price: Decimal?
    var currency: String?

    /// Everything the reader saw, verbatim. Kept so the human can correct the machine.
    var rawText: String
    @Attribute(.externalStorage) var imageData: Data?

    /// Who produced the structured fields: `foundation-models`, `heuristic`, or `manual`.
    var readBy: String
    var confidence: Double

    /// Authored imperfection. Fixed at creation so the stub never fidgets on its own.
    var tilt: Double
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        cinema: String? = nil,
        screenedAt: Date? = nil,
        screen: String? = nil,
        seat: String? = nil,
        price: Decimal? = nil,
        currency: String? = nil,
        rawText: String = "",
        imageData: Data? = nil,
        readBy: String = "manual",
        confidence: Double = 1,
        tilt: Double = Stub.randomTilt(),
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.cinema = cinema
        self.screenedAt = screenedAt
        self.screen = screen
        self.seat = seat
        self.price = price
        self.currency = currency
        self.rawText = rawText
        self.imageData = imageData
        self.readBy = readBy
        self.confidence = confidence
        self.tilt = tilt
        self.createdAt = createdAt
    }

    /// Between -1.5° and 1.5°, never level. Rounded so two stubs rarely share a tilt.
    static func randomTilt() -> Double {
        let candidates: [Double] = [-1.5, -1.1, -0.8, -0.5, 0.4, 0.7, 1.2]
        return candidates.randomElement() ?? -0.8
    }
}

extension Stub {
    var displayDate: String? {
        guard let screenedAt else { return nil }
        return screenedAt.formatted(.dateTime.day(.twoDigits).month(.abbreviated).year(.twoDigits))
            .uppercased()
    }

    var displayPrice: String? {
        guard let price else { return nil }
        let code = currency ?? "NZD"
        return price.formatted(.currency(code: code).precision(.fractionLength(2)))
    }

    var seatLine: String? {
        [screen, seat].compactMap { $0 }.joined(separator: " · ").nilIfEmpty
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
