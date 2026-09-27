import Foundation
import CoreGraphics
import SwiftData
import Observation
import OSLog

#if DEBUG
/// Launch with `-drive` (with `-seed`) and the table presses, opens, turns the edition in the light, turns it over,
/// holds the photograph and closes, on a timer.
/// The simulator cannot be tapped from a script (ADR-003), so the interactions that Day 2 is about are
/// driven from here: the same state the finger would set, on a clock, so `recordVideo` can watch.
@MainActor @Observable
final class DebugDrive {
    static let shared = DebugDrive()
    static let log = Logger(subsystem: "com.designedbybruno.stub", category: "drive")
    static var requested: Bool { ProcessInfo.processInfo.arguments.contains("-drive") }
    /// `-season`: open the season sheet once the seed has settled, so the sheet can be screenshotted.
    static var wantsSeason: Bool { ProcessInfo.processInfo.arguments.contains("-season") }
    /// `-import`: open the import sheet once the seed has settled, so the sheet can be screenshotted.
    static var wantsImport: Bool { ProcessInfo.processInfo.arguments.contains("-import") }

    /// `-edition`: open the first stub's detail once the seed has settled, so its edition can be screenshotted.
    static var wantsEdition: Bool { ProcessInfo.processInfo.arguments.contains("-edition") }
    /// `-turned`: with `-edition`, show the back: the stub as scanned.
    static var wantsTurned: Bool { ProcessInfo.processInfo.arguments.contains("-turned") }
    /// `-tilt x,y`: the edition's tilt, held. The simulator has no gyroscope, so this is where a screenshot's light
    /// comes from (ADR-015).
    static let heldTilt: CGPoint? = {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-tilt"), i + 1 < args.count else { return nil }
        let parts = args[i + 1].split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.count == 2 else { return nil }
        return CGPoint(x: parts[0], y: parts[1])
    }()

    /// The card the driver is pressing, if any. `StubCard` treats it as a touch.
    var pressedID: UUID?
    /// The edition's tilt while the driver is turning it in the light; `nil` leaves it to the gyroscope and the finger.
    var tilt: CGPoint? = DebugDrive.heldTilt
    /// Whether the driver has turned the edition over.
    var turned = false
    /// Whether the driver is holding the photograph in the detail view.
    var holding = false
    private(set) var hasRun = false
    /// The choreography runs on a clock from launch (not from the seed), so a filming script can be timed.
    private let launchedAt = Date()
    private var task: Task<Void, Never>?
    /// Seconds after launch at which the first press lands. The seed is done by then on this Mac.
    static let curtain: TimeInterval = 16

    private func beat(_ seconds: Double) async throws {
        try await Task.sleep(for: .seconds(seconds))
    }

    /// Start (or restart, with a fuller drawer) the choreography. It runs in its own task: the table's own
    /// `.task` is cancelled when the detail is pushed over it, and the show must go on.
    func run(stubs: [Stub], open: @escaping (Stub?) -> Void) {
        task?.cancel()
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let wait = Self.curtain - Date().timeIntervalSince(launchedAt)
                if wait > 0 { try await beat(wait) }
                hasRun = true
                try await choreography(stubs: stubs, open: open)
            } catch {
                // Restarted by the seed filing another stub (quietly), or cancelled mid-show.
                if hasRun { Self.log.info("drive: cancelled") }
                pressedID = nil; holding = false; turned = false; tilt = Self.heldTilt
            }
        }
    }

    private func choreography(stubs: [Stub], open: @escaping (Stub?) -> Void) async throws {
        let first = stubs[0]
        let second = stubs.count > 1 ? stubs[1] : stubs[0]
        Self.log.info("drive: press \(second.title)")
        pressedID = second.id;      try await beat(0.7)
        pressedID = nil;            try await beat(1.0)
        Self.log.info("drive: press \(first.title)")
        pressedID = first.id;       try await beat(0.7)
        pressedID = nil;            try await beat(1.0)
        Self.log.info("drive: open \(first.title)")
        // Long enough for the press to run when the release has never been printed (ADR-015).
        open(first);                try await beat(3.2)
        Self.log.info("drive: turn it in the light")
        for step in 0...48 {
            let a = Double(step) / 48 * 2 * .pi
            tilt = CGPoint(x: sin(a) * 0.8, y: -sin(a * 2) * 0.35)
            try await beat(1.0 / 24)
        }
        tilt = Self.heldTilt;       try await beat(0.8)
        Self.log.info("drive: turn over")
        turned = true;              try await beat(1.6)
        Self.log.info("drive: hold")
        holding = true;             try await beat(2.0)
        Self.log.info("drive: release")
        holding = false;            try await beat(1.2)
        Self.log.info("drive: turn back")
        turned = false;             try await beat(1.4)
        Self.log.info("drive: close")
        open(nil);                  try await beat(1.5)
        Self.log.info("drive: done")
    }
}
#endif
