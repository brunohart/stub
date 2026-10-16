import SwiftUI

/// The press's studio (ADR-046): two tools, each with its tray. Overprint pulls a pass through a screen with a stroke of
/// the finger; Stamp presses a rubber stamp of the night where a finger taps. Everything on the trays is drawn by the same
/// printer as the card, in the card's own inks, so what is offered is what will print.

/// The press's tools, in one strip along the foot of the room (ADR-048): the genome's three choices and the studio's two
/// acts, each a mark drawn in the card's own inks over its name. The tool in hand rests on a raised slip of paper and its
/// tray rises above the strip; tapped again, it is put down. One row, as an editor's tools are, so the card keeps the room.
struct ToolStrip: View {
    let session: PressSession
    let choose: (PressSession.Bench) -> Void
    @Namespace private var slip
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var tools: [(bench: PressSession.Bench, name: String, value: String?)] {
        [(.movement, "Movement", session.edition.movement.rawValue.capitalized),
         (.inks, "Inks", session.inks.rawValue.capitalized),
         (.stock, "Stock", session.edition.stock.words),
         (.pull, "Overprint", nil),
         (.stamp, "Stamp", nil)]
    }

    var body: some View {
        // One row where the names fit; at the large sizes, three over two (decision 005).
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 2) { ForEach(tools, id: \.name) { tool($0) } }
            VStack(spacing: 2) {
                HStack(spacing: 2) { ForEach(tools.prefix(3), id: \.name) { tool($0) } }
                HStack(spacing: 2) { ForEach(tools.suffix(2), id: \.name) { tool($0) } }
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Ink.cream))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Ink.ink.opacity(0.08), lineWidth: 0.75))
        .sensoryFeedback(.selection, trigger: session.bench)
    }

    private func tool(_ tool: (bench: PressSession.Bench, name: String, value: String?)) -> some View {
        let open = session.bench == tool.bench
        return Button { choose(open ? .rest : tool.bench) } label: {
            VStack(spacing: 5) {
                mark(tool.bench)
                    .frame(width: 26, height: 22)
                    .opacity(open ? 1 : 0.82)
                    .accessibilityHidden(true)
                Text(tool.name)
                    .font(Type.words(12))
                    .foregroundStyle(open ? Ink.ink : Ink.grey)
                    .fixedSize()
            }
            .frame(maxWidth: .infinity, minHeight: 58)
            .background {
                if open {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(hex: 0xFCF9F2))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Ink.ink.opacity(0.1), lineWidth: 0.75))
                        .shadow(color: Color(hex: 0x3B2A12).opacity(0.14), radius: 3, x: 0, y: 2)
                        .matchedGeometryEffect(id: "slip", in: slip)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(reduceMotion ? Motion.plain : .spring(response: 0.34, dampingFraction: 0.78), value: session.bench)
        .accessibilityLabel(tool.value.map { "\(tool.name), \($0)" } ?? tool.name)
        .accessibilityAddTraits(open ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(open ? "Puts it down." : Self.hint(tool.bench))
    }

    private static func hint(_ bench: PressSession.Bench) -> String {
        switch bench {
        case .movement: "Opens the movements."
        case .inks: "Opens the inks."
        case .stock: "Opens the swatch book."
        case .pull: "Opens the screens. Drag across the card, or tap it, to overprint it."
        case .stamp: "Opens the stamps. Tap the card to stamp it."
        case .rest: ""
        }
    }

    /// Each tool's mark, in the card's own inks: what it changes, drawn small.
    @ViewBuilder private func mark(_ bench: PressSession.Bench) -> some View {
        let inks = session.composition.inks
        switch bench {
        case .movement:
            // A composition in miniature: a disc and a bar laid across it.
            ZStack {
                Circle().fill(inks.color(.primary)).frame(width: 15, height: 15).offset(x: 4, y: -2)
                Capsule().fill(inks.color(.ink)).frame(width: 22, height: 4).rotationEffect(.degrees(-24)).offset(y: 4)
            }
        case .inks:
            // The three inks, as drops on the slab.
            HStack(spacing: -4) {
                Circle().fill(inks.color(.primary)).frame(width: 12, height: 12)
                Circle().fill(inks.color(.secondary)).frame(width: 12, height: 12)
                Circle().fill(inks.color(.ink)).frame(width: 12, height: 12)
            }
            .overlay(Capsule().strokeBorder(Ink.ink.opacity(0.12), lineWidth: 0.5).padding(-1))
        case .stock:
            // A sheet of card with the light across it and a corner turned up, drawn in ink like the others.
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .fill(Color(hex: inks.groundIsLight ? inks.ground : inks.hex(.light)))
                    .overlay(LinearGradient(colors: [.white.opacity(0), .white.opacity(0.75), .white.opacity(0)],
                                            startPoint: .topLeading, endPoint: .bottomTrailing)
                        .clipShape(RoundedRectangle(cornerRadius: 2.5, style: .continuous)))
                    .overlay(RoundedRectangle(cornerRadius: 2.5, style: .continuous).strokeBorder(inks.color(.ink), lineWidth: 1.3))
                Path { p in
                    p.move(to: CGPoint(x: 0, y: 0)); p.addLine(to: CGPoint(x: 6, y: 6)); p.addLine(to: CGPoint(x: 0, y: 6)); p.closeSubpath()
                }
                .fill(inks.color(.primary))
                .frame(width: 6, height: 6)
                .offset(x: -1.3, y: 1.3)
            }
            .frame(width: 16, height: 21)
            .rotationEffect(.degrees(-8))
        case .pull:
            ZStack {
                Circle().fill(inks.color(.primary)).frame(width: 15, height: 15).offset(x: -4)
                Circle().fill(inks.color(.secondary)).frame(width: 15, height: 15).offset(x: 4).blendMode(.multiply)
            }
            .compositingGroup()
        case .stamp:
            // A date stamp's impression: a frame, a figure and a rule, pressed a little crooked.
            VStack(spacing: 2) {
                Text("06").font(Type.numbers(8)).foregroundStyle(inks.color(.ink))
                Rectangle().fill(inks.color(.ink)).frame(width: 11, height: 1.3)
            }
            .padding(.horizontal, 3.5)
            .padding(.vertical, 2.5)
            .overlay(RoundedRectangle(cornerRadius: 2.5).strokeBorder(inks.color(.ink), lineWidth: 1.3))
            .rotationEffect(.degrees(-11))
        case .rest:
            EmptyView()
        }
    }
}

