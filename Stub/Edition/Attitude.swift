import CoreMotion
import Observation
import CoreGraphics

/// The phone's attitude, as the edition's tilt. Device motion at sixty hertz, measured from how the phone was held
/// when the card appeared, smoothed so the light follows the hand and not the tremor in it, and clamped to ±1
/// (about eighteen degrees). The square drifts slowly toward however the phone is held now, so a new grip becomes
/// the new rest instead of a card stuck at its limit.
///
/// Not started under Reduce Motion, and there is nothing to start on the simulator, which has no gyroscope: there
/// the light stays where a finger or `-tilt` leaves it (ADR-015).
@MainActor @Observable
final class Attitude {
    private(set) var tilt: CGPoint = .zero

    @ObservationIgnored private let manager = CMMotionManager()
    @ObservationIgnored private var square: (roll: Double, pitch: Double)?

    /// Radians of turn for a full tilt.
    static let reach = 18.0 * .pi / 180
    /// How much of the way to the new reading the tilt moves each update.
    static let smoothing = 0.22
    /// How much of the way the square drifts toward the phone each update: about four seconds to settle.
    static let drift = 0.004

    var isAvailable: Bool { manager.isDeviceMotionAvailable }

    func start() {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        square = nil
        manager.deviceMotionUpdateInterval = 1.0 / 60
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion else { return }
            let roll = motion.attitude.roll
            let pitch = motion.attitude.pitch
            // Delivered on the main queue, so this is the main actor.
            MainActor.assumeIsolated { self?.update(roll: roll, pitch: pitch) }
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }

    private func update(roll: Double, pitch: Double) {
        let rest = square ?? (roll, pitch)
        let x = max(-1, min(1, (roll - rest.roll) / Self.reach))
        let y = max(-1, min(1, (pitch - rest.pitch) / Self.reach))
        tilt = CGPoint(x: tilt.x + (x - tilt.x) * Self.smoothing, y: tilt.y + (y - tilt.y) * Self.smoothing)
        square = (rest.roll + (roll - rest.roll) * Self.drift, rest.pitch + (pitch - rest.pitch) * Self.drift)
    }
}
