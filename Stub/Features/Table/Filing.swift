import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// The ways a stub is moved and filed (ADR-026): held and carried within its year, dropped on another drawer's label, the
// drawer named, a drawer's stubs chosen from a list, and the year dividers they are filed between.

extension UTType {
    /// A stub carried by a finger, inside the app. Never offered to another app: what it carries is only an id.
    static let stubCard = UTType(exportedAs: "com.designedbybruno.stub.card")
}

/// The carried stub's item provider. It goes when the drag does, dropped or not, and says so: a drag let go anywhere that
/// takes nothing puts the stub back where it stood.
final class CarriedStub: NSItemProvider {
    var ended: (@MainActor @Sendable () -> Void)?

    convenience init(_ id: UUID) {
        self.init()
        registerDataRepresentation(forTypeIdentifier: UTType.stubCard.identifier, visibility: .ownProcess) { done in
            done(Data(id.uuidString.utf8), nil)
            return nil
        }
    }

    deinit {
        if let ended { Task { @MainActor in ended() } }
    }
}

/// A card under a carried stub. Entering it moves the carried stub to its place, at once, so the drawer makes room as the
/// finger goes; a card of another year will not take it, and says so.
struct ReorderDrop: DropDelegate {
    let target: UUID
    let sameYear: (UUID, UUID) -> Bool
    @Binding var working: [UUID]?
    let carried: UUID?
    let commit: () -> Void
    /// Told when the carried stub is over a card: it is moving, not held for its menu (ADR-035).
    var moved: () -> Void = {}

    func validateDrop(info: DropInfo) -> Bool { info.hasItemsConforming(to: [.stubCard]) && carried != nil }

    func dropEntered(info: DropInfo) {
        moved()
        guard let carried, let order = working else { return }
        let next = Cabinet.move(carried, to: target, in: order, sameYear: sameYear)
        guard next != order else { return }
        withAnimation(Motion.place) { working = next }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        moved()
        guard let carried else { return DropProposal(operation: .cancel) }
        return DropProposal(operation: carried == target || sameYear(carried, target) ? .move : .forbidden)
    }

    func performDrop(info: DropInfo) -> Bool {
        commit()
        return true
    }
}

/// The table itself, round and between the cards: a stub let go there stays where the drawer made room for it.
struct SettleDrop: DropDelegate {
    let carried: UUID?
    let commit: () -> Void
    var moved: () -> Void = {}
    func validateDrop(info: DropInfo) -> Bool { info.hasItemsConforming(to: [.stubCard]) && carried != nil }
    func dropEntered(info: DropInfo) { moved() }
    func dropUpdated(info: DropInfo) -> DropProposal? { moved(); return DropProposal(operation: .move) }
    func performDrop(info: DropInfo) -> Bool { commit(); return true }
}

/// A drawer's label in the rail. A stub held over it opens the drawer a little; let go, it is filed.
struct FileDrop: DropDelegate {
    let id: String
    @Binding var over: String?
    let file: () -> Void
    func validateDrop(info: DropInfo) -> Bool { info.hasItemsConforming(to: [.stubCard]) }
    func dropEntered(info: DropInfo) { over = id }
    func dropExited(info: DropInfo) { if over == id { over = nil } }
    /// A move, not a copy: no badge on the stub, which is let go into the drawer as it would be into a real one.
    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }
    func performDrop(info: DropInfo) -> Bool {
        over = nil
        file()
        return true
    }
}

/// The cabinet's other drawers, come down from the top of the screen while a stub is held (ADR-026): their labels, small,
/// each one a place to let it go. A blank one makes a new drawer; in a drawer the person made, the last one takes the stub
/// back out of it.
struct CabinetRail: View {
    struct Target: Identifiable {
        let id: String
        let typed: DrawerLabel.Typed
        let file: () -> Void
    }

