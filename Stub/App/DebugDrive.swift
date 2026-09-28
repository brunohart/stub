import Foundation
import CoreGraphics
import SwiftData
import Observation
import OSLog
import SwiftUI

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

    /// `-open "The Brutalist"`: with `-edition`, open this stub rather than the newest.
    static let openTitle: String? = value(after: "-open")
    /// `-press`: with `-edition`, carry the card on into the press room once it is printed (ADR-016).
    static var wantsPress: Bool { ProcessInfo.processInfo.arguments.contains("-press") }
    /// `-part constructivist/disc`: in the press room, pick up this part (its last word is enough).
    static let part: String? = value(after: "-part")
    /// `-take 14`: turn the part in hand to this take and let it settle.
    static let take: Int? = value(after: "-take").flatMap { Int($0) }
    /// `-bench movement|inks|stock`: in the press room, open that choice's object on the bench (brief §5.5–5.6).
    static let bench: String? = value(after: "-bench")
    /// `-flood 0.4`: in the press room, start the next palette flooding the card and hold it this far across.
    static let flood: CGFloat? = value(after: "-flood").flatMap { Double($0) }.map { CGFloat($0) }
    /// `-pulled`: in the press room, pull the proof on the press once it is set up (brief §5.7).
    static var wantsPull: Bool { ProcessInfo.processInfo.arguments.contains("-pulled") }
    /// `-wet 0.6`: hold the ink that wet after a pull, for a screenshot.
    static let wet: Double? = value(after: "-wet").flatMap { Double($0) }
    /// `-signed`: sign with the fixture signature at launch, if there is none (brief §5.8).
    static var wantsSigned: Bool { ProcessInfo.processInfo.arguments.contains("-signed") }
    /// `-separated 0.8`: in the press room, lift the card's layers this far apart (brief §5.4).
    static let separated: CGFloat? = value(after: "-separated").flatMap { Double($0) }.map { CGFloat($0) }
    /// `-scrub 13.5`: hold the wheel here, between two takes, for a screenshot of an in-between.
    static let scrub: Double? = value(after: "-scrub").flatMap { Double($0) }

    private static func value(after flag: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    /// `-keeps`: with `-edition`, open "What the press keeps" in the detail and scroll to it.
    static var wantsKeeps: Bool { ProcessInfo.processInfo.arguments.contains("-keeps") }
    /// `-proof "disc=14,bars=3"`: a proof pulled over each release as it is first printed (ADR-016). Parts are named
    /// by their last word or their whole id; `movement=`, `inks=` and `stock=` choose from the genome.
    static let proofSpec: String? = {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-proof"), i + 1 < args.count else { return nil }
        return args[i + 1]
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

    /// In the press room: pick up `-part`, and set the wheel at `-take` or `-scrub`. With `-drive`, turn the wheel on a
    /// clock instead, so `recordVideo` can watch the in-betweens: a flick up to take fourteen, a settle, a slower turn
    /// back to three, a settle, and the part put down.
    func press(_ session: PressSession, reduceMotion: Bool) async {
        do {
            try await beat(0.8)
            if let open = Self.bench.flatMap(PressSession.Bench.init(rawValue:)) {
                Self.log.info("drive: open the bench at \(open.rawValue)")
                withAnimation(Motion.settle) { session.bench = open }
                try await beat(0.8)
                if open == .movement, Self.requested {
                    // A finger slid along the fan, left to right and back a little, and let go on a card.
                    Self.log.info("drive: slide along the fan")
                    for frame in 0...90 {
                        let t = Double(frame) / 90
                        session.fanFinger = CGFloat(30 + 300 * sin(t * .pi * 0.62))
                        try await beat(1.0 / 60)
                    }
                    try await beat(0.6)
                    let chosen = Genome.movements[5]
                    Self.log.info("drive: let go on \(chosen.rawValue)")
                    session.fanFinger = nil
                    session.letGo = chosen
                    try await beat(2.4)
                    Self.log.info("drive: done")
                    return
                }
                if open == .movement, let finger = Self.scrub {
                    // With the fan open, `-scrub` is where along it the finger rests.
                    session.fanFinger = CGFloat(finger)
                }
            }
            if let across = Self.flood {
                let palettes = Genome.palettes
                let next = palettes[((palettes.firstIndex(of: session.edition.palette) ?? 0) + 1) % palettes.count]
                Self.log.info("drive: flood \(next.rawValue) to \(Double(across))")
                session.bench = .inks
                session.flood = PressSession.Flood(palette: next, origin: CGPoint(x: Card.width * 0.3, y: Card.height * 0.28),
                                                   progress: across)
                return
            }
            if let apart = Self.separated {
                if Self.requested {
                    try await separations(session, to: apart)
                    return
                }
                Self.log.info("drive: separate \(Double(apart))")
                withAnimation(Motion.settle) { session.separation = apart }
                try await beat(0.8)
            }
            let named = Self.part.flatMap { name in session.turnable.first { $0.id == name || $0.id.hasSuffix("/" + name) } }
            guard let part = named ?? (Self.requested ? session.turnable.first : nil) else {
                try await pullAndTurn(session)
                return
            }
            Self.log.info("drive: pick up \(part.id)")
            withAnimation(Motion.settle) { session.pickUp(part) }
            try await beat(0.8)
            if Self.requested {
                try await turn(session, to: 14, over: 1.6)
                try await beat(1.4)
                try await turn(session, to: 3, over: 2.4)
                try await beat(1.4)
                Self.log.info("drive: put down")
                withAnimation(Motion.settle) { session.putDown() }
                try await beat(1.0)
                Self.log.info("drive: done")
            } else if let scrub = Self.scrub {
                Self.log.info("drive: hold the wheel at \(scrub)")
                session.position = scrub
            } else if let take = Self.take {
                Self.log.info("drive: take \(take)")
                withAnimation(Motion.settle) { session.position = Double(take) }
                session.settle(on: take)
            }
            try await pullAndTurn(session)
        } catch {
            // The room was left.
        }
    }

    /// `-pulled` and `-turned` in the press room: the proof pulled (held as wet as `-wet` says), and the card turned over
    /// to its back and the margin.
    private func pullAndTurn(_ session: PressSession) async throws {
        if Self.wantsPull {
            try await beat(0.8)
            Self.log.info("drive: pull the proof")
            withAnimation(Motion.settle) { session.putDown() }
            session.heldWet = Self.wet
            session.pull()
        }
        if Self.wantsTurned {
            try await beat(0.6)
            Self.log.info("drive: turn it over on the bed")
            withAnimation(Motion.settle) { session.turned = true }
        }
    }

    /// The card pinched apart into its sheets, turned in the light, a part picked up on its own sheet, put down, and the
    /// sheets pressed back together.
    private func separations(_ session: PressSession, to apart: CGFloat) async throws {
        Self.log.info("drive: pinch apart")
        for frame in 1...50 {
            var still = Transaction()
            still.disablesAnimations = true
            withTransaction(still) { session.separation = apart * CGFloat(frame) / 50 * 0.85 }
            try await beat(1.0 / 60)
        }
        withAnimation(Motion.settle) { session.separation = apart }
        try await beat(1.2)
        Self.log.info("drive: the light across the sheets")
        for step in 0...60 {
            let a = Double(step) / 60 * 2 * .pi
            tilt = CGPoint(x: sin(a) * 0.7, y: -0.2 - sin(a) * 0.2)
            try await beat(1.0 / 30)
        }
        tilt = Self.heldTilt
        if let part = Self.part.flatMap({ name in session.turnable.first { $0.id == name || $0.id.hasSuffix("/" + name) } }) {
            Self.log.info("drive: pick up \(part.id) on its sheet")
            withAnimation(Motion.settle) { session.pickUp(part) }
            try await beat(1.6)
            withAnimation(Motion.settle) { session.putDown() }
            try await beat(0.8)
        }
        Self.log.info("drive: press together")
        withAnimation(Motion.settle) { session.separation = 0 }
        try await beat(1.4)
        Self.log.info("drive: done")
    }

    /// The wheel turned by hand to `take`: fast at first and slowing, as a flick coasts, then the settle spring.
    private func turn(_ session: PressSession, to take: Int, over seconds: Double) async throws {
        Self.log.info("drive: turn to \(take)")
        let start = session.position
        let frames = Int(seconds * 60)
        for frame in 1...frames {
            let t = Double(frame) / Double(frames)
            let eased = 1 - pow(1 - t, 3)
            var still = Transaction()
            still.disablesAnimations = true
            withTransaction(still) { session.position = start + (Double(take) - 0.18 - start) * eased }
            try await beat(1.0 / 60)
        }
        withAnimation(Motion.settle) { session.position = Double(take) }
        session.settle(on: take)
    }
}
#endif
