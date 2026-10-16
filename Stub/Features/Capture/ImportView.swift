import SwiftUI
import SwiftData
import PhotosUI
import OSLog

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
    /// The draft the reader last put in front of the person. A later answer changes only the fields still as offered: the
    /// model improves the draft in place and never undoes a hand (decision 001).
    @State private var offered = StubDraft()
    /// The plate as the store keeps it, encoded off the main thread while the person reads the draft, so Keep does not
    /// spend its tap compressing a photograph (decision 004: Kept).
    @State private var plateData: Data?
    /// Keep tapped and the press not yet on screen (`Signposts.pressed`).
    @State private var pressing: OSSignpostIntervalState?
    /// The ticket's shape, when the person put right what the reader read: theirs to send, so the next one reads right
    /// (docs/decisions/006-network-without-data.md).
    @State private var shape: TicketFormat?
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
            // Gone while the viewfinder is up, not faded under it: no controls behind the camera, for VoiceOver or the
            // audit (decision 005). Everything the form shows lives here, so nothing is lost when it comes back.
            if !onCamera {
                form.transition(.opacity)
            }
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
        // The plate encoded as the store keeps it while the person reads the draft, not on the tap that keeps it.
        .task(id: image.map(ObjectIdentifier.init)) {
            plateData = nil
            guard let picture = image else { return }
            let data = await Task.detached(priority: .userInitiated) { picture.jpegData(compressionQuality: 0.82) }.value
            if image === picture { plateData = data }
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
                                    .accessibilityIdentifier("artwork")
                            } else if arrival == nil {
                                picker
                            }
                            if let arrival {
                                Label(arrival.sentence(postersOn: Posters.shared.on), systemImage: arrival.symbol)
                                    .font(Type.words(15)).foregroundStyle(Ink.soft(0.75))
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
                                        .foregroundStyle(Ink.soft(0.7))
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
                    .accessibilityIdentifier("import.keep")
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
            #if DEBUG || PERF
            // `-stage-keep`: Keep pressed a moment after the draft is keepable, so Instruments can record the press opening
            // without a test runner attached (decision 004).
            .onChange(of: draft.isUsable) { _, usable in
                guard usable, ProcessInfo.processInfo.arguments.contains("-stage-keep"), kept == nil else { return }
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    Stage.log.info("stage: keep")
                    if kept == nil { keep() }
                }
            }
            #endif
            .task {
                guard let arrival, !received else { return }
                received = true
                await receive(arrival)
                #if DEBUG || PERF
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
                    .font(Type.numbers(12)).foregroundStyle(Ink.grey)
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
            offered = known
        case .page(let data, let whole):
            await read(data, whole: whole)
        case .document(let page, let lines):
            // The PDF's own words to the parsers, its page to the plate: no OCR (BEDIP-218).
            let clock = CaptureClock()
            guard let cg = PlateImage.decode(page, maxPixelSize: PlateImage.intake) else { return }
            image = UIImage(cgImage: cg)
            let result = await StubReader.read(StubReading(lines: lines), plate: cg, progress: { stage in
                withAnimation(reduceMotion ? Motion.plain : Motion.settle) { self.stage = stage }
            }, partial: { snapshot in
                offer(snapshot, clock: clock)
            })
            reading = result.reading
            settle(result.draft, clock: clock)
            if result.cropped { withAnimation(Motion.place) { image = UIImage(cgImage: result.plate) } }
        case .text(let lines):
            // A booking's words: straight to the parsers, no picture to read or keep (docs/decisions/002-surfaces.md).
            let clock = CaptureClock()
            let words = StubReading(lines: lines)
            reading = words
            let final = await StubReader.understand(words, progress: { stage in
                withAnimation(reduceMotion ? Motion.plain : Motion.settle) { self.stage = stage }
            }, partial: { snapshot in
                offer(snapshot, clock: clock)
            })
            settle(final, clock: clock)
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
        let clock = CaptureClock()
        let size = PlateImage.intake
        guard let cg = await Task.detached(priority: .userInitiated, operation: {
                  PlateImage.decode(data, maxPixelSize: size)
              }).value else {
            failure = "That picture could not be opened."
            clock.finished()
            return
        }
        await read(cg, whole: whole, clock: clock)
    }

    /// The photograph, upright, through the reader: found, cropped, read, understood.
    private func read(_ cg: CGImage, whole: Bool = false, clock: CaptureClock? = nil) async {
        let clock = clock ?? CaptureClock()
        failure = nil
        image = UIImage(cgImage: cg)
        do {
            let result = try await StubReader.read(cg, whole: whole, progress: { stage in
                withAnimation(Motion.settle) { self.stage = stage }
            }, partial: { snapshot in
                // The rules' draft the moment it has a title; or, while it has none, the model's as it forms, title first.
                offer(snapshot, clock: clock)
            })
            reading = result.reading
            settle(result.draft, clock: clock)
            // Show the ticket, not the table it was lying on.
            if result.cropped { withAnimation(Motion.place) { image = UIImage(cgImage: result.plate) } }
        } catch {
            stage = .done
            failure = "No printed text found. Type it in instead."
            reading = nil
            clock.finished()
        }
    }

    /// A draft from the reader, put in front of the person: every field they have not changed takes it.
    private func offer(_ next: StubDraft, clock: CaptureClock) {
        withAnimation(Motion.place) { draft = draft.adopting(next, unchangedFrom: offered) }
        offered = next
        clock.offered(draft)
    }

    /// The reader's last word. Offered like any other draft; and if the person kept the stub before it came, the kept stub
    /// takes it into the fields it left empty, and nothing else (a kept stub is never rewritten under the person).
    private func settle(_ final: StubDraft, clock: CaptureClock) {
        offer(final, clock: clock)
        clock.finished()
        guard let kept else { return }
        if kept.cinema == nil, let cinema = final.cinema.nilIfEmpty {
            kept.cinema = cinema
            let place = Venue.resolve(cinema: cinema, organization: final.organization.nilIfEmpty)
            kept.venue = kept.venue ?? place.venue
            kept.circuit = kept.circuit ?? place.circuit
        }
        if kept.screenedAt == nil { kept.screenedAt = final.screenedAt }
        if kept.screen == nil { kept.screen = final.screen.nilIfEmpty }
        if kept.seat == nil { kept.seat = final.seat.nilIfEmpty }
        if kept.price == nil, let price = final.price { kept.price = price; kept.currency = final.currency.nilIfEmpty }
        try? context.save()
    }

    private func keep() {
        let saving = Signposts.capture.beginInterval(Signposts.kept)
        pressing = Signposts.capture.beginInterval(Signposts.pressed)
        // The person corrected the reader: the ticket's shape is worth offering back (never its contents).
        if let reading, draft.corrected(from: offered) { shape = TicketFormat.of(reading, kept: draft) }
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
            imageData: plateData ?? image?.jpegData(compressionQuality: 0.82),
            readBy: reading == nil ? "manual" : draft.readBy,
            confidence: reading == nil ? 1 : draft.confidence,
            venue: place.venue,
            circuit: place.circuit
        )
        context.insert(stub)
        if let drawer { Cabinet.file(stub, in: drawer, among: everyStub + [stub]) }
        // Saved now, not at the next autosave: the phone goes back in a pocket the moment this is tapped (decision 001).
        try? context.save()
        // The cinema's poster, if its link handed one over: fetched now, once, and printed as it arrives (ADR-050).
        if let poster = draft.poster { Posters.shared.supplied(poster, title: stub.title) }
        Signposts.capture.endInterval(Signposts.kept, saving)
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
                if let shape { ShapeOffer(shape: shape) }
            }
            .padding(20)
        }
        .transition(.opacity)
        .onAppear {
            if let pressing { Signposts.capture.endInterval(Signposts.pressed, pressing) }
            pressing = nil
        }
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
            // Wraps rather than scrolling sideways, so a long cinema's name is all there at any size (decision 005). One
            // line of words all the same: a return is not part of a ticket.
            TextField("", text: $text, axis: .vertical)
                .font(font)
                .foregroundStyle(Ink.ink)
                .textInputAutocapitalization(.words)
                .frame(minHeight: 44)
                .accessibilityLabel(label)
                .onChange(of: text) { _, now in
                    if now.contains("\n") { text = now.replacingOccurrences(of: "\n", with: "") }
                }
            Rectangle().fill(Ink.ink.opacity(0.18)).frame(height: 1)
        }
    }
}

