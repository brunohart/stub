import SwiftUI

/// One stub on the table. Tilted until touched; touching it makes it sit up straight.
struct StubCard: View {
    let stub: Stub
    @State private var pressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            plate
            VStack(alignment: .leading, spacing: 3) {
                Text(stub.title)
                    .displayText(17)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    if let d = stub.displayDate { Text(d).numberText(11) }
                    if let s = stub.seat { Text(s).numberText(11) }
                }
                if let cinema = stub.cinema {
                    Text(cinema).font(Type.words(12)).foregroundStyle(Ink.grey)
                }
            }
            .padding(.horizontal, 2)
        }
        .rotationEffect(.degrees(pressed || reduceMotion ? 0 : stub.tilt))
        .scaleEffect(pressed ? 1.02 : 1)
        .animation(Motion.stamp, value: pressed)
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressed = $0 }, perform: {})
        .sensoryFeedback(.impact(weight: .light), trigger: pressed) { _, new in new }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(stub.title), \(stub.displayDate ?? ""), \(stub.cinema ?? "")")
    }

    @ViewBuilder
    private var plate: some View {
        if let data = stub.imageData, let ui = UIImage(data: data) {
            Color.clear
                .frame(height: 150)
                .overlay(Image(uiImage: ui).resizable().scaledToFill())
                .clipped()
                .silkscreened(strength: pressed ? 0.15 : 1, seed: stub.tilt)
                .animation(Motion.settle, value: pressed)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Ink.navy.opacity(0.10))
                        .offset(x: 5, y: 6)
                )
        } else {
            BlankStub(tilt: 0, title: stub.title)
                .frame(height: 118)
        }
    }
}

/// The stub with no photograph. A perforated parchment card, printed with what we know.
struct BlankStub: View {
    var tilt: Double
    var title: String? = nil

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Ink.cream)
                .overlay(Grain(opacity: 0.08).clipShape(RoundedRectangle(cornerRadius: 3)))
                .overlay(perforation, alignment: .trailing)
                .background(RoundedRectangle(cornerRadius: 3).fill(Ink.orange.opacity(0.12)).offset(x: 5, y: 6))
            VStack(alignment: .leading, spacing: 6) {
                Text("ADMIT ONE").font(Type.numbers(10)).foregroundStyle(Ink.grey)
                if let title {
                    Text(title).displayText(15).lineLimit(3)
                }
            }
            .padding(12)
            .padding(.trailing, 28)
        }
        .rotationEffect(.degrees(tilt))
    }

    private var perforation: some View {
        VStack(spacing: 5) {
            ForEach(0..<14, id: \.self) { _ in
                Circle().fill(Ink.grey.opacity(0.35)).frame(width: 4, height: 4)
            }
        }
        .padding(.trailing, 22)
    }
}
