import SwiftUI
import SwiftData
import PhotosUI

/// Bring a stub in. Keep a stub opens on the camera (ADR-025); the photograph, or one from the library, is read here, and
/// typing it in is always there. Keep it and you get two things back (ADR-015): the stub as scanned, filed in the drawer,
/// and its edition, printed here before your eyes.
struct ImportView: View {
    /// A ticket handed over from outside (ADR-021): the sheet opens prefilled, or reading it.
    var arrival: Arrival? = nil
    /// The drawer that was open when Keep a stub was pressed: a stub kept is filed there too (ADR-026).
    var drawer: StubDrawer? = nil
    /// Keep a stub opens on the viewfinder; an arrival, or typing, on the form.
    var startsWithCamera = false
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    /// The drawer, so a kept stub's edition knows which viewing of its release it is.
    @Query private var everyStub: [Stub]
    /// The stub just kept. Set, the sheet stops being a form and becomes the press.
    @State private var kept: Stub?
    @State private var keptTurned = false

    @State private var pick: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var stage: StubReader.Stage?
    @State private var reading: StubReading?
    @State private var draft = StubDraft()
    @State private var failure: String?
    @State private var showRaw = false
    @State private var received = false
    /// Holding the camera up to the ticket, or the form it fills in.
    @State private var onCamera = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(arrival: Arrival? = nil, drawer: StubDrawer? = nil, startsWithCamera: Bool = false) {
        self.arrival = arrival
        self.drawer = drawer
        self.startsWithCamera = startsWithCamera
        _onCamera = State(initialValue: startsWithCamera && arrival == nil)
    }

    var body: some View {
        ZStack {
            form
                .opacity(onCamera ? 0 : 1)
            if onCamera {
                Viewfinder { photo in
                    image = UIImage(cgImage: photo)
                    withAnimation(reduceMotion ? Motion.plain : Motion.place) { onCamera = false }
                    Task { await read(photo) }
                } library: { item in
                    withAnimation(reduceMotion ? Motion.plain : Motion.place) { onCamera = false }
                    Task { await load(item) }
                } type: {
                    withAnimation(reduceMotion ? Motion.plain : Motion.place) { onCamera = false }
                } cancel: {
                    dismiss()
                }
                .transition(.opacity)
            }
        }
    }

