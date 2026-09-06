import SwiftUI
import SwiftData

/// One stub, close up. The photograph lifts from silkscreen to colour when you hold it.
struct StubDetailView: View {
    @Bindable var stub: Stub
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var holding = false
    @State private var showRaw = false

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
                            .background(RoundedRectangle(cornerRadius: 3).fill(Ink.orange.opacity(0.14)).offset(x: 6, y: 7))
                            .rotationEffect(.degrees(holding ? 0 : stub.tilt * 0.6))
                            .animation(Motion.settle, value: holding)
                            .onLongPressGesture(minimumDuration: .infinity, pressing: { holding = $0 }, perform: {})
                            .sensoryFeedback(.impact(weight: .medium), trigger: holding) { _, new in new }
                    } else {
                        BlankStub(tilt: stub.tilt * 0.6, title: stub.title).frame(height: 160)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(stub.title).displayText(34).fixedSize(horizontal: false, vertical: true)
                        if let cinema = stub.cinema {
                            Text(cinema).font(Type.reading(20)).foregroundStyle(Ink.ink.opacity(0.8))
                        }
                    }

                    HStack(alignment: .top, spacing: 26) {
                        if let d = stub.displayDate { Figure("Date", d) }
                        if let s = stub.seat { Figure("Seat", s) }
                        if let sc = stub.screen { Figure("Screen", sc.replacingOccurrences(of: "Screen ", with: "")) }
                        if let p = stub.displayPrice { Figure("Paid", p) }
                    }

                    Divider().overlay(Ink.ink.opacity(0.15))

                    Text("Read by \(stub.readBy == "foundation-models" ? "the on-device model" : stub.readBy) · confidence \(Int(stub.confidence * 100))%")
                        .font(Type.numbers(11)).foregroundStyle(Ink.grey)

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
    }
}

/// A number and its quiet label.
struct Figure: View {
    let label: String
    let value: String
    init(_ label: String, _ value: String) { self.label = label; self.value = value }
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value).numberText(15)
            Text(label).font(Type.words(11)).foregroundStyle(Ink.grey)
        }
    }
}