    let targets: [Target]
    /// Shown when the open drawer is one the person made: let go here and the stub leaves it.
    var takeOut: (name: String, act: () -> Void)?
    @State private var over: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let scale: CGFloat = 0.62

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("File it in a drawer")
                .font(Type.words(13)).foregroundStyle(Ink.grey)
                .padding(.horizontal, 20)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(targets) { target in
                        DrawerLabel(target.typed, open: over == target.id) {}
                            .scaleEffect(scale)
                            .frame(width: DrawerLabel.size.width * scale, height: DrawerLabel.size.height * scale)
                            .onDrop(of: [.stubCard], delegate: FileDrop(id: target.id, over: $over, file: target.file))
                    }
                    if let takeOut {
                        VStack(spacing: 3) {
                            Image(systemName: "tray.and.arrow.up").font(.system(size: 17))
                            Text("Take it out of \(takeOut.name)").font(Type.words(12)).lineLimit(2).multilineTextAlignment(.center)
                        }
                        .foregroundStyle(over == "out" ? Ink.paper : Ink.rust)
                        .frame(width: 120, height: DrawerLabel.size.height * scale)
                        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(over == "out" ? Ink.rust : Ink.cream))
                        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Ink.rust.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                        .scaleEffect(over == "out" ? 1.06 : 1)
                        .animation(Motion.press(reduceMotion: reduceMotion), value: over)
                        .onDrop(of: [.stubCard], delegate: FileDrop(id: "out", over: $over, file: takeOut.act))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
            .scrollClipDisabled()
        }
        .padding(.top, 8)
        .padding(.bottom, 14)
        .background {
            LinearGradient(stops: [.init(color: Ink.paper, location: 0), .init(color: Ink.paper, location: 0.8),
                                   .init(color: Ink.paper.opacity(0), location: 1)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .top)
        }
        .accessibilityElement(children: .contain)
    }
}

/// A year of the drawer as a folder of card stock (ADR-026): a tab with the year on it, rising from the folder's back, the
/// tabs stepping along from year to year, left, middle, right, as a box of folders is cut. Tap the tab and the folder
/// closes: the year's stubs slide down into it, the front comes up over them with a soft thud, and what is filed shows
/// only as the tops of the tickets standing in it, with how many and which months on the front. Tap it again and it
/// opens. Only the drawer's own tabs close; a list of years to choose from (`toggle` nil) just files them.
struct YearFolder: View {
    let year: Int
    let count: Int
    var closed = false
    /// The tops of the tickets standing in the folder when it is closed, as colours, front to back.
    var slips: [Color] = []
    /// "FEB – NOV": the months the year's stubs span.
    var months: String? = nil
    var toggle: (() -> Void)? = nil

    static let manila = Color(hex: 0xEFE5CF)
    static let front = Color(hex: 0xE8DCC0)

