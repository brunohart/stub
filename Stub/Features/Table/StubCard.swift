import SwiftUI

/// One stub on the table. Tilted until touched; touching it makes it sit up straight.
struct StubCard: View {
    let stub: Stub
    @State private var touched = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// A finger, or the Debug driver standing in for one.
    private var pressed: Bool {
        #if DEBUG
        return touched || DebugDrive.shared.pressedID == stub.id
        #else
        return touched
        #endif
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            plate
            VStack(alignment: .leading, spacing: 3) {
                // Never truncated: at the large Dynamic Type sizes a title takes the lines it needs.
                Text(stub.title)
                    .displayText(17)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    if let d = stub.displayDate { Text(d).numberText(11) }
                    if let s = stub.seat { Text(s).numberText(11) }
                }
                if let cinema = stub.cinema {
                    Text(cinema).font(Type.words(12)).foregroundStyle(Ink.grey)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 2)
        }
        // Touch-down: the stub sits up straight and lifts a little, overshooting once (Motion.stamp).
        // Reduce Motion: it never tilts, so there is nothing to straighten; the lift is critically damped.
        .rotationEffect(.degrees(pressed || reduceMotion ? 0 : stub.tilt))
        .scaleEffect(pressed ? 1.02 : 1)
        .animation(Motion.press(reduceMotion: reduceMotion), value: pressed)
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: .infinity, pressing: { touched = $0 }, perform: {})
        .sensoryFeedback(.impact(weight: .light), trigger: pressed) { _, new in new }
        // One element to VoiceOver, a button (the table adds the action), that says what the stub knows.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(stub.spokenLabel)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens the stub.")
    }

    @ViewBuilder
    private var plate: some View {
        if let ui = PlateImage.image(for: stub.id, in: .card, data: stub.imageData) {
            // The plate is the ticket's own shape, so a cropped stub reads as a stub. A photograph that
            // could not be cropped is still bounded: no taller than it is wide, no flatter than 2.6:1.
            let aspect = min(max(ui.size.width / max(ui.size.height, 1), 1), 2.6)
            Color.clear
                .aspectRatio(aspect, contentMode: .fit)
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
                    .accessibilityHidden(true)
                if let title {
                    Text(title).displayText(15).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
            .padding(.trailing, 28)
        }
        .rotationEffect(.degrees(tilt))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title.map { "A blank stub for \($0)." } ?? "A blank stub. The drawer is empty.")
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
