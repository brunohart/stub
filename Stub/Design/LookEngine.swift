import Foundation

/// Which implementation draws the look. The look itself is specified at the modifier boundary
/// (`Paper`, `silkscreened`, `DisplayTitle`); this only decides who does the arithmetic.
///
/// Day 1: Metal is the default. The SwiftUI version stays so the two can be screenshotted side by side
/// (`scripts/run.sh --look swiftui`) and so the identity survives a missing Metal toolchain (ADR-002).
enum LookEngine: String, Sendable, CaseIterable {
    case swiftUI = "swiftui"
    case metal

    /// Chosen once per process. `-look swiftui` or `-look metal` on the command line overrides the default.
    static let current: LookEngine = {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-look"), i + 1 < args.count,
           let engine = LookEngine(rawValue: args[i + 1].lowercased()) {
            return engine
        }
        return .metal
    }()

    var isMetal: Bool { self == .metal }
}
