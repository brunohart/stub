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
                                .animation(Motion.settle, value: stage)
                        } else {
                            picker
                        }

                        if let stage, stage != .done {
                            StageLine(stage: stage)
                        }

                        if reading != nil || stage == .done || image == nil {
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
        }
    }

    private var picker: some View {
        VStack(alignment: .leading, spacing: 14) {
            PhotosPicker(selection: $pick, matching: .images, photoLibrary: .shared()) {
                HStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                    Text("Choose a photograph of the stub")
                        .font(Type.words(16))
                }
                .foregroundStyle(Ink.paper)
                .padding(.horizontal, 16).padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Ink.ink, in: RoundedRectangle(cornerRadius: 6))
            }
            Text("Or type it. The reader is a shortcut, not a gate.")
                .font(Type.italic(16)).foregroundStyle(Ink.navy)
            Text(StubReader.modelStatus)
                .font(Type.numbers(11)).foregroundStyle(Ink.grey)
        }
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
            }
        }
    }

    private func load(_ item: PhotosPickerItem) async {
        failure = nil
        guard let data = try? await item.loadTransferable(type: Data.self),
              let ui = UIImage(data: data), let cg = ui.cgImage else {
            failure = "That photograph could not be opened."
            return
        }
        image = ui
        do {
            let result = try await StubReader.read(cg) { stage in
                withAnimation(Motion.settle) { self.stage = stage }
            }
            reading = result.reading
            withAnimation(Motion.place) { draft = result.draft }
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
            TextField("", text: $text)
                .font(font)
                .foregroundStyle(Ink.ink)
                .textInputAutocapitalization(.words)
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
    }
    private var label: String {
        switch stage {
        case .reading: return "Reading the print…"
        case .understanding(let parser):
            return parser == "foundation-models" ? "Asking the on-device model…" : "Working it out…"
        case .done: return ""
        }
    }
}
