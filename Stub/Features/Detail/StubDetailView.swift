import SwiftUI
import SwiftData

/// One stub, close up, as two things (ADR-015): its edition, designed for the film's release, and on the back of it
/// the stub as it was scanned. The card arrives tilted, as the stub lay on the table, and sits up straight as it
/// grows (the zoom transition carries the frame, this view carries the rotation). Turn it over for the photograph;
/// hold the photograph and the silkscreen lifts, as it does in the drawer.
struct StubDetailView: View {
    @Bindable var stub: Stub
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The whole drawer, so the edition can say which viewing of its release this stub was.
    @Query private var drawer: [Stub]
    @State private var tilt: Double
    @State private var turned: Bool
    @State private var showRaw = false
    @State private var showProof = false
    /// The card has been taken to the press room.
    @State private var pressing = false
    /// The card is on a real table (ADR-018).
    @State private var inRoom = false
    @Namespace private var press
    @State private var shareable: Image?
    @Environment(\.dynamicTypeSize) private var typeSize
    private let editions = Editions.shared

    init(stub: Stub) {
        self.stub = stub
        _tilt = State(initialValue: stub.tilt)
        #if DEBUG
        _turned = State(initialValue: DebugDrive.wantsTurned)
        #else
        _turned = State(initialValue: false)
        #endif
    }

