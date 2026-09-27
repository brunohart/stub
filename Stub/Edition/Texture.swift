import CoreHaptics
import CoreGraphics
import OSLog

/// The stock under a moving finger (ADR-015). One continuous haptic for as long as the finger is down, its strength
/// following the finger's speed and its sharpness the stock's: cotton soft and dragging, coated card smooth, foil
/// slick and bright. One click where the finger crosses the perforation. Silent when the finger is still.
///
/// Phones without a Taptic Engine, and the simulator, have no haptics; every call is then a no-op.
@MainActor
final class Texture {
    static let log = Logger(subsystem: "com.designedbybruno.stub", category: "texture")
    static var isSupported: Bool { CHHapticEngine.capabilitiesForHardware().supportsHaptics }

    private var engine: CHHapticEngine?
    private var rub: CHHapticAdvancedPatternPlayer?
    private var stock: Stock = .coated

    /// A finger has come down on the card.
    func begin(on stock: Stock) {
        guard Self.isSupported else { return }
        self.stock = stock
        do {
            let engine = try self.engine ?? CHHapticEngine()
            engine.isAutoShutdownEnabled = true
            self.engine = engine
            try engine.start()
            // A continuous event at full strength, held at zero by the intensity control until the finger moves.
            // A continuous event is capped at thirty seconds; nobody strokes a ticket for longer.
            let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: stock.sharpness),
            ], relativeTime: 0, duration: 30)
            let still = CHHapticDynamicParameter(parameterID: .hapticIntensityControl, value: 0, relativeTime: 0)
            let player = try engine.makeAdvancedPlayer(with: CHHapticPattern(events: [event], parameters: [still]))
            try player.start(atTime: CHHapticTimeImmediate)
            rub = player
        } catch {
            Self.log.error("Texture could not start: \(error.localizedDescription)")
            rub = nil
        }
    }

    /// The finger moved at `speed` points a second.
    func stroke(speed: CGFloat) {
        guard let rub else { return }
        let strength = Float(min(max(speed, 0) / 1400, 1)) * stock.grip
        try? rub.sendParameters([CHHapticDynamicParameter(parameterID: .hapticIntensityControl, value: strength, relativeTime: 0)],
                                atTime: CHHapticTimeImmediate)
    }

    /// The finger crossed the perforation: one sharp tick, like a fingernail over the holes.
    func perforation() {
        guard let engine else { return }
        let tick = CHHapticEvent(eventType: .hapticTransient, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.75),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.95),
        ], relativeTime: 0)
        do {
            try engine.makePlayer(with: CHHapticPattern(events: [tick], parameters: [])).start(atTime: CHHapticTimeImmediate)
        } catch {
            Self.log.error("Perforation tick failed: \(error.localizedDescription)")
        }
    }

    /// The finger has lifted.
    func end() {
        try? rub?.stop(atTime: CHHapticTimeImmediate)
        rub = nil
    }

    /// Whether a finger that moved from `a` to `b` (in card points, y down) crossed the perforation.
    nonisolated static func crossesPerforation(from a: CGFloat, to b: CGFloat) -> Bool {
        (a - Card.poster) * (b - Card.poster) < 0
    }
}

extension Stock {
    /// Haptic sharpness: how bright the surface feels. Paper is dull; metal is bright.
    var sharpness: Float {
        switch self {
        case .cotton: 0.15
        case .coated: 0.4
        case .foil: 0.75
        case .holographic: 0.85
        }
    }

    /// How much the surface pushes back against a moving finger. Cotton drags; film slips.
    var grip: Float {
        switch self {
        case .cotton: 0.9
        case .coated: 0.55
        case .foil: 0.45
        case .holographic: 0.35
        }
    }
}
