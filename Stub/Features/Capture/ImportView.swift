import SwiftUI
import SwiftData
import PhotosUI

/// Bring a stub in. From the library today; from the camera when there is a device to hold.
struct ImportView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var pick: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var stage: StubReader.Stage?
    @State private var reading: StubReading?
    @State private var draft = StubDraft()
    @State private var failure: String?
    @State private var showRaw = false
    @State private var isScanning = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ZStack {
                Paper()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        if let image {
                            Image(uiImage: image)
                                .resizable().scaledToFit()
                                .frame(maxHeight: 260)
                                .silkscreened(strength: stage == .done ? 1 : 0.4, seed: 2)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                                .animation(reduceMotion ? Motion.plain : Motion.settle, value: stage)
                                .accessibilityLabel(stage == .done ? "The stub, printed on parchment." : "The photograph of the stub, being read.")
                        } else {
                            picker
                        }

                        if let stage, stage != .done {
                            StageLine(stage: stage)
                        }

                        // The fields are on screen while the model is still answering, so a streamed title
                        // has somewhere to land.
                        if reading != nil || stage == .done || image == nil || understanding {
                            fields
                        }

                        if let failure {
                            Text(failure).font(Type.reading(15)).foregroundStyle(Ink.rust)
                        }

                        if let reading {
                            DisclosureGroup(isExpanded: $showRaw) {
                                Text(reading.text)
                                    .font(Type.numbers(12))
                                    .foregroundStyle(Ink.ink.opacity(0.7))
                                    .padding(.top, 8)
                            } label: {
                                Text("What the reader saw")
                                    .font(Type.words(14)).foregroundStyle(Ink.grey)
                            }
                            .tint(Ink.grey)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("New stub")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.tint(Ink.ink)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Keep") { keep() }
                        .tint(Ink.ink)
                        .disabled(!draft.isUsable)
                }
            }
            .onChange(of: pick) { _, item in
                guard let item else { return }
                Task { await load(item) }
            }
            .fullScreenCover(isPresented: $isScanning) {
                ScanSheet { scan in Task { await scanned(scan) } }
            }
        }
    }

    private var understanding: Bool {
        if case .understanding = stage { return true }
        return false
    }

    private var picker: some View {
        // The camera, when there is one to hold (Day 6). The simulator has none, and keeps the Photos path.
        let scannable = StubScanner.isUsable
        return VStack(alignment: .leading, spacing: 14) {
            if scannable {
                Button { isScanning = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "camera.viewfinder")
                        Text("Scan the stub with the camera")
                            .font(Type.words(16))
                    }
                    .foregroundStyle(Ink.paper)
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .background(Ink.ink, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the camera and reads the print live.")
            }
            PhotosPicker(selection: $pick, matching: .images, photoLibrary: .shared()) {
                HStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                    Text("Choose a photograph of the stub")
                        .font(Type.words(16))
                }
                .foregroundStyle(scannable ? Ink.ink : Ink.paper)
                .padding(.horizontal, 16).padding(.vertical, 14)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .background(scannable ? Ink.ink.opacity(0.08) : Ink.ink, in: RoundedRectangle(cornerRadius: 6))
            }
            .accessibilityHint("Opens your photo library.")
            Text("Or type it. The reader is a shortcut, not a gate.")
                .font(Type.italic(16)).foregroundStyle(Ink.navy)
            Text(StubReader.modelStatus)
                .font(Type.numbers(11)).foregroundStyle(Ink.grey)
        }
    }

    /// The camera's lines go through the same parsers as a photograph's (ADR-010); the frame is the plate.
    private func scanned(_ scan: StubScanner.Scan) async {
        failure = nil
        reading = nil
        if let photo = scan.photo { image = UIImage(cgImage: photo) }
        guard !scan.reading.lines.isEmpty else {
            stage = .done
            failure = "The camera read nothing. Hold the stub flatter, or type it in."
            return
        }
        // A frame the camera could not give is a blank stub in the drawer, which the card already knows how to print.
        let plate = scan.photo ?? blankPlate
        let result = await StubReader.read(scan.reading, plate: plate, progress: { stage in
            withAnimation(reduceMotion ? Motion.plain : Motion.settle) { self.stage = stage }
        }, partial: { snapshot in
            withAnimation(Motion.place) { draft = snapshot }
        })
        reading = result.reading
        withAnimation(Motion.place) { draft = result.draft }
    }

    private var blankPlate: CGImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8))
        return renderer.image { ctx in UIColor(Ink.cream).setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 8, height: 8)) }.cgImage!
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: 14) {
            Field("Film", text: $draft.title, font: Type.display(22))
            Field("Cinema", text: $draft.cinema, font: Type.words(17))
            HStack(spacing: 14) {
                Field("Screen", text: $draft.screen, font: Type.words(17))
                Field("Seat", text: $draft.seat, font: Type.numbers(17))
            }
            DatePicker("Screening", selection: Binding(
                get: { draft.screenedAt ?? .now },
                set: { draft.screenedAt = $0 }
            ), displayedComponents: [.date, .hourAndMinute])
            .font(Type.words(15))
            .tint(Ink.orange)
            if draft.readBy != "manual", draft.isUsable {
                Text("Read by \(draft.readBy == "foundation-models" ? "the on-device model" : "heuristics") · confidence \(Int(draft.confidence * 100))%")
                    .font(Type.numbers(11)).foregroundStyle(Ink.grey)
                    .accessibilityLabel("Read by \(draft.readBy == "foundation-models" ? "the on-device model" : "heuristics"), \(Int(draft.confidence * 100)) percent confident.")
            }
        }
    }

    private func load(_ item: PhotosPickerItem) async {
        failure = nil
        // Upright and no larger than the reader needs, decoded off the main thread: a portrait photograph
        // reaches Vision the right way up, and a 48 MP one is not carried through the crop at 48 MP.
        let size = PlateImage.intake
        guard let data = try? await item.loadTransferable(type: Data.self),
              let cg = await Task.detached(priority: .userInitiated, operation: {
                  PlateImage.decode(data, maxPixelSize: size)
              }).value else {
            failure = "That photograph could not be opened."
            return
        }
        image = UIImage(cgImage: cg)
        do {
            let result = try await StubReader.read(cg, progress: { stage in
                withAnimation(Motion.settle) { self.stage = stage }
            }, partial: { snapshot in
                // The model's answer as it forms: the title lands first, then the rest fills in beneath it.
                withAnimation(Motion.place) { draft = snapshot }
            })
            reading = result.reading
            withAnimation(Motion.place) {
                draft = result.draft
                // Show the ticket, not the table it was lying on.
                if result.cropped { image = UIImage(cgImage: result.plate) }
            }
        } catch {
            stage = .done
            failure = "No printed text found. Type it in instead."
            reading = nil
        }
    }

    private func keep() {
        let stub = Stub(
            title: draft.title.trimmingCharacters(in: .whitespaces),
            cinema: draft.cinema.nilIfEmpty,
            screenedAt: draft.screenedAt,
            screen: draft.screen.nilIfEmpty,
            seat: draft.seat.nilIfEmpty,
            price: draft.price,
            currency: draft.currency.nilIfEmpty,
            rawText: reading?.text ?? "",
            imageData: image?.jpegData(compressionQuality: 0.82),
            readBy: reading == nil ? "manual" : draft.readBy,
            confidence: reading == nil ? 1 : draft.confidence
        )
        context.insert(stub)
        dismiss()
    }
}

/// A labelled field. The label is quiet words; the value carries the weight.
struct Field: View {
    let label: String
    @Binding var text: String
    let font: Font

    init(_ label: String, text: Binding<String>, font: Font) {
        self.label = label; self._text = text; self.font = font
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(Type.words(12)).foregroundStyle(Ink.grey)
                .accessibilityHidden(true)
            TextField("", text: $text)
                .font(font)
                .foregroundStyle(Ink.ink)
                .textInputAutocapitalization(.words)
                .frame(minHeight: 44)
                .accessibilityLabel(label)
            Rectangle().fill(Ink.ink.opacity(0.18)).frame(height: 1)
        }
    }
}

struct StageLine: View {
    let stage: StubReader.Stage
    var body: some View {
        HStack(spacing: 10) {
            ProgressView().tint(Ink.orange)
            Text(label).font(Type.italic(16)).foregroundStyle(Ink.navy)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }
    private var label: String {
        switch stage {
        case .cropping: return "Finding the stub…"
        case .reading: return "Reading the print…"
        case .understanding(let parser):
            return parser == "foundation-models" ? "Asking the on-device model…" : "Working it out…"
        case .done: return ""
        }
    }
}
