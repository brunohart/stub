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
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Keepsake(stub: stub, copy: copy, turned: $turned)
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
                        Text("Edition: \(edition.described.lowercased()) · \(edition.directedBy == .model ? "chosen by the on-device model" : "drawn from the title")")
                            .font(Type.numbers(11)).foregroundStyle(Ink.grey)
                            .fixedSize(horizontal: false, vertical: true)
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
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
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
        #endif
    }

    /// This stub's copy of its edition, counted against the drawer.
    private var copy: Copy { Copy(stub: stub, among: drawer) }

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
