import SwiftUI
import SwiftData

/// One stub, close up. It arrives tilted, as it lay on the table, and sits up straight as it grows (the zoom
/// transition carries the frame, this view carries the rotation). Hold it and the silkscreen lifts to the
/// photograph while the orange plate slides back into register; a haptic marks the moment it lands.
struct StubDetailView: View {
    @Bindable var stub: Stub
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var holding = false
    @State private var registered = false
    @State private var tilt: Double
    @State private var showRaw = false
    @Environment(\.dynamicTypeSize) private var typeSize

    /// How far the orange plate missed by, at rest.
    private let misregistration = CGSize(width: 6, height: 7)

    init(stub: Stub) {
        self.stub = stub
        _tilt = State(initialValue: stub.tilt)
    }

    var body: some View {
        ZStack {
            Paper()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let data = stub.imageData, let ui = UIImage(data: data) {
                        Image(uiImage: ui)
                            .resizable().scaledToFit()
                            .silkscreened(strength: holding ? 0 : 1, seed: stub.tilt)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Ink.orange.opacity(0.14))
                                    .offset(holding ? .zero : misregistration)
                            )
                            .rotationEffect(.degrees(reduceMotion ? 0 : tilt))
                            .onLongPressGesture(minimumDuration: .infinity, pressing: hold, perform: {})
                            .sensoryFeedback(.impact(weight: .medium, intensity: 0.8), trigger: registered) { _, new in new }
                            .accessibilityLabel("The stub for \(stub.title), printed on parchment.")
                            .accessibilityHint("Hold to lift the print and see the photograph.")
                    } else {
                        BlankStub(tilt: reduceMotion ? 0 : tilt, title: stub.title).frame(height: 160)
                    }

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
        .onAppear {
            // Sits up straight as it grows. The zoom is the system's; the straightening is ours, on the same clock.
            withAnimation(Motion.settle) { tilt = 0 }
        }
        #if DEBUG
        .onChange(of: DebugDrive.shared.holding) { _, held in hold(held) }
        #endif
    }

    /// Touch-down lifts the print and slides the plate; the haptic fires when the plate is logically in
    /// register, not on touch-down, so the feedback is the landing rather than the reach.
    private func hold(_ pressing: Bool) {
        if pressing {
            withAnimation(reduceMotion ? Motion.plain : Motion.settle, completionCriteria: .logicallyComplete) {
                holding = true
            } completion: {
                if holding { registered = true }
            }
        } else {
            registered = false
            withAnimation(reduceMotion ? Motion.plain : Motion.settle) { holding = false }
        }
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
