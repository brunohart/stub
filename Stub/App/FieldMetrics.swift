import Foundation
import MetricKit
import OSLog

/// Field data without collecting data (docs/decisions/004-budgets.md, 006). MetricKit hands the app, about once a day,
/// what the system measured of it on this phone: launch time, hangs, hitches, memory, CPU and GPU time, and the
/// capture's own intervals (`mxSignpost`, below). Stub keeps the last thirty reports on the phone and sends them nowhere.
/// Your card says they are there; the person can share them by hand, each time, seeing what they send: the App Store's
/// optional-disclosure case, so the privacy label stays "Data Not Collected". Apple's own field numbers (Xcode
/// Organizer, from people who chose to share with developers) are collected by Apple and need nothing from the app.
final class FieldMetrics: NSObject, MXMetricManagerSubscriber, @unchecked Sendable {
    static let shared = FieldMetrics()
    static let log = Logger(subsystem: Signposts.subsystem, category: "field")
    /// The handle the capture's MetricKit signposts are made on: their durations come back in each day's report.
    static let capture = MXMetricManager.makeLogHandle(category: "Capture")

    private let folder: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Field", isDirectory: true)
    }()
    private let keep = 30

    /// Listen. Called once at launch; MetricKit delivers what it has gathered since.
    func start() {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        MXMetricManager.shared.add(self)
    }

    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads { store(payload.jsonRepresentation(), kind: "metrics") }
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads { store(payload.jsonRepresentation(), kind: "diagnostics") }
    }

    /// The reports on this phone, newest first.
    var reports: [URL] {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    private func store(_ json: Data, kind: String) {
        let stamp = ISO8601DateFormatter().string(from: .now).replacingOccurrences(of: ":", with: "-")
        let file = folder.appendingPathComponent("\(stamp)-\(kind).json")
        do {
            try json.write(to: file, options: [.atomic, .completeFileProtection])
            Self.log.info("field: kept a \(kind) report")
        } catch {
            Self.log.error("field: could not keep a \(kind) report: \(error.localizedDescription)")
        }
        for old in reports.dropFirst(keep) { try? FileManager.default.removeItem(at: old) }
    }
}
