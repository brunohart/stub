import Foundation
import SwiftData
import Observation
import OSLog

#if DEBUG
/// Launch with `-drive` (with `-seed`) and the table presses, opens, holds and closes on a timer.
/// The simulator cannot be tapped from a script (ADR-003), so the interactions that Day 2 is about are
/// driven from here: the same state the finger would set, on a clock, so `recordVideo` can watch.
@MainActor @Observable
final class DebugDrive {
    static let shared = DebugDrive()
    static let log = Logger(subsystem: "com.designedbybruno.stub", category: "drive")
    static var requested: Bool { ProcessInfo.processInfo.arguments.contains("-drive") }
    /// `-season`: open the season sheet once the seed has settled, so the sheet can be screenshotted.
    static var wantsSeason: Bool { ProcessInfo.processInfo.arguments.contains("-season") }

    /// The card the driver is pressing, if any. `StubCard` treats it as a touch.
    var pressedID: UUID?
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
                pressedID = nil; holding = false
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
        open(first);                try await beat(2.0)
        Self.log.info("drive: hold")
        holding = true;             try await beat(2.0)
        Self.log.info("drive: release")
        holding = false;            try await beat(1.5)
        Self.log.info("drive: hold")
        holding = true;             try await beat(2.5)
        holding = false;            try await beat(1.2)
        Self.log.info("drive: close")
        open(nil);                  try await beat(1.5)
        Self.log.info("drive: done")
    }
}
#endif
