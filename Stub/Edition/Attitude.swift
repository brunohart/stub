import CoreMotion
import Observation
import CoreGraphics
import Foundation

/// The phone's attitude, as the edition's tilt. Device motion at sixty hertz, measured from how the phone was held
/// when the card appeared, smoothed so the light follows the hand and not the tremor in it, and clamped to ±1
/// (about eighteen degrees). The square drifts slowly toward however the phone is held now, so a new grip becomes
/// the new rest instead of a card stuck at its limit.
///
/// Not started under Reduce Motion, and there is nothing to start on the simulator, which has no gyroscope: there
/// the light stays where a finger or `-tilt` leaves it (ADR-015). Every attitude listens to one `MotionSource`: Core
/// Motion asks for one manager per app, and a table of brass labels once ran one each (docs/decisions/004-budgets.md).
@MainActor @Observable
final class Attitude {
    private(set) var tilt: CGPoint = .zero

    @ObservationIgnored private let id = UUID()
    @ObservationIgnored private var square: (roll: Double, pitch: Double)?

    /// Radians of turn for a full tilt.
    static let reach = 18.0 * .pi / 180
    /// How much of the way to the new reading the tilt moves each update.
    static let smoothing = 0.22
    /// How much of the way the square drifts toward the phone each update: about four seconds to settle.
    static let drift = 0.004

    var isAvailable: Bool { MotionSource.shared.isAvailable }

    func start() {
        square = nil
        MotionSource.shared.listen(id) { [weak self] roll, pitch in self?.update(roll: roll, pitch: pitch) }
    }

    func stop() {
        MotionSource.shared.leave(id)
    }

    private func update(roll: Double, pitch: Double) {
        let rest = square ?? (roll, pitch)
        let x = max(-1, min(1, (roll - rest.roll) / Self.reach))
        let y = max(-1, min(1, (pitch - rest.pitch) / Self.reach))
        tilt = CGPoint(x: tilt.x + (x - tilt.x) * Self.smoothing, y: tilt.y + (y - tilt.y) * Self.smoothing)
        square = (rest.roll + (roll - rest.roll) * Self.drift, rest.pitch + (pitch - rest.pitch) * Self.drift)
    }
}

/// The one device-motion stream the app has. Running while anything is listening, and stopped the moment nothing is, so the
/// gyroscope can power down (Apple: create one `CMMotionManager`; stop updates as soon as they are not needed).
@MainActor
final class MotionSource {
    static let shared = MotionSource()

    private let manager = CMMotionManager()
    private var listeners: [UUID: (Double, Double) -> Void] = [:]

    var isAvailable: Bool { manager.isDeviceMotionAvailable }
    /// How many are listening: zero means the gyroscope is off. For the tests.
    var listening: Int { listeners.count }

    func listen(_ id: UUID, _ handler: @escaping (Double, Double) -> Void) {
        listeners[id] = handler
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 60
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion else { return }
            let roll = motion.attitude.roll
            let pitch = motion.attitude.pitch
            // Delivered on the main queue, so this is the main actor.
            MainActor.assumeIsolated {
                guard let self else { return }
                for handler in self.listeners.values { handler(roll, pitch) }
            }
        }
    }

    func leave(_ id: UUID) {
        listeners[id] = nil
        if listeners.isEmpty, manager.isDeviceMotionActive { manager.stopDeviceMotionUpdates() }
    }
}
