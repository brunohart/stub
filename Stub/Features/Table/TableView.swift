import SwiftUI
import SwiftData

/// The drawer. Stubs laid out like they were tipped onto a table, not filed in a grid.
struct TableView: View {
    @Query(sort: \Stub.createdAt, order: .reverse) private var stubs: [Stub]
    @Environment(\.modelContext) private var context
    @State private var isImporting = false
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
                        header
                        if stubs.isEmpty {
                            EmptyDrawer { isImporting = true }
                        } else {
                            StubTable(stubs: stubs, table: table) { selected = $0 }
                        }
                    }
                    // The table is the width of the screen. Without this the stack shrinks to its widest
                    // non-greedy child (the one-line season sentence) and the columns size against that.
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 120)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { isImporting = true } label: {
                        Label("Add a stub", systemImage: "plus")
                    }
                    .tint(Ink.ink)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $isImporting) {
                ImportView()
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
                isImporting = true
            }
            #if DEBUG
            .task {
                // `-import`: open the import sheet after the seed has settled, so it can be screenshotted.
                guard DebugDrive.wantsImport else { return }
                do { try await Task.sleep(for: .seconds(DebugDrive.curtain)) } catch { return }
                isImporting = true
            }
            #endif
            .navigationDestination(item: $selected) { stub in
                StubDetailView(stub: stub)
                    .navigationTransition(.zoom(sourceID: stub.id, in: table))
            }
            #if DEBUG
            .task(id: stubs.count) {
                // `-drive`: press, open, hold and close on a timer, so the simulator can be filmed without hands.
                guard DebugDrive.requested, !stubs.isEmpty, !DebugDrive.shared.hasRun else { return }
                DebugDrive.shared.run(stubs: stubs) { selected = $0 }
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            DisplayTitle("Stub", size: 44)
            // The one italic sentence. Counted by hand on Day 0; written by the on-device model from Day 4,
            // with the hand count as the floor (ADR-011). Tap it for the numbers.
            Button {
                if !stubs.isEmpty { showSeason = true }
            } label: {
                Text(season.sentence)
                    .font(Type.italic(20))
                    .foregroundStyle(Ink.navy)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                    .contentTransition(.opacity)
                    .animation(Motion.place, value: season.sentence)
            }
            .buttonStyle(.plain)
            .disabled(stubs.isEmpty)
            .frame(minHeight: 44, alignment: .topLeading)
            .accessibilityHint(stubs.isEmpty ? "" : "Opens the season: the numbers behind this sentence.")
        }
        .padding(.top, 4)
    }
}

/// Two uneven columns. Objects with spatial relationships, not items in a grid.
struct StubTable: View {
    let stubs: [Stub]
    let table: Namespace.ID
    let open: (Stub) -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if typeSize.isAccessibilitySize {
            // At the accessibility sizes the narrow column would wrap every title to a word a line. The stubs
            // become a stack in the hand, one under the other, still tilted (ADR-013).
            column(stubs)
        } else {
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
                StubCard(stub: stub)
                    .matchedTransitionSource(id: stub.id, in: table)
                    .onTapGesture { open(stub) }
                    // The press gesture keeps the card from being a Button; VoiceOver's double-tap comes in here.
                    .accessibilityAction { open(stub) }
            }
        }
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
            Button(action: add) {
                Text("Add the first stub")
                    .font(Type.words(17))
                    .foregroundStyle(Ink.paper)
                    .padding(.horizontal, 18).padding(.vertical, 12)
                    .frame(minHeight: 44)
                    .background(Ink.ink, in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }
    }
}
