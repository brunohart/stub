import SwiftUI
import VisionKit
import OSLog

/// Live text off a physical stub, through the camera (Day 6). Device only: the simulator has no camera,
/// so `isUsable` is false there and the import screen keeps the Photos path (ADR-003).
///
/// The scanner reads the print as it looks; when the ticket is held still and the words have settled, the
/// person taps "Read this stub". The recognised lines go to `StubReader` as a `StubReading`, so the parsers
/// and the model see exactly what they would have seen from a photograph; the photograph taken at that
/// moment is only the plate.
enum StubScanner {
    static let log = Logger(subsystem: "com.designedbybruno.stub", category: "scanner")

    /// Supported by the hardware and allowed by the person. Both, or the button is not offered.
    @MainActor static var isUsable: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    /// What the scanner hands back: the print in reading order, and the frame it was read from.
    struct Scan: Sendable {
        var reading: StubReading
        var photo: CGImage?
    }

    /// One line of recognised text with where it sat in the viewfinder. A plain shape so the ordering can be
    /// tested without a camera.
    struct Line: Equatable, Sendable {
        var text: String
        var top: CGFloat
        var left: CGFloat
    }

    /// Live text arrives in the order the scanner noticed it, not the order the ticket prints it. Read it
    /// top to bottom, then left to right, and skip empty lines and exact repeats (the scanner re-reads a
    /// line it lost and found again).
    static func ordered(_ lines: [Line]) -> [String] {
        var seen = Set<String>()
        return lines
            .sorted { a, b in
                // Two lines on the same printed row are within half a line height of each other.
                abs(a.top - b.top) < 12 ? a.left < b.left : a.top < b.top
            }
            .map { $0.text.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    static func lines(from items: [RecognizedItem]) -> [Line] {
        items.compactMap { item in
            guard case .text(let text) = item else { return nil }
            return Line(text: text.transcript, top: text.bounds.topLeft.y, left: text.bounds.topLeft.x)
        }
    }
}

/// The viewfinder, as a SwiftUI view. Owns the `DataScannerViewController`, keeps the latest recognised
/// items, and on request captures a frame and hands back a `Scan`.
struct StubScannerView: UIViewControllerRepresentable {
    /// The recognised lines, updated as the scanner sees them, so the sheet can say how much it has read.
    @Binding var lineCount: Int
    /// Set by the sheet when the person taps "Read this stub"; the coordinator answers through `onScan`.
    @Binding var wantsScan: Bool
    let onScan: @MainActor (StubScanner.Scan) -> Void
    let onFailure: @MainActor (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .accurate,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        context.coordinator.scanner = scanner
        do {
            try scanner.startScanning()
        } catch {
            StubScanner.log.error("Scanner would not start: \(error.localizedDescription)")
            Task { @MainActor in onFailure("The camera could not start. Choose a photograph instead.") }
        }
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        context.coordinator.parent = self
        if wantsScan {
            context.coordinator.scan()
        }
    }

    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var parent: StubScannerView
        weak var scanner: DataScannerViewController?
        private var items: [RecognizedItem] = []
        private var scanning = false

        init(_ parent: StubScannerView) { self.parent = parent }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            items = allItems
            parent.lineCount = allItems.count
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            items = allItems
            parent.lineCount = allItems.count
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didRemove removedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            items = allItems
            parent.lineCount = allItems.count
        }

        func dataScanner(_ dataScanner: DataScannerViewController, becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable) {
            let reason = switch error {
            case .unsupported: "This device cannot scan live text."
            case .cameraRestricted: "The camera is restricted on this device."
            @unknown default: "The camera stopped."
            }
            StubScanner.log.error("Scanner unavailable: \(reason)")
            parent.onFailure(reason)
        }

        /// Freeze what has been read, take the frame, and hand both back. The lines are what the parsers
        /// get; the photograph is the plate on the card.
        func scan() {
            guard !scanning, let scanner else { return }
            scanning = true
            parent.wantsScan = false
            let lines = StubScanner.ordered(StubScanner.lines(from: items))
            Task { @MainActor in
                defer { scanning = false }
                let photo = try? await scanner.capturePhoto()
                scanner.stopScanning()
                StubScanner.log.info("Scanned \(lines.count) lines\(photo == nil ? ", no photograph" : "")")
                parent.onScan(StubScanner.Scan(reading: StubReading(lines: lines), photo: photo?.cgImage))
            }
        }
    }
}

/// The scanner as a sheet: the viewfinder, one italic line of guidance, one button. Nothing else.
struct ScanSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onScan: @MainActor (StubScanner.Scan) -> Void
    @State private var lineCount = 0
    @State private var wantsScan = false
    @State private var failure: String?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                StubScannerView(lineCount: $lineCount, wantsScan: $wantsScan, onScan: { scan in
                    onScan(scan)
                    dismiss()
                }, onFailure: { failure = $0 })
                .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 14) {
                    Text(failure ?? guidance)
                        .font(Type.italic(18))
                        .foregroundStyle(failure == nil ? Ink.navy : Ink.rust)
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        wantsScan = true
                    } label: {
                        Text("Read this stub")
                            .font(Type.words(17))
                            .foregroundStyle(Ink.paper)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(Ink.ink, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .disabled(lineCount == 0 || failure != nil)
                    .accessibilityHint("Reads the \(lineCount) lines the camera can see and fills in the fields.")
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Paper().ignoresSafeArea(edges: .bottom))
            }
            .navigationTitle("Hold the stub still")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.tint(Ink.ink)
                }
            }
        }
    }

    private var guidance: String {
        switch lineCount {
        case 0: return "Point the camera at the print."
        case 1...3: return "Reading. Hold it flat and let the words settle."
        default: return "\(SeasonSummary.spelled(lineCount).prefix(1).uppercased() + SeasonSummary.spelled(lineCount).dropFirst()) lines read. When they look right, read the stub."
        }
    }
}
