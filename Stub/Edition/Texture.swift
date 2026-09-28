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

/// The press wheel's detents (ADR-016): one click per take, at the stock's own sharpness, so the wheel feels like the
/// paper it is printing on. The faster the wheel turns, the harder each click. Past one detent every 28 ms single clicks
/// would blur into mush, so the wheel plays a short continuous buzz at the same sharpness instead: a ratchet.
///
/// Here, beside `Texture`, so everything the stock says to a finger is in one file.
@MainActor
final class Detents {
    /// Closer than this, clicks become a ratchet.
    nonisolated static let blur: Duration = .milliseconds(28)

    private var engine: CHHapticEngine?
    private var ratchet: CHHapticAdvancedPatternPlayer?
    private var last: ContinuousClock.Instant?
    private var quiet: Task<Void, Never>?

    /// Clicks from 0.5 at a crawl to 0.9 at `fast` degrees a millisecond.
    nonisolated static func intensity(speed: Double, fast: Double = 1.2) -> Float {
        Float(0.5 + 0.4 * min(max(abs(speed) / fast, 0), 1))
    }

    /// Whether a detent this soon after the last one should ratchet rather than click.
    nonisolated static func ratchets(after interval: Duration) -> Bool { interval < blur }

    func prepare() {
        guard Texture.isSupported, engine == nil else { return }
        do {
            let engine = try CHHapticEngine()
            engine.isAutoShutdownEnabled = true
            try engine.start()
            self.engine = engine
        } catch {
            Texture.log.error("Detents could not start: \(error.localizedDescription)")
        }
    }

    /// The wheel has passed a take, turning at `speed` degrees a millisecond, on `stock`.
    func detent(on stock: Stock, speed: Double) {
        guard Texture.isSupported else { return }
        prepare()
        guard let engine else { return }
        let now = ContinuousClock.now
        defer { last = now }
        let intensity = Self.intensity(speed: speed)
        do {
            if let last, Self.ratchets(after: last.duration(to: now)) {
                if ratchet == nil {
                    let buzz = CHHapticEvent(eventType: .hapticContinuous, parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: stock.sharpness),
                    ], relativeTime: 0, duration: 30)
                    let player = try engine.makeAdvancedPlayer(with: CHHapticPattern(events: [buzz], parameters: []))
                    try player.start(atTime: CHHapticTimeImmediate)
                    ratchet = player
                }
                try ratchet?.sendParameters([CHHapticDynamicParameter(parameterID: .hapticIntensityControl, value: intensity * 0.8, relativeTime: 0)],
                                            atTime: CHHapticTimeImmediate)
            } else {
                let click = CHHapticEvent(eventType: .hapticTransient, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: stock.sharpness),
                ], relativeTime: 0)
                try engine.makePlayer(with: CHHapticPattern(events: [click], parameters: [])).start(atTime: CHHapticTimeImmediate)
            }
        } catch {
            Texture.log.error("Detent failed: \(error.localizedDescription)")
        }
        // The ratchet stops when the detents slow down again.
        quiet?.cancel()
        quiet = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(60))
            guard !Task.isCancelled else { return }
            self?.stopRatchet()
        }
    }

    func stopRatchet() {
        try? ratchet?.stop(atTime: CHHapticTimeImmediate)
        ratchet = nil
    }
}