struct StageLine: View {
    let stage: StubReader.Stage
    var body: some View {
        HStack(spacing: 10) {
            ProgressView().tint(Ink.orange)
            Text(label).font(Type.words(15)).foregroundStyle(Ink.soft(0.75))
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

/// After a kept stub the reader got wrong: one quiet line offering this cinema's ticket shape back, never what it said. It
/// opens Mail with the shape written out, so the person sees every word that would go, and sends it or doesn't. Infrequent,
/// optional and sent by hand each time: the App Store's optional-disclosure case (docs/decisions/006).
private struct ShapeOffer: View {
    let shape: TicketFormat
    static let address = "formats@designedbybruno.net"

    var body: some View {
        if let mail = mail {
            Link(destination: mail) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "envelope").font(.system(size: 13))
                    Text("Stub misread this cinema's ticket. Send its shape, never what it says, so the next one reads right.")
                        .multilineTextAlignment(.leading)
                }
                .font(Type.words(13)).foregroundStyle(Ink.soft(0.7))
                .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityHint("Opens Mail with the ticket's shape written out. Nothing is sent unless you send it.")
        }
    }

    private var mail: URL? {
        let body = "This is the shape of a cinema ticket Stub misread: every value replaced, nothing the ticket said.\n\n" + shape.text
        var parts = URLComponents()
        parts.scheme = "mailto"
        parts.path = Self.address
        parts.queryItems = [URLQueryItem(name: "subject", value: "A ticket's shape for Stub"), URLQueryItem(name: "body", value: body)]
        return parts.url
    }
}