    private var form: some View {
        NavigationStack {
            ZStack {
                Paper()
                if let kept {
                    press(kept)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                            if let image {
                                Image(uiImage: image)
                                    .resizable().scaledToFit()
                                    .frame(maxHeight: 260)
                                    .silkscreened(strength: stage == .done ? 1 : 0.4)
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                                    .animation(reduceMotion ? Motion.plain : Motion.settle, value: stage)
                                    .accessibilityLabel(stage == .done ? "The stub, printed on parchment." : "The photograph of the stub, being read.")
                            } else if arrival == nil {
                                picker
                            }
                            if let arrival {
                                Label(arrival.sentence, systemImage: arrival.symbol)
                                    .font(Type.words(15)).foregroundStyle(Ink.ink.opacity(0.75))
                                    .fixedSize(horizontal: false, vertical: true)
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
            }
            .navigationTitle(kept == nil ? "New stub" : "Kept")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                if kept == nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }.buttonStyle(.stub(.quiet))
                    }
                    .sharedBackgroundVisibility(.hidden)
                }
            }
            // Keep is the sheet's one act, so it is a stamp where the thumb is, not a word in the corner (ADR-022). It
            // waits, printed faint, until there is a title to keep.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if kept == nil {
                    Button { keep() } label: {
                        Text(draft.isUsable ? "Keep it" : "Keep it, once it has a title").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.stub(.ink))
                    .disabled(!draft.isUsable)
                    .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 8)
                    .background {
                        LinearGradient(stops: [.init(color: Ink.paper.opacity(0), location: 0), .init(color: Ink.paper, location: 0.4)],
                                       startPoint: .top, endPoint: .bottom)
                            .ignoresSafeArea(edges: .bottom)
                    }
                }
            }
            .onChange(of: pick) { _, item in
                guard let item else { return }
                Task { await load(item) }
            }
            .task {
                guard let arrival, !received else { return }
                received = true
                await receive(arrival)
                #if DEBUG
                // `-preview`: keep it once it is read, let the press print it, and go back to the drawer.
                guard DebugDrive.wantsPreview, draft.isUsable else { return }
                // The edition is chosen while the sheet is still up, so the press prints it on camera; the wait is cut.
                let year = draft.screenedAt.map { Calendar.current.component(.year, from: $0) }
                _ = await Editions.shared.decide(title: draft.title, year: year, screen: draft.screen.nilIfEmpty)
                do { try await Task.sleep(for: .seconds(1.4)) } catch { return }
                DebugDrive.log.info("preview: keep")
                keep()
                do { try await Task.sleep(for: .seconds(4.4)) } catch { return }
                DebugDrive.log.info("preview: into the drawer")
                DebugDrive.shared.openNewest = true
                dismiss()
                #endif
            }
        }
    }

    private var understanding: Bool {
        if case .understanding = stage { return true }
        return false
    }

    /// Typing it in, with nothing photographed yet: the camera and the library are a tap away still.
    private var picker: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Button { withAnimation(reduceMotion ? Motion.plain : Motion.place) { onCamera = true } } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "camera")
                        Text("Photograph it")
                    }
                }
                .buttonStyle(.stub(.paper))
                .accessibilityHint("Opens the camera.")
                PhotosPicker(selection: $pick, matching: .images, photoLibrary: .shared()) {
                    HStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle.angled")
                        Text("Photos")
                    }
                }
                .buttonStyle(.stub(.paper))
                .accessibilityHint("Opens your photo library.")
            }
            Text(StubReader.modelStatus)
                .font(Type.words(12)).foregroundStyle(Ink.grey)
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
                Text("Read by \(ReadBy.words(draft.readBy)) · confidence \(Int(draft.confidence * 100))%")
                    .font(Type.numbers(11)).foregroundStyle(Ink.grey)
                    .accessibilityLabel("Read by \(ReadBy.words(draft.readBy)), \(Int(draft.confidence * 100)) percent confident.")
            }
        }
    }

    /// A ticket from outside. Known fields land in the form as they are, with what was handed over as the raw read; a
    /// page is read as a photograph is.
    private func receive(_ arrival: Arrival) async {
        switch arrival.content {
        case .known(let known, let raw, let plate):
            if let plate, let cg = PlateImage.decode(plate, maxPixelSize: PlateImage.intake) { image = UIImage(cgImage: cg) }
            reading = StubReading(text: raw)
            stage = .done
            withAnimation(reduceMotion ? Motion.plain : Motion.place) { draft = known }
        case .page(let data, let whole):
            await read(data, whole: whole)
        case .document(let page, let lines):
            // The PDF's own words to the parsers, its page to the plate: no OCR (BEDIP-218).
            guard let cg = PlateImage.decode(page, maxPixelSize: PlateImage.intake) else { return }
            image = UIImage(cgImage: cg)
            let result = await StubReader.read(StubReading(lines: lines), plate: cg, progress: { stage in
                withAnimation(reduceMotion ? Motion.plain : Motion.settle) { self.stage = stage }
            }, partial: { snapshot in
                withAnimation(Motion.place) { draft = snapshot }
            })
            reading = result.reading
            withAnimation(Motion.place) {
                draft = result.draft
                if result.cropped { image = UIImage(cgImage: result.plate) }
            }
        }
    }

    private func load(_ item: PhotosPickerItem) async {
        failure = nil
        // Upright and no larger than the reader needs, decoded off the main thread: a portrait photograph
        // reaches Vision the right way up, and a 48 MP one is not carried through the crop at 48 MP.
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            failure = "That photograph could not be opened."
            return
        }
        await read(data)
    }

    /// A photograph of a ticket (or a page, or a screenshot, read `whole`) through the reader.
    private func read(_ data: Data, whole: Bool = false) async {
        let size = PlateImage.intake
        guard let cg = await Task.detached(priority: .userInitiated, operation: {
                  PlateImage.decode(data, maxPixelSize: size)
              }).value else {
            failure = "That picture could not be opened."
            return
        }
        await read(cg, whole: whole)
    }

    /// The photograph, upright, through the reader: found, cropped, read, understood.
    private func read(_ cg: CGImage, whole: Bool = false) async {
        failure = nil
        image = UIImage(cgImage: cg)
        do {
            let result = try await StubReader.read(cg, whole: whole, progress: { stage in
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
        // Where it was, as a place: the venue normalised and its circuit, from the pass's issuer if there was one (ADR-024).
        let place = Venue.resolve(cinema: draft.cinema.nilIfEmpty, organization: draft.organization.nilIfEmpty)
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
            confidence: reading == nil ? 1 : draft.confidence,
            venue: place.venue,
            circuit: place.circuit
        )
        context.insert(stub)
        if let drawer { Cabinet.file(stub, in: drawer, among: everyStub + [stub]) }
        // Not dismissed: the stub is in the drawer, and now its edition is printed.
        withAnimation(reduceMotion ? Motion.plain : Motion.place) { kept = stub }
    }

    /// The press: the kept stub's copy of its edition, printed pass by pass, with the stub as scanned on its back.
    private func press(_ stub: Stub) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Keepsake(stub: stub, copy: Copy(stub: stub, among: everyStub), turned: $keptTurned, pressesOnAppear: true)
                Button { dismiss() } label: {
                    HStack(spacing: 8) {
                        Text("Into the drawer")
                        Image(systemName: "arrow.down").font(.system(size: 14, weight: .medium))
                    }
                }
                .buttonStyle(.stub(.ink))
            }
            .padding(20)
        }
        .transition(.opacity)
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
            Text(label).font(Type.words(15)).foregroundStyle(Ink.ink.opacity(0.75))
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