/// A tool's tray: its four or five choices, the three inks, and the way to take the last act off or put the tool down.
struct StudioTray: View {
    let session: PressSession
    /// The stub's photograph: with it, the trays offer a pass through the stub itself.
    var photo: UIImage? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    if session.bench == .pull {
                        if let photo { stubTile(photo) }
                        ForEach(Act.Screen.allCases.filter { $0 != .stub }, id: \.self) { screen in
                            tile(screen.name, chosen: session.screen == screen,
                                 marks: Studio.marks([.pull(screen, in: session.inking, from: CGPoint(x: -60, y: 0), to: CGPoint(x: 60, y: 0))],
                                                     copy: session.copy, inks: session.composition.inks,
                                                     field: session.composition.posterField, title: session.copy.title),
                                 scale: 0.3) { session.screen = screen }
                        }
                    } else {
                        ForEach(Act.Stamp.allCases, id: \.self) { stamp in
                            tile(stamp.name, chosen: session.stamp == stamp,
                                 marks: Studio.marks([.stamp(stamp, in: session.inking, at: CGPoint(x: stamp == .postmark ? -36 : 0, y: 0))],
                                                     copy: session.copy, inks: session.composition.inks,
                                                     field: session.composition.posterField, title: session.copy.title),
                                 scale: stamp == .postmark ? 0.36 : 0.44) { session.stamp = stamp }
                        }
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 6)
            }
            .scrollClipDisabled()

            HStack(spacing: 6) {
                ForEach(Act.Inking.allCases, id: \.self) { inking in pot(inking) }
                Spacer(minLength: 8)
                Button("Take it off") {
                    withAnimation(reduceMotion ? Motion.plain : Motion.settle) { session.takeOffLast() }
                }
                .buttonStyle(.stub(.quiet))
                .disabled(session.acts.isEmpty)
                .accessibilityHint("Takes the last pass or stamp off the card.")
            }
        }
    }

    /// The stub's own screen: its photograph as it would print, in the chosen ink, on the card's stock.
    private func stubTile(_ photo: UIImage) -> some View {
        let c = session.composition
        let chosen = session.screen == .stub
        let light = EditionInks.luminance(c.inks.hex(c.posterField)) > 0.35
        let colour = c.inks.color(!light && session.inking == .ink ? .light : session.inking.role)
        return Button {
            withAnimation(reduceMotion ? Motion.plain : Motion.press(reduceMotion: false)) { session.screen = .stub }
        } label: {
            VStack(spacing: 6) {
                PhotoPasses.pass(.pull(.stub, in: session.inking, from: CGPoint(x: 0, y: 33), to: CGPoint(x: 66, y: 33)),
                                 photo: photo, colour: colour, light: light)
                    .frame(width: 66, height: 66)
                    .background(c.inks.color(c.posterField))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(chosen ? Ink.ink : Ink.ink.opacity(0.14), lineWidth: chosen ? 2 : 0.75))
                    .shadow(color: .black.opacity(chosen ? 0.18 : 0.06), radius: chosen ? 6 : 2, x: 0, y: chosen ? 4 : 1)
                    .scaleEffect(chosen ? 1.05 : 1)
                Text(Act.Screen.stub.name).font(Type.words(12)).foregroundStyle(chosen ? Ink.ink : Ink.grey).fixedSize()
            }
            .frame(minWidth: 66)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("The stub, its own photograph")
        .accessibilityAddTraits(chosen ? [.isButton, .isSelected] : .isButton)
    }

    /// One screen or stamp on the tray: its impression on a square of the card's own stock, its name under it.
    private func tile(_ name: String, chosen: Bool, marks: [Mark], scale: CGFloat, choose: @escaping () -> Void) -> some View {
        let c = session.composition
        return Button {
            withAnimation(reduceMotion ? Motion.plain : Motion.press(reduceMotion: false)) { choose() }
        } label: {
            VStack(spacing: 6) {
                Canvas { context, size in
                    var g = context
                    g.translateBy(x: size.width / 2, y: size.height / 2)
                    g.scaleBy(x: scale, y: scale)
                    let printer = Printer(composition: c)
                    for mark in marks { printer.draw(mark, into: g, colour: c.inks.color(mark.role)) }
                }
                .frame(width: 66, height: 66)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(c.inks.color(c.posterField)))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(chosen ? Ink.ink : Ink.ink.opacity(0.14), lineWidth: chosen ? 2 : 0.75))
                .shadow(color: .black.opacity(chosen ? 0.18 : 0.06), radius: chosen ? 6 : 2, x: 0, y: chosen ? 4 : 1)
                .scaleEffect(chosen ? 1.05 : 1)
                Text(name).font(Type.words(12)).foregroundStyle(chosen ? Ink.ink : Ink.grey).fixedSize()
            }
            .frame(minWidth: 66)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .accessibilityAddTraits(chosen ? [.isButton, .isSelected] : .isButton)
    }

    static func name(of inking: Act.Inking) -> String {
        switch inking {
        case .primary: "First ink"
        case .secondary: "Second ink"
        case .ink: "The type's ink"
        }
    }

    /// One of the card's three inks, as a pot of it: chosen, ringed.
    private func pot(_ inking: Act.Inking) -> some View {
        let chosen = session.inking == inking
        let colour = session.composition.inks.color(inking.role)
        return Button { session.inking = inking } label: {
            Circle().fill(colour)
                .overlay(Circle().fill(LinearGradient(colors: [.white.opacity(0.35), .clear], startPoint: .topLeading, endPoint: .center)))
                .overlay(Circle().strokeBorder(Ink.ink.opacity(0.18), lineWidth: 0.75))
                .frame(width: 26, height: 26)
                .padding(4)
                .overlay(Circle().strokeBorder(Ink.ink, lineWidth: chosen ? 1.8 : 0))
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .animation(reduceMotion ? Motion.plain : Motion.settle, value: chosen)
        .accessibilityLabel(Self.name(of: inking))
        .accessibilityAddTraits(chosen ? [.isButton, .isSelected] : .isButton)
    }
}

