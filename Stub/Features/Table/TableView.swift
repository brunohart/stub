import SwiftUI
import SwiftData

/// The drawer. Stubs laid out like they were tipped onto a table, not filed in a grid.
struct TableView: View {
    @Query(sort: \Stub.createdAt, order: .reverse) private var stubs: [Stub]
    @Environment(\.modelContext) private var context
    @State private var isImporting = false
    @State private var selected: Stub?
    /// The zoom transition's pair: the card on the table is the source, the detail grows out of it.
    @Namespace private var table

    var body: some View {
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
            #endif
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            DisplayTitle("Stub", size: 44)
            Text(seasonLine)
                .font(Type.italic(20))
                .foregroundStyle(Ink.navy)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }

    /// The one italic sentence. Day 0: counted by hand. Day 5: written by the on-device model.
    private var seasonLine: String {
        switch stubs.count {
        case 0: return "Nothing in the drawer yet. Every film you saw in a room with strangers, kept here, read here, never uploaded."
        case 1: return "One stub. The drawer has started."
        default:
            let cinemas = Set(stubs.compactMap(\.cinema)).count
            let places = cinemas <= 1 ? "one cinema" : "\(spelled(cinemas).lowercased()) cinemas"
            return "\(spelled(stubs.count)) stubs across \(places)."
        }
    }

    private func spelled(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .spellOut
        return (f.string(from: NSNumber(value: n)) ?? "\(n)").capitalized
    }
}

/// Two uneven columns. Objects with spatial relationships, not items in a grid.
struct StubTable: View {
    let stubs: [Stub]
    let table: Namespace.ID
    let open: (Stub) -> Void

    var body: some View {
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

    private func column(_ items: [Stub]) -> some View {
        VStack(spacing: 22) {
            ForEach(items) { stub in
                StubCard(stub: stub)
                    .matchedTransitionSource(id: stub.id, in: table)
                    .onTapGesture { open(stub) }
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
                    .background(Ink.ink, in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }
    }
}