    var body: some View {
        ZStack {
            Paper()
            ScrollViewReader { scroller in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Keepsake(stub: stub, copy: copy, turned: $turned, takeToPress: { pressing = true }, pressSource: press)
                            .rotationEffect(.degrees(reduceMotion ? 0 : tilt))

                        VStack(alignment: .leading, spacing: 6) {
                            Text(stub.title).displayText(34).fixedSize(horizontal: false, vertical: true)
                            if let cinema = stub.cinema {
                                Text(cinema).font(Type.reading(20)).foregroundStyle(Ink.ink.opacity(0.8))
                            }
                        }

                        // Four figures in a row; at the accessibility sizes they would not fit, so they stack.
                        let figures = AnyLayout(typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16)) : AnyLayout(HStackLayout(alignment: .top, spacing: 26)))
                        figures {
                            if let d = stub.displayDate { Figure("Date", d, spoken: stub.spokenDate) }
                            if let s = stub.seat { Figure("Seat", s) }
                            if let sc = stub.screen { Figure("Screen", sc.replacingOccurrences(of: "Screen ", with: "")) }
                            if let p = stub.displayPrice { Figure("Paid", p) }
                        }

                        Divider().overlay(Ink.ink.opacity(0.15))

                        Text("Read by \(stub.readBy == "foundation-models" ? "the on-device model" : stub.readBy) · confidence \(Int(stub.confidence * 100))%")
                            .font(Type.numbers(11)).foregroundStyle(Ink.grey)
                            .accessibilityLabel("Read by \(stub.readBy == "foundation-models" ? "the on-device model" : stub.readBy), \(Int(stub.confidence * 100)) percent confident.")

                        // Honest machinery for the edition too: what it is, and who chose it (DESIGN.md rule 7).
                        if let edition = editions.edition(for: stub.title) {
                            Text("Edition: \(edition.described.lowercased()) · \(edition.directedBy.words)")
                                .font(Type.numbers(11)).foregroundStyle(Ink.grey)
                                .fixedSize(horizontal: false, vertical: true)
                            // Only where the phone can find a table: the simulator and older phones never see it.
                            if RoomView.isSupported {
                                Button { inRoom = true } label: {
                                    Text("Put it on the table").font(Type.words(14)).foregroundStyle(Ink.ink)
                                        .frame(minHeight: 44)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityHint("Shows the edition at its real size on a table, through the camera.")
                            }
                        }

                        // What the press keeps: the whole difference between this card and the title's, as it is stored
                        // (ADR-016). A poster in about sixty bytes is the best evidence that a proof is not an image.
                        if let proof = editions.proof(for: stub.title) {
                            DisclosureGroup(isExpanded: $showProof) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(String(decoding: proof.json, as: UTF8.self))
                                        .font(Type.numbers(12)).foregroundStyle(Ink.ink.opacity(0.7))
                                        .fixedSize(horizontal: false, vertical: true)
                                        .textSelection(.enabled)
                                    Text("\(proof.json.count) bytes")
                                        .font(Type.numbers(11)).foregroundStyle(Ink.grey)
                                }
                                .padding(.top, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            } label: {
                                Text("What the press keeps").font(Type.words(14)).foregroundStyle(Ink.grey)
                            }
                            .tint(Ink.grey)
                            .id("keeps")
                        }

                        if !stub.rawText.isEmpty {
                            DisclosureGroup(isExpanded: $showRaw) {
                                Text(stub.rawText).font(Type.numbers(12)).foregroundStyle(Ink.ink.opacity(0.7)).padding(.top, 8)
                            } label: {
                                Text("What the reader saw").font(Type.words(14)).foregroundStyle(Ink.grey)
                            }
                            .tint(Ink.grey)
                        }

                        Button(role: .destructive) {
                            context.delete(stub)
                            dismiss()
                        } label: {
                            Text("Throw this stub away").font(Type.words(14)).foregroundStyle(Ink.rust)
                                .frame(minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 12)
                    }
                    .padding(20)
                    .padding(.bottom, 80)
                }
                #if DEBUG
                .task {
                    // `-keeps`: open what the press keeps and bring it on screen, so it can be screenshotted.
                    guard DebugDrive.wantsKeeps else { return }
                    do { try await Task.sleep(for: .seconds(1.5)) } catch { return }
                    showProof = true
                    do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
                    withAnimation(Motion.settle) { scroller.scrollTo("keeps", anchor: .center) }
                }
                #endif
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        // The press room: full screen, grown from the card, closed with the system's back.
        .navigationDestination(isPresented: $pressing) {
            PressRoom(stub: stub, copy: copy)
                .navigationTransition(.zoom(sourceID: "press", in: press))
        }
        .fullScreenCover(isPresented: $inRoom) {
            if let edition = editions.edition(for: stub.title) {
                let composition = Composition(edition: edition, copy: copy)
                RoomView(composition: composition, back: EditionBack(
                    composition: composition, photo: PlateImage.image(for: stub.id, in: .detail, data: stub.imageData),
                    tilt: stub.tilt, code: Aztec.mask(for: copy.message), pencil: Pencil(edition: edition),
                    signature: Signatures.shared.image))
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let shareable {
                    ShareLink(item: shareable, preview: SharePreview("An edition of \(stub.title)", image: shareable)) {
                        Label("Share the edition", systemImage: "square.and.arrow.up")
                    }
                    .tint(Ink.ink)
                }
            }
        }
        .onAppear {
            // Sits up straight as it grows. The zoom is the system's; the straightening is ours, on the same clock.
            withAnimation(Motion.settle) { tilt = 0 }
        }
        // The share is the front, whole, rendered once the edition is printed, at three times the card.
        .onChange(of: editions.edition(for: stub.title), initial: true) { _, edition in
            guard let edition else { return }
            shareable = Self.render(Composition(edition: edition, copy: copy))
        }
        #if DEBUG
        .onChange(of: DebugDrive.shared.turned) { _, now in turned = now }
        .task {
            // `-room`: set the card on the table once it is printed, as "Put it on the table" would on a phone that can.
            guard DebugDrive.wantsRoom else { return }
            do {
                while editions.edition(for: stub.title) == nil { try await Task.sleep(for: .milliseconds(250)) }
                try await Task.sleep(for: .seconds(1.5))
            } catch { return }
            inRoom = true
        }
        .task {
            // `-press`: carry the card on into the press room once it is printed, as a hold would.
            guard DebugDrive.wantsPress else { return }
            do {
                while editions.edition(for: stub.title) == nil { try await Task.sleep(for: .milliseconds(250)) }
                try await Task.sleep(for: .seconds(2.2))
            } catch { return }
            pressing = true
        }
        #endif
    }

    /// This stub's copy of its edition, counted against the drawer.
    private var copy: Copy {
        var copy = Copy(stub: stub, among: drawer)
        #if DEBUG
        // `-viewings` and `-age` stand in for a drawer with more of this film in it, and for the years (ADR-009).
        if let viewing = DebugDrive.viewings {
            copy.viewing = viewing
            copy.viewings = max(copy.viewings, viewing)
        }
        if let age = DebugDrive.age { copy.age = min(max(age, 0), Patina.oldest) }
        #endif
        return copy
    }

    /// The edition's front on a margin of parchment, lit a little from the side, as an image to share.
    private static func render(_ composition: Composition) -> Image? {
        let card = EditionFace(composition: composition, light: Light(tilt: CGPoint(x: 0.3, y: -0.2)))
            .padding(28)
            .background(Ink.paper)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        return renderer.uiImage.map { Image(uiImage: $0) }
    }
}

/// A number and its quiet label. Read aloud as "Seat, H12": the label first, then the value, and a date
/// in words rather than the printed "06 SEP 26".
struct Figure: View {
    let label: String
    let value: String
    var spoken: String?
    init(_ label: String, _ value: String, spoken: String? = nil) { self.label = label; self.value = value; self.spoken = spoken }
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value).numberText(15)
            Text(label).font(Type.words(11)).foregroundStyle(Ink.grey)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), \(spoken ?? value)")
    }
}
