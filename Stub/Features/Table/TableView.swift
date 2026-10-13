import SwiftUI
import SwiftData

/// The drawer. Stubs laid out like they were tipped onto a table, not filed in a grid.
struct TableView: View {
    /// Animated, so a stub kept from the import sheet is dropped onto the table rather than appearing on it (ADR-022).
    @Query(sort: \Stub.createdAt, order: .reverse, animation: Motion.drop) private var stubs: [Stub]
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    /// The import sheet, blank or on a ticket handed over from outside (ADR-021).
    @State private var importing: ImportRequest?
    @State private var selected: Stub?
    @State private var showSeason = false
    /// The sentence and the numbers. Hand-counted at once, phrased by the model when it is idle.
    @State private var season = SeasonModel()
    /// The zoom transition's pair: the card on the table is the source, the detail grows out of it.
    @Namespace private var table
    /// Siri and the Shortcuts app come in through here: "Log a stub" sets `wantsImport`.
    private let reach = Reach.shared

    var body: some View {
        let summary = SeasonSummary(stubs: stubs)
        NavigationStack {
            ZStack {
                Paper()
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        header(summary)
                        if stubs.isEmpty {
                            EmptyDrawer { importing = ImportRequest() }
                        } else {
                            StubTable(stubs: stubs, table: table) { selected = $0 }
                        }
                    }
                    // The table is the width of the screen. Without this the stack shrinks to its widest
                    // non-greedy child (the one-line season sentence) and the columns size against that.
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
            // The two places to go from the drawer, at the bottom where a thumb is, named (ADR-022). The empty drawer has
            // its own one button, so the dock waits for the first stub.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !stubs.isEmpty {
                    Dock(films: summary.films) { showSeason = true } keep: { importing = ImportRequest() }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $importing, onDismiss: takeArrival) { request in
                ImportView(arrival: request.arrival)
            }
            .sheet(isPresented: $showSeason) {
                SeasonView(summary: season.summary, sentence: season.sentence)
            }
            // Re-count when the drawer changes; the previous sentence in progress is cancelled with the task.
            // The widget is told at the same moment: it prints the last card and has no clock of its own.
            .task(id: summary.key) {
                Reach.refreshWidgets()
                await season.update(summary)
            }
            .onChange(of: reach.wantsImport, initial: true) { _, wants in
                guard wants else { return }
                reach.wantsImport = false
                importing = ImportRequest()
            }
            // A link, a shortcut or a shared ticket. One at a time: an arrival while the sheet is open waits for it to close.
            .onChange(of: reach.arrival, initial: true) { _, _ in takeArrival() }
            .onOpenURL { url in reach.open(url) }
            // Whatever the share extension left while the app was away (ADR-023).
            .onChange(of: scenePhase, initial: true) { _, phase in
                if phase == .active { reach.drainInbox() }
            }
            #if DEBUG
            .task {
                // `-import`: open the import sheet after the seed has settled, so it can be screenshotted.
                guard DebugDrive.wantsImport else { return }
                do { try await Task.sleep(for: .seconds(DebugDrive.curtain)) } catch { return }
                importing = ImportRequest()
            }
            #endif
            .navigationDestination(item: $selected) { stub in
                StubDetailView(stub: stub)
                    .navigationTransition(.zoom(sourceID: stub.id, in: table))
            }
            #if DEBUG
            .task(id: stubs.count) {
                // `-drive`: press, open, hold and close on a timer, so the simulator can be filmed without hands.
                guard DebugDrive.requested, !DebugDrive.wantsPress, !stubs.isEmpty, !DebugDrive.shared.hasRun else { return }
                DebugDrive.shared.run(stubs: stubs) { selected = $0 }
            }
            .task(id: stubs.count) {
                // `-edition`: open the newest stub once the drawer has sat still after the seed, so its edition (and
                // with `-turned`, its back) can be screenshotted (ADR-015).
                guard DebugDrive.wantsEdition, !DebugDrive.requested || DebugDrive.wantsPress, !stubs.isEmpty else { return }
                do { try await Task.sleep(for: .seconds(2)) } catch { return }
                guard !DebugSeed.requested || DebugSeed.finished else { return }
                let named = DebugDrive.openTitle.flatMap { title in stubs.first { Release.key(for: $0.title) == Release.key(for: title) } }
                selected = named ?? stubs.first
            }
            .task(id: stubs.count) {
                // `-season`: open the season sheet once the drawer has sat still for a moment after the seed.
                guard DebugDrive.wantsSeason, !stubs.isEmpty else { return }
                do { try await Task.sleep(for: .seconds(2)) } catch { return }
                showSeason = true
            }
            #endif
        }
    }

    private func takeArrival() {
        guard importing == nil, reach.arrival != nil, let arrival = reach.take() else { return }
        importing = ImportRequest(arrival: arrival)
    }

    /// The drawer's label, centred over the table: the screen's own name for itself (ADR-022). The season's sentence is
    /// the season sheet's; the home shows what the drawer holds.
    private func header(_ summary: SeasonSummary) -> some View {
        DrawerLabel(summary: summary, years: DrawerLabel.years(of: stubs)) { showSeason = true }
            .frame(maxWidth: .infinity)
            .padding(.top, 18)
            .padding(.bottom, 6)
    }
}