    var body: some View {
        let step = year % 3
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                if step != 0 { Spacer(minLength: 0) }
                tab
                if step != 2 { Spacer(minLength: 0) }
            }
            .padding(.horizontal, 26)
            // The folder's back, the tab rising from it.
            Rectangle()
                .fill(Self.manila)
                .frame(height: 7)
                .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.55)).frame(height: 0.75) }
                .overlay(alignment: .bottom) { Rectangle().fill(Ink.ink.opacity(0.12)).frame(height: 0.75) }
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 3, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 3))
                .padding(.horizontal, 20)
            if closed {
                filed
                    .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity),
                                            removal: .move(edge: .bottom).combined(with: .opacity)))
            }
        }
        .padding(.top, 12)
        .background(Ink.paper)
        .clipped()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(year), \(count) \(count == 1 ? "stub" : "stubs")\(toggle == nil ? "" : closed ? ", closed" : ", open")")
        .accessibilityAddTraits(toggle == nil ? .isHeader : [.isHeader, .isButton])
        .accessibilityHint(toggle == nil ? "" : closed ? "Opens the year." : "Closes the year.")
        .accessibilityAction { toggle?() }
    }

    private var tab: some View {
        Button { toggle?() } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(verbatim: "\(year)").font(Type.numbers(16)).foregroundStyle(Ink.ink)
                Text("\(count)").font(Type.numbers(12)).foregroundStyle(Ink.grey)
                if toggle != nil {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Ink.grey)
                        .rotationEffect(.degrees(closed ? -90 : 0))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 9)
            .padding(.bottom, 7)
            .background(
                UnevenRoundedRectangle(topLeadingRadius: 9, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 9, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: 0xF6EEDC), Self.manila], startPoint: .top, endPoint: .bottom))
                    .overlay(
                        UnevenRoundedRectangle(topLeadingRadius: 9, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 9, style: .continuous)
                            .stroke(Ink.ink.opacity(0.12), lineWidth: 0.75)
                    )
                    .shadow(color: Color(hex: 0x3B2A12).opacity(0.08), radius: 2, x: 0, y: -1)
            )
            .frame(minHeight: 44, alignment: .bottom)
            .contentShape(Rectangle())
        }
        .buttonStyle(TabPress())
        .disabled(toggle == nil)
    }

    /// The closed folder: the tickets' tops standing out of it, and the front, with what is in it written on it.
    private var filed: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: -10) {
                ForEach(Array(slips.prefix(7).enumerated()), id: \.offset) { i, colour in
                    UnevenRoundedRectangle(topLeadingRadius: 3, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 3, style: .continuous)
                        .fill(colour)
                        .overlay(alignment: .top) {
                            // The ticket's perforation, just showing above the folder's front.
                            HStack(spacing: 3) {
                                ForEach(0..<8, id: \.self) { _ in Circle().fill(Ink.ink.opacity(0.18)).frame(width: 1.6, height: 1.6) }
                            }
                            .padding(.top, 5)
                        }
                        .overlay(UnevenRoundedRectangle(topLeadingRadius: 3, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 3,
                                                        style: .continuous).stroke(Ink.ink.opacity(0.12), lineWidth: 0.5))
                        .frame(width: 64, height: CGFloat(16 + (i * 7) % 9))
                        .rotationEffect(.degrees(Double((i * 5) % 7) * 0.5 - 1.5))
                        .shadow(color: .black.opacity(0.08), radius: 1, x: 0, y: 1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 34)
            .frame(height: 20, alignment: .bottom)
            .clipped()
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(count == 1 ? "One stub" : "\(SeasonSummary.spelled(count).capitalizedFirst) stubs")
                    .font(Type.words(14)).foregroundStyle(Ink.soft(0.75))
                if let months { Text(months).font(Type.numbers(12)).foregroundStyle(Ink.grey) }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .frame(height: 46)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(LinearGradient(colors: [Self.front, Color(hex: 0xE2D4B5)], startPoint: .top, endPoint: .bottom))
                    .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.5)).frame(height: 0.75).padding(.horizontal, 2) }
                    .shadow(color: Color(hex: 0x3B2A12).opacity(0.14), radius: 3, x: 0, y: 2)
            )
            .padding(.horizontal, 20)
            .contentShape(Rectangle())
            .onTapGesture { toggle?() }
        }
        .padding(.bottom, 14)
    }
}

/// The tab pressed: it goes down a touch into the folder, and the tap lands at contact.
private struct TabPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { TabPressed(configuration: configuration) }
}

private struct TabPressed: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        configuration.label
            .offset(y: configuration.isPressed ? 2 : 0)
            .brightness(configuration.isPressed ? -0.03 : 0)
            .animation(configuration.isPressed ? Motion.touchDown : Motion.press(reduceMotion: reduceMotion), value: configuration.isPressed)
            .sensoryFeedback(.impact(flexibility: .solid, intensity: 0.45), trigger: configuration.isPressed) { _, now in now }
    }
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}

/// Tickets or editions: what the drawer shows, as one control with a sliding thumb (ADR-029).
struct FacePicker: View {
    @Binding var face: DrawerFace

