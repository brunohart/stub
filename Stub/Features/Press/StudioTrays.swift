import SwiftUI

/// The press's studio (ADR-046): two tools, each with its tray. Overprint pulls a pass through a screen with a stroke of
/// the finger; Stamp presses a rubber stamp of the night where a finger taps. Everything on the trays is drawn by the same
/// printer as the card, in the card's own inks, so what is offered is what will print.

/// The studio's two tools at rest on the bench: each a button with its mark drawn in the edition's inks.
struct StudioTools: View {
    let composition: Composition
    let open: (PressSession.Bench) -> Void

    var body: some View {
        // Side by side where they fit, one over the other at the large sizes (decision 005).
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { tools }
            VStack(spacing: 10) { tools }
        }
    }

    @ViewBuilder private var tools: some View {
        tool("Overprint", .pull, hint: "Opens the screens. Drag across the card to overprint it.") {
            ZStack {
                Circle().fill(composition.inks.color(.primary)).frame(width: 15, height: 15).offset(x: -4)
                Circle().fill(composition.inks.color(.secondary)).frame(width: 15, height: 15).offset(x: 4)
                    .blendMode(.multiply)
            }
            .compositingGroup()
        }
        tool("Stamp", .stamp, hint: "Opens the stamps. Tap the card to stamp it.") {
            // A date stamp's impression: a frame, a figure and a rule, pressed a little crooked.
            VStack(spacing: 2.5) {
                Text("06").font(Type.numbers(9)).foregroundStyle(composition.inks.color(.ink))
                Rectangle().fill(composition.inks.color(.ink)).frame(width: 12, height: 1.4)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 3)
            .overlay(RoundedRectangle(cornerRadius: 2.5).strokeBorder(composition.inks.color(.ink), lineWidth: 1.4))
            .rotationEffect(.degrees(-11))
        }
    }

    private func tool(_ title: String, _ bench: PressSession.Bench, hint: String, @ViewBuilder mark: () -> some View) -> some View {
        Button { open(bench) } label: {
            HStack(spacing: 10) {
                mark().frame(width: 24, height: 24).accessibilityHidden(true)
                Text(title).font(Type.display(16))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.stub(.paper))
        .accessibilityHint(hint)
    }
}

/// A tool's tray: its four or five choices, the three inks, and the way to take the last act off or put the tool down.
struct StudioTray: View {
    let session: PressSession
    /// The stub's photograph: with it, the trays offer a pass through the stub itself.
    var photo: UIImage? = nil
    let close: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // The tool's own line: its name, the way to take the last act off, and the way to put it down.
            HStack(alignment: .center, spacing: 12) {
                Text(session.bench == .pull ? "Overprint" : "Stamp").font(Type.display(20)).foregroundStyle(Ink.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                Button("Take it off") {
                    withAnimation(reduceMotion ? Motion.plain : Motion.settle) { session.takeOffLast() }
                }
                .buttonStyle(.stub(.quiet))
                .disabled(session.acts.isEmpty)
                .accessibilityHint("Takes the last pass or stamp off the card.")
                Button("Done", action: close).buttonStyle(.stub(.ink))
            }

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