/// Two uneven columns. Objects with spatial relationships, not items in a grid.
struct StubTable: View {
    let stubs: [Stub]
    let table: Namespace.ID
    let open: (Stub) -> Void
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The cards have been dealt. Once a launch: coming back from a stub does not deal them again.
    @State private var dealt = false

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                // At the accessibility sizes the narrow column would wrap every title to a word a line. The stubs
                // become a stack in the hand, one under the other, still tilted (ADR-013).
                column(stubs)
            } else {
                columns
            }
        }
        // A beat after the table is there, so the deal is seen and not lost in the launch's own fade.
        .task {
            guard !dealt else { return }
            if !reduceMotion { try? await Task.sleep(for: .milliseconds(260)) }
            dealt = true
        }
    }

    private var columns: some View {
        Group {
            let left = stubs.enumerated().filter { $0.offset % 2 == 0 }.map(\.element)
            let right = stubs.enumerated().filter { $0.offset % 2 == 1 }.map(\.element)
            // 1.15fr / 0.85fr, overlapping by 6pt. The container is the scroll view; 40pt is the table's own margin.
            HStack(alignment: .top, spacing: -6) {
                column(left)
                    .containerRelativeFrame(.horizontal) { width, _ in (width - 40) * 0.575 }
                column(right)
                    .containerRelativeFrame(.horizontal) { width, _ in (width - 40) * 0.425 }
                    .padding(.top, 44)
            }
        }
    }

    private func column(_ items: [Stub]) -> some View {
        VStack(spacing: 22) {
            ForEach(items) { stub in
                let order = stubs.firstIndex(of: stub) ?? 0
                StubCard(stub: stub)
                    .matchedTransitionSource(id: stub.id, in: table)
                    .onTapGesture { open(stub) }
                    // The press gesture keeps the card from being a Button; VoiceOver's double-tap comes in here.
                    .accessibilityAction { open(stub) }
                    // Dealt onto the table the first time the drawer opens, newest first, one after another.
                    .modifier(Dropped(airborne: !dealt, order: order))
                    .animation(reduceMotion ? nil : Motion.drop.delay(min(Double(order), 9) * 0.055), value: dealt)
                    .transition(reduceMotion ? .opacity : .modifier(active: Dropped(airborne: true, order: 0),
                                                                    identity: Dropped(airborne: false, order: 0)))
            }
        }
    }
}

/// A card in the air above the table, about to land (ADR-022): a little higher, a little larger, turned a few degrees
/// further than it will lie, and not yet there. Animated to `airborne: false` with `Motion.drop`, it falls, skids a
/// fraction of a degree past its own tilt, and settles. Alternate cards fall from alternate sides, as a hand deals them.
struct Dropped: ViewModifier {
    var airborne: Bool
    var order: Int

    func body(content: Content) -> some View {
        let side: Double = order.isMultiple(of: 2) ? -1 : 1
        content
            .rotationEffect(.degrees(airborne ? 4.5 * side : 0))
            .scaleEffect(airborne ? 1.06 : 1, anchor: .center)
            .offset(x: airborne ? 10 * side : 0, y: airborne ? -26 : 0)
            .opacity(airborne ? 0 : 1)
    }
}

struct EmptyDrawer: View {
    let add: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The blank stub breathes once when the drawer opens: one inhale, one settle, then still. Never a loop.
    @State private var breath: CGFloat = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            BlankStub(tilt: reduceMotion ? 0 : -1.1)
                .frame(width: 210, height: 118)
                .scaleEffect(breath, anchor: .bottomLeading)
                .padding(.top, 20)
                .task {
                    guard !reduceMotion else { return }
                    try? await Task.sleep(for: .milliseconds(400))
                    withAnimation(Motion.breath) { breath = 1.035 } completion: {
                        withAnimation(Motion.settle) { breath = 1 }
                    }
                }
            // The empty drawer's one sentence: what the drawer is for. Reading type, not the season's italic voice.
            Text(SeasonSummary().handSentence)
                .font(Type.reading(19))
                .foregroundStyle(Ink.ink.opacity(0.8))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: add) {
                HStack(spacing: 8) {
                    Image(systemName: "plus").font(.system(size: 15, weight: .medium))
                    Text("Keep the first stub")
                }
            }
            .buttonStyle(.stamp(.ink))
        }
    }
}

/// One presentation of the import sheet: blank, or on an arrival.
struct ImportRequest: Identifiable {
    let id = UUID()
    var arrival: Arrival?
}

/// The drawer's two doors, at the bottom of the table where a thumb is (ADR-022): the season, with how many films it
/// counts, and Keep a stub, the one act the app is for. Stamps on the parchment, which fades in under them; no glass.
struct Dock: View {
    let films: Int
    let season: () -> Void
    let keep: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: season) {
                HStack(spacing: 8) {
                    Text("The season")
                    Text("\(films)").font(Type.numbers(14)).foregroundStyle(Ink.grey)
                }
            }
            .buttonStyle(.stamp(.paper))
            .accessibilityLabel("The season, \(films) \(films == 1 ? "film" : "films")")
            .accessibilityHint("The numbers behind the sentence.")

            Button(action: keep) {
                HStack(spacing: 8) {
                    Image(systemName: "plus").font(.system(size: 15, weight: .medium))
                    Text("Keep a stub")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.stamp(.ink))
            .accessibilityHint("Photograph a ticket, or type one in.")
        }
        .padding(.horizontal, 20)
        .padding(.top, 44)
        .padding(.bottom, 8)
        .background {
            LinearGradient(stops: [.init(color: Ink.paper.opacity(0), location: 0), .init(color: Ink.paper.opacity(0.85), location: 0.38),
                                   .init(color: Ink.paper, location: 0.55)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .bottom)
        }
    }
}