    var body: some View {
        Segmented(options: DrawerFace.allCases, selection: $face) { option in
            (option.name, option == .ticket ? "ticket" : "rectangle.portrait.on.rectangle.portrait")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Show the drawer as")
    }
}

/// Naming a drawer: the label in its holder, the name typed onto its card as it is typed, a key's tap under each letter.
struct NameDrawerSheet: View {
    let title: String
    let done: (String) -> Void
    @State private var name: String
    @FocusState private var typing: Bool
    @Environment(\.dismiss) private var dismiss

    init(title: String, name: String = "", done: @escaping (String) -> Void) {
        self.title = title
        self.done = done
        _name = State(initialValue: name)
    }

    var body: some View {
        VStack(spacing: 22) {
            Text(title).font(Type.display(19)).foregroundStyle(Ink.ink)
            DrawerLabel(name.isEmpty ? .blank : .made(name: name, films: 0, years: nil)) { typing = true }
                .allowsHitTesting(false)
            TextField("Festival 2025, With Mum, Wong Kar-wai", text: $name)
                .font(Type.words(17))
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .focused($typing)
                .onSubmit(finish)
                .padding(.vertical, 10)
                .overlay(alignment: .bottom) { Rectangle().fill(Ink.ink.opacity(0.18)).frame(height: 1) }
                .padding(.horizontal, 24)
            HStack(spacing: 14) {
                Button("Cancel") { dismiss() }.buttonStyle(.stub(.quiet))
                Button(action: finish) { Text("Label the drawer").frame(maxWidth: .infinity) }
                    .buttonStyle(.stub(.ink))
                    .disabled(Cabinet.name(name) == nil)
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 26)
        .frame(maxWidth: .infinity)
        .background(Paper())
        .sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.35), trigger: name)
        .presentationDetents([.height(340)])
        .presentationBackground(Ink.paper)
        .onAppear { typing = true }
    }

    private func finish() {
        guard let named = Cabinet.name(name) else { return }
        done(named)
        dismiss()
    }
}

/// Choosing which stubs a drawer holds, from every stub, a year at a time: tap one to file it, tap again to take it out.
struct ChooseStubsSheet: View {
    @Bindable var drawer: StubDrawer
    let stubs: [Stub]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                    ForEach(Cabinet.sections(Cabinet.order(stubs, in: nil))) { year in
                        Section {
                            ForEach(year.stubs) { stub in row(stub) }
                        } header: {
                            YearFolder(year: year.year, count: year.stubs.count)
                        }
                    }
                }
                .padding(.bottom, 30)
            }
            .background(Paper())
            .navigationTitle(drawer.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.buttonStyle(.stub(.quiet))
                }
                .sharedBackgroundVisibility(.hidden)
            }
        }
        .presentationBackground(Ink.paper)
    }

    private func row(_ stub: Stub) -> some View {
        let filed = drawer.stubIDs.contains(stub.id)
        return Button {
            withAnimation(Motion.press(reduceMotion: reduceMotion)) {
                if filed { Cabinet.takeOut(stub.id, of: drawer) } else { Cabinet.file(stub, in: drawer, among: stubs) }
            }
            try? context.save()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: filed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(filed ? Ink.orange : Ink.greyMark)
                    .contentTransition(.symbolEffect(.replace))
                VStack(alignment: .leading, spacing: 2) {
                    Text(stub.title).displayText(16)
                    HStack(spacing: 8) {
                        if let d = stub.displayDate { Text(d).numberText(12) }
                        if let place = stub.venue ?? stub.cinema { Text(place).font(Type.words(12)).foregroundStyle(Ink.grey).lineLimit(1) }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: filed)
        .accessibilityAddTraits(filed ? .isSelected : [])
        .accessibilityHint(filed ? "Takes it out of \(drawer.name)." : "Files it in \(drawer.name).")
    }
}