/// The pass as the finger draws it: the screen's marks along the stroke so far, and the squeegee's blade where the finger is.
struct StrokePreview: View {
    let composition: Composition
    let act: Act

    var body: some View {
        Canvas { context, _ in
            var poster = context
            poster.clip(to: Path(Card.posterRect))
            let c = composition
            let marks = Studio.marks([act], copy: c.copy, inks: c.inks, field: c.posterField, title: c.copy.title)
            let printer = Printer(composition: c)
            for mark in marks { printer.draw(mark.faded(0.75), into: poster, colour: c.inks.color(mark.role)) }
            // The blade: across the stroke, at the finger.
            let end = CGPoint(x: act.x + act.dx, y: act.y + act.dy)
            let angle = atan2(act.dy, act.dx) + .pi / 2
            let half: CGFloat = 70
            var blade = Path()
            blade.move(to: CGPoint(x: end.x - cos(angle) * half, y: end.y - sin(angle) * half))
            blade.addLine(to: CGPoint(x: end.x + cos(angle) * half, y: end.y + sin(angle) * half))
            context.stroke(blade, with: .color(Ink.ink.opacity(0.55)), style: StrokeStyle(lineWidth: 5, lineCap: .round))
            context.stroke(blade, with: .color(.white.opacity(0.5)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
