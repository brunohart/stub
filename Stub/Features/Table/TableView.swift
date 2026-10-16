import SwiftUI
import SwiftData

/// The cabinet (ADR-026). One drawer open at a time, its brass label at the top among the others' (swipe along them to open
/// another; a blank one at the end makes a new drawer), and the drawer's stubs filed by year behind tabbed dividers, two to a
/// row. Tickets or editions, as the person chooses. Hold a stub and its menu opens: file it in a drawer or throw it away
/// (ADR-035). Hold it and move, and it is carried: within its year it goes where it is let go; let go on another drawer's
/// label, which comes down from the top while a stub is held, it is filed there.
struct TableView: View {
    /// Animated, so a stub kept from the import sheet is dropped onto the table rather than appearing on it (ADR-022).
    @Query(sort: \Stub.createdAt, order: .reverse, animation: Motion.drop) private var stubs: [Stub]
    @Query(sort: \StubDrawer.position) private var drawers: [StubDrawer]
    /// The name on Your card, for the initials on its button.
    @Query(filter: #Predicate<PressRecord> { $0.kind == "owner" }) private var owner: [PressRecord]
    @State private var showCard = false
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The drawer open: empty for the drawer of every stub, otherwise a made drawer's id. Kept between launches.
    @AppStorage("drawer.open") private var openID = ""
    /// Tickets or editions (ADR-026). Kept between launches.
    @AppStorage("drawer.face") private var face: DrawerFace = .ticket
    /// The import sheet, on a ticket handed over from outside (ADR-021).
    @State private var importing: ImportRequest?
    /// Keep a stub: the viewfinder, full screen, and the form it fills in (ADR-025).
    @State private var keeping: ImportRequest?
    @State private var selected: Stub?
    @State private var showSeason = false
    /// The sentence and the numbers. Hand-counted at once, phrased by the model when it is idle.
    @State private var season = SeasonModel()
    @State private var naming: Naming?
    @State private var choosing: StubDrawer?
    @State private var removing: StubDrawer?
    /// A stub its menu is throwing away, asked once (DESIGN.md rule 16).
    @State private var throwing: Stub?
    /// The stub a finger is carrying, and the drawer's order as it makes room for it.
    @State private var carried: UUID?
    @State private var working: [UUID]?
    /// The held stub has moved. A hold lifts the card for its menu and for carrying at once; the rail comes down and the
    /// shelf gives way only once the finger takes it somewhere, so a hold that ends in the menu leaves the drawer as it was.
    @State private var moving = false
    /// When the carried stub was last seen over the table. The system asks for the carried item more than once in a single
    /// hold (at the lift for the menu, again as the drag begins), so an item going away only puts the stub down once nothing
    /// has been seen moving for a moment. A box, so the drag's updates do not redraw the drawer.
    @State private var seen = CarryClock()
    /// Every stub's viewing of its release, counted once per change to the drawer rather than once per card (decision 004).
    @State private var viewings = Viewings()
    private var inHand: Bool { carried != nil && moving }
    /// Which label the shelf is showing: "every", a made drawer's id, or "new".
    @State private var page: String?
    /// Each plate's height on the shelf, which the shelf is as tall as (decision 005).
    @State private var plateHeights: [String: CGFloat] = [:]
    /// A line over the dock for a moment after something is filed.
    @State private var notice: String?
    /// The cards have been dealt. Once a launch: coming back from a stub does not deal them again.
    @State private var dealt = false
    /// The years closed into their folders, as "drawer/year", kept between launches.
    @AppStorage("drawer.closedYears") private var closedYears = ""
    @State private var folderTaps = 0
    @State private var folderThud: SensoryFeedback = .impact(weight: .medium)
    /// The zoom transition's pair: the card on the table is the source, the detail grows out of it.
    @Namespace private var table
    /// Siri and the Shortcuts app come in through here: "Log a stub" sets `wantsImport`.
    private let reach = Reach.shared

    enum Naming: Identifiable {
        case new(filing: UUID?)
        case rename(StubDrawer)
        var id: String {
            switch self {
            case .new: "new"
            case .rename(let d): d.id.uuidString
            }
        }
    }

    private var open: StubDrawer? { drawers.first { $0.id.uuidString == openID } }
    private var ownerName: String? {
        owner.max { $0.updatedAt < $1.updatedAt }.flatMap { String(data: $0.data, encoding: .utf8) }?.nilIfEmpty
    }
    private var members: [Stub] { Cabinet.members(of: open, among: stubs) }

    /// The open drawer's stubs as they stand, or as they stand while a carried stub is making room.
    private var shown: [Stub] {
        let ordered = Cabinet.order(members, in: open)
        guard let working else { return ordered }
        let byID = Dictionary(ordered.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        return working.compactMap { byID[$0] }
    }

    var body: some View {
        let summary = SeasonSummary(stubs: members)
        let _ = viewings.refresh(stubs)
        NavigationStack {
            ZStack(alignment: .top) {
                Paper()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                        header(summary)
                        content
                    }
                    .padding(.bottom, 32)
                }
                .accessibilityIdentifier("drawer.scroll")
                #if DEBUG || PERF
                .modifier(StagedScroll())
                #endif
                // A stub let go between cards stays where the drawer made room for it.
                .onDrop(of: [.stubCard], delegate: SettleDrop(carried: carried, commit: commitOrder, moved: startMoving))
                if inHand {
                    rail.transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            // Nothing scrolls under the clock: the parchment stands behind the status bar.
            .overlay(alignment: .top) {
                GeometryReader { proxy in
                    Ink.paper.frame(height: proxy.safeAreaInsets.top).offset(y: -proxy.safeAreaInsets.top)
                }
                .allowsHitTesting(false)
            }
            .animation(reduceMotion ? Motion.plain : Motion.place, value: inHand)
            .sensoryFeedback(.selection, trigger: working)
            .sensoryFeedback(folderThud, trigger: folderTaps)
            // The drawer's two doors, at the bottom where a thumb is, named (ADR-022). The empty drawer has its own one
            // button, so the dock waits for the first stub.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    if let notice {
                        Text(notice)
                            .font(Type.words(14)).foregroundStyle(Ink.soft(0.8))
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Ink.cream))
                            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Ink.ink.opacity(0.12), lineWidth: 0.75))
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .padding(.bottom, -30)
                            .zIndex(1)
                    }
                    if !stubs.isEmpty {
                        Dock(films: summary.films) { showSeason = true } keep: { keeping = ImportRequest(drawer: open) }
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(Motion.place, value: notice)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $importing, onDismiss: takeArrival) { request in
                ImportView(arrival: request.arrival, drawer: request.drawer)
            }
            .fullScreenCover(item: $keeping, onDismiss: takeArrival) { request in
                ImportView(drawer: request.drawer, startsWithCamera: true)
            }
            .sheet(isPresented: $showSeason) {
                SeasonView(summary: season.summary, sentence: season.sentence, drawer: open?.name,
                           rename: open.map { d in { showSeason = false; naming = .rename(d) } },
                           remove: open.map { d in { showSeason = false; removing = d } })
            }
            .sheet(item: $naming) { naming in
                switch naming {
                case .new(let filing):
                    NameDrawerSheet(title: "A new drawer") { name in make(name, filing: filing) }
                case .rename(let drawer):
                    NameDrawerSheet(title: "Rename the drawer", name: drawer.name) { name in
                        drawer.name = name
                        try? context.save()
                    }
                }
            }
            .sheet(item: $choosing) { drawer in
                ChooseStubsSheet(drawer: drawer, stubs: stubs)
            }
            .sheet(isPresented: $showCard) { YourCard() }
            .confirmationDialog(removing.map { "Take out the drawer “\($0.name)”?" } ?? "", isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }),
                                titleVisibility: .visible) {
                Button("Take the drawer out", role: .destructive) { if let removing { remove(removing) } }
            } message: {
                Text("Its stubs stay in the drawer of every stub.")
            }
            .confirmationDialog(throwing.map { "Throw away \($0.title)?" } ?? "", isPresented: Binding(get: { throwing != nil }, set: { if !$0 { throwing = nil } }),
                                titleVisibility: .visible) {
                Button("Throw it away", role: .destructive) { if let throwing { throwAway(throwing) } }
            } message: {
                Text("The stub and its photograph go from every drawer, here and in your iCloud. Its edition stays with the film.")
            }
            // Re-count when the drawer changes; the previous sentence in progress is cancelled with the task.
            // The widget is told at the same moment: it prints the last card and has no clock of its own.
            .task(id: summary.key) {
                Reach.refreshWidgets()
                await season.update(summary)
            }
            // Editions the press has not printed yet are printed in turn, one at a time, while the drawer shows editions.
            .task(id: face == .edition ? members.count : -1) {
                guard face == .edition else { return }
                await printMissing()
            }
            // A stub found in Spotlight, or asked for by Siri or a shortcut (decision 002).
            .onChange(of: reach.wantsStub, initial: true) { _, wanted in
                guard let wanted else { return }
                reach.wantsStub = nil
                guard let stub = stubs.first(where: { $0.id == wanted }) else { return }
                if !members.contains(where: { $0.id == wanted }) {
                    openID = ""
                    page = "every"
                }
                selected = stub
            }
            // The drawer in Spotlight's index, a moment after it last changed (decision 002).
            .task(id: viewings.count) {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                await Spotlight.index(stubs)
            }
            .onChange(of: reach.wantsImport, initial: true) { _, wants in
                guard wants else { return }
                reach.wantsImport = false
                keeping = ImportRequest()
            }
            // A link, a shortcut or a shared ticket. One at a time: an arrival while the sheet is open waits for it to close.
            .onChange(of: reach.arrival, initial: true) { _, _ in takeArrival() }
            // The widget's card opens its stub (ADR-027); a link or a shortcut goes to Reach.
            .onOpenURL { url in
                // The Lock Screen's control: straight to the viewfinder, as the dock's Keep a stub (decision 002).
                if StubLink.isKeep(url) {
                    keeping = ImportRequest(drawer: open)
                    return
                }
                guard let id = StubLink.id(in: url) else {
                    reach.open(url)
                    return
                }
                guard let stub = stubs.first(where: { $0.id == id }) else { return }
                if !members.contains(where: { $0.id == id }) {
                    openID = ""
                    page = "every"
                }
                selected = stub
            }
            // Whatever the share extension left while the app was away (ADR-023).
            .onChange(of: scenePhase, initial: true) { _, phase in
                guard phase == .active else { return }
                #if DEBUG || PERF
                // The preview lets the cards be dealt before the stub arrives.
                if DebugDrive.wantsPreview {
                    Task { try? await Task.sleep(for: .seconds(2.6)); reach.drainInbox() }
                    return
                }
                #endif
                reach.drainInbox()
            }
            // A drawer taken out on another phone, or this one: back to the drawer of every stub.
            .onChange(of: drawers.map(\.id)) { _, ids in
                if !openID.isEmpty, !ids.contains(where: { $0.uuidString == openID }) { openID = "" ; page = "every" }
            }
            // Another drawer opened: its stubs are dealt onto the table, as the first drawer's were.
            .onChange(of: openID) { _, _ in
                guard !reduceMotion else { return }
                dealt = false
                Task {
                    try? await Task.sleep(for: .milliseconds(80))
                    dealt = true
                }
            }
            .onChange(of: notice) { _, now in
                guard now != nil else { return }
                Task {
                    try? await Task.sleep(for: .seconds(2.4))
                    if notice == now { notice = nil }
                }
            }
            .navigationDestination(item: $selected) { stub in
                StubDetailView(stub: stub)
                    .navigationTransition(.zoom(sourceID: stub.id, in: table))
            }
            #if DEBUG || PERF
            .modifier(TableDebug(stubs: stubs, drawers: drawers, selected: $selected, showSeason: $showSeason,
                                 importing: $importing, keeping: $keeping, showCard: $showCard, openID: $openID, page: $page, face: $face, carried: $carried, moving: $moving, working: $working,
                                 shown: shown))
            #endif
        }
    }

    // MARK: The shelf of labels

    /// The open drawer's label among the others', and under it what the drawer shows.
    private func header(_ summary: SeasonSummary) -> some View {
        VStack(spacing: 10) {
            // Your card, in the corner above the labels, where a phone keeps the person's own things.
            HStack {
                Spacer()
                CardButton(initials: CardButton.initials(ownerName)) { showCard = true }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, -6)
            // While a stub is held the cabinet's other drawers come down over the shelf, so the shelf gives way to them.
            shelf
                .opacity(inHand ? 0 : 1)
                .scaleEffect(!inHand || reduceMotion ? 1 : 0.96)
                .animation(reduceMotion ? Motion.plain : Motion.place, value: inHand)
            if !stubs.isEmpty, page != "new" {
                HStack(spacing: 12) {
                    FacePicker(face: $face)
                    Spacer(minLength: 0)
                    if let open {
                        Button { choosing = open } label: {
                            Image(systemName: "checklist").font(.system(size: 17)).frame(width: 44, height: 44)
                        }
                        .buttonStyle(.stub(.quiet))
                        .accessibilityLabel("Choose the stubs in \(open.name)")
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.top, 2)
        .padding(.bottom, 8)
    }

    /// The labels, one to a page, the next ones showing at the edges so it is plain there are more. Swiped to, a label
    /// opens its drawer; tapped, the drawer's season. The blank one at the end names a new drawer.
    private var shelf: some View {
        GeometryReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    DrawerLabel(.every(films: stubs.count, cinemas: SeasonSummary(stubs: stubs).cinemas.count,
                                       years: DrawerLabel.years(of: stubs))) { showSeason = true }
                        .id("every")
                        .modifier(PlaqueDepth())
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { plateHeights["every"] = $0 }
                    ForEach(drawers) { drawer in
                        let filed = Cabinet.members(of: drawer, among: stubs)
                        DrawerLabel(.made(name: drawer.name, films: filed.count, years: DrawerLabel.years(of: filed))) { showSeason = true }
                            .id(drawer.id.uuidString)
                            .modifier(PlaqueDepth())
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { plateHeights[drawer.id.uuidString] = $0 }
                            .contextMenu {
                                Button("Rename", systemImage: "character.cursor.ibeam") { naming = .rename(drawer) }
                                Button("Choose stubs", systemImage: "checklist") { choosing = drawer }
                                Button("Take the drawer out", systemImage: "tray.and.arrow.up", role: .destructive) { removing = drawer }
                            }
                    }
                    if !stubs.isEmpty {
                        DrawerLabel(.blank) { naming = .new(filing: nil) }
                            .id("new")
                            .modifier(PlaqueDepth())
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { plateHeights["new"] = $0 }
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, max(20, (proxy.size.width - DrawerLabel.size(for: typeSize).width) / 2), for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $page, anchor: .center)
            .scrollClipDisabled()
        }
        // As tall as the tallest plate on it, which grows with the type (decision 005).
        .frame(height: (plateHeights.values.max() ?? DrawerLabel.size(for: typeSize).height) + 16)
        .onAppear { if page == nil { page = openID.isEmpty ? "every" : openID } }
        .onChange(of: page) { _, now in
            guard let now, now != "new" else { return }
            let id = now == "every" ? "" : now
            guard id != openID else { return }
            openID = id
            working = nil
        }
        .sensoryFeedback(.selection, trigger: page)
    }

    // MARK: The drawer

    @ViewBuilder
    private var content: some View {
        if stubs.isEmpty {
            EmptyDrawer { keeping = ImportRequest() }
                .padding(.horizontal, 20)
        } else if page == "new" {
            Invitation(title: "A drawer of your own.",
                       words: "For a festival, a season, someone you went with. A stub can be filed in more than one drawer, and every stub stays in the drawer of every stub.",
                       button: "Name a new drawer", symbol: "plus") { naming = .new(filing: nil) }
        } else if shown.isEmpty, let open {
            Invitation(title: "Nothing is filed in \(open.name) yet.",
                       words: "Hold a stub in another drawer and file it here, or choose them from a list.",
                       button: "Choose stubs to file", symbol: "checklist") { choosing = open }
        } else {
            let years = Cabinet.sections(shown)
            let order = Dictionary(shown.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { a, _ in a })
            ForEach(years) { year in
                let closed = isClosed(year.year)
                Section {
                    if !closed {
                        let mounts = mounts(year.stubs)
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 28) {
                            ForEach(year.stubs) { stub in
                                cell(stub, order: order[stub.id] ?? 0, mount: mounts[stub.id])
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 18)
                        .padding(.bottom, 30)
                        .transition(reduceMotion ? .opacity : .modifier(active: Filed(away: true), identity: Filed(away: false)))
                    }
                } header: {
                    YearFolder(year: year.year, count: year.stubs.count, closed: closed, slips: slips(year.stubs),
                               months: months(year.stubs)) { toggle(year.year) }
                }
            }
        }
    }

    // MARK: The year folders

    private func folderKey(_ year: Int) -> String { "\(openID.isEmpty ? "every" : openID)/\(year)" }

    private func isClosed(_ year: Int) -> Bool {
        closedYears.split(separator: ",").contains { $0 == folderKey(year) }
    }

    /// Closes a year into its folder, or opens it: the drawer's own spring, a little heavier than a card's, and a thud
    /// when the front comes up, a lighter tap when it opens.
    private func toggle(_ year: Int) {
        var keys = Set(closedYears.split(separator: ",").map(String.init))
        let key = folderKey(year)
        let closing = !keys.contains(key)
        if closing { keys.insert(key) } else { keys.remove(key) }
        withAnimation(reduceMotion ? Motion.plain : Motion.file) { closedYears = keys.sorted().joined(separator: ",") }
        folderThud = closing ? .impact(weight: .medium, intensity: 0.8) : .impact(weight: .light, intensity: 0.6)
        folderTaps += 1
    }

    /// The tops of a year's tickets standing in its closed folder: the edition's ground, or a ticket's card.
    private func slips(_ stubs: [Stub]) -> [Color] {
        let papers: [UInt32] = [0xF7F3EA, 0xF1E8D2, 0xE6DCC6, 0xFAF8F2, 0xD9D3C3]
        return stubs.map { stub in
            if face == .edition, let edition = Editions.shared.edition(for: stub.title) {
                return edition.palette.inks.color(.ground)
            }
            return Color(hex: papers[Int(Release.seed(for: stub.id.uuidString) % UInt64(papers.count))])
        }
    }

    /// "FEB – NOV", or one month, from the nights the year's stubs were seen.
    private func months(_ stubs: [Stub]) -> String? {
        let calendar = Calendar.current
        let ms = stubs.compactMap(\.screenedAt).map { calendar.component(.month, from: $0) }
        guard let first = ms.min(), let last = ms.max() else { return nil }
        let names = calendar.shortMonthSymbols.map { $0.uppercased() }
        return first == last ? names[first - 1] : "\(names[first - 1]) – \(names[last - 1])"
    }

    /// Two to a row; one at the accessibility sizes, where a narrow column would wrap every title a word to a line.
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 18, alignment: .top), count: typeSize.isAccessibilitySize ? 1 : 2)
    }

    /// Each row's mount, by stub: the row's tallest ticket decides it.
    private func mounts(_ year: [Stub]) -> [UUID: CGFloat] {
        let across = columns.count
        var mounts: [UUID: CGFloat] = [:]
        for start in stride(from: 0, to: year.count, by: across) {
            let row = Array(year[start..<min(start + across, year.count)])
            let mount = StubCard.mount(for: row)
            for stub in row { mounts[stub.id] = mount }
        }
        return mounts
    }

    private func cell(_ stub: Stub, order: Int, mount: CGFloat?) -> some View {
        Button { selected = stub } label: {
            StubCard(stub: stub, face: face, copy: copy(of: stub), order: order, carried: inHand && carried == stub.id, mount: mount)
        }
        .buttonStyle(CardPress())
        .accessibilityIdentifier("drawer.stub")
        .matchedTransitionSource(id: stub.id, in: table)
        // Held and let be, its menu: file it, or throw it away (ADR-035).
        .contextMenu { menu(for: stub) }
        // Held and moved, it comes up off the table to be carried; the drawer makes room for it as it goes.
        .onDrag {
            carry(stub)
        } preview: {
            CarriedPicture(stub: stub, face: face, copy: copy(of: stub))
        }
        .onDrop(of: [.stubCard], delegate: ReorderDrop(target: stub.id, sameYear: sameYear, working: $working, carried: carried, commit: commitOrder,
                                                           moved: startMoving))
        // Dealt onto the table the first time the drawer opens, newest first, one after another.
        .modifier(Dropped(airborne: !dealt, order: order))
        .animation(reduceMotion ? nil : Motion.drop.delay(min(Double(order), 9) * 0.055), value: dealt)
        .transition(reduceMotion ? .opacity : .modifier(active: Dropped(airborne: true, order: 0), identity: Dropped(airborne: false, order: 0)))
        .task {
            guard !dealt else { return }
            if !reduceMotion { try? await Task.sleep(for: .milliseconds(260)) }
            dealt = true
        }
        // A carried stub, without a finger: moved one place at a time.
        .accessibilityAction(named: "Move earlier in \(Cabinet.year(of: stub))") { nudge(stub, by: -1) }
        .accessibilityAction(named: "Move later in \(Cabinet.year(of: stub))") { nudge(stub, by: 1) }
        .accessibilityAction(named: "Throw away") { throwing = stub }
    }

    /// A held stub's menu, the detail's "File in a drawer" in the same words: every drawer, ticked where the stub is filed,
    /// a tick taken off taking it out of that drawer (it stays in the drawer of every stub); a new drawer; and throwing it
    /// away, which is asked once.
    @ViewBuilder
    private func menu(for stub: Stub) -> some View {
        Menu {
            ForEach(drawers) { drawer in
                let isIn = drawer.stubIDs.contains(stub.id)
                Button(drawer.name, systemImage: isIn ? "checkmark" : "tray") {
                    if isIn { takeOut(stub.id, of: drawer) } else { file(stub, into: drawer) }
                }
            }
            Button("New drawer…", systemImage: "plus") { naming = .new(filing: stub.id) }
        } label: {
            Label("File in a drawer", systemImage: "tray.and.arrow.down")
        }
        Divider()
        Button("Throw away", systemImage: "trash", role: .destructive) { throwing = stub }
    }

    /// A card's copy of its edition: which viewing it is comes from the drawer's one count.
    private func copy(of stub: Stub) -> Copy {
        guard let counted = viewings.of[stub.id] else { return Copy(stub: stub, among: stubs) }
        return Copy(stub: stub, viewing: counted.viewing, viewings: counted.of)
    }

    // MARK: Carrying and filing

    /// The other drawers' labels, to let a held stub go on; a blank one for a new drawer; and in a made drawer, a place to
    /// take it out.
    private var rail: some View {
        let others = drawers.filter { $0.id != open?.id }
        var targets = others.map { drawer in
            let filed = Cabinet.members(of: drawer, among: stubs)
            return CabinetRail.Target(id: drawer.id.uuidString,
                                      typed: .made(name: drawer.name, films: filed.count, years: DrawerLabel.years(of: filed))) { file(into: drawer) }
        }
        targets.append(CabinetRail.Target(id: "new", typed: .blank) {
            let id = carried
            settle()
            naming = .new(filing: id)
        })
        return CabinetRail(targets: targets, takeOut: open.map { drawer in (drawer.name, { takeOut(of: drawer) }) })
    }

    private func carry(_ stub: Stub) -> NSItemProvider {
        let provider = CarriedStub(stub.id)
        carried = stub.id
        // Asked again mid-carry, the drawer keeps the room it has already made.
        if working == nil { working = shown.map(\.id) }
        // Let go where nothing takes it: it goes back where it stood. A drop on the table has put it down already.
        provider.ended = {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(400))
                guard carried == stub.id, seen.quiet(for: 0.35) else { return }
                withAnimation(Motion.place) { settle() }
            }
        }
        return provider
    }

    private func sameYear(_ a: UUID, _ b: UUID) -> Bool {
        let byID = Dictionary(members.map { ($0.id, $0) }, uniquingKeysWith: { x, _ in x })
        guard let x = byID[a], let y = byID[b] else { return false }
        return Cabinet.year(of: x) == Cabinet.year(of: y)
    }

    /// The order the drawer made room in is the order it keeps.
    private func commitOrder() {
        if let working, Cabinet.commit(working, stubs: stubs, in: open) > 0 { try? context.save() }
        withAnimation(Motion.place) { settle() }
    }

    private func settle() {
        working = nil
        carried = nil
        moving = false
    }

    /// The first time the carried stub is seen over the table: it is being taken somewhere, not held for its menu.
    private func startMoving() {
        seen.mark()
        guard carried != nil, !moving else { return }
        withAnimation(reduceMotion ? Motion.plain : Motion.place) { moving = true }
    }

    private func file(into drawer: StubDrawer) {
        guard let id = carried, let stub = stubs.first(where: { $0.id == id }) else { return settle() }
        file(stub, into: drawer)
    }

    /// Carried there or chosen from its menu.
    private func file(_ stub: Stub, into drawer: StubDrawer) {
        let already = drawer.stubIDs.contains(stub.id)
        Cabinet.file(stub, in: drawer, among: stubs)
        try? context.save()
        withAnimation(Motion.place) { settle() }
        notice = already ? "Already in \(drawer.name)." : "Filed in \(drawer.name)."
    }

    private func takeOut(of drawer: StubDrawer) {
        guard let id = carried else { return settle() }
        takeOut(id, of: drawer)
    }

    private func takeOut(_ id: UUID, of drawer: StubDrawer) {
        withAnimation(Motion.place) {
            Cabinet.takeOut(id, of: drawer)
            settle()
        }
        try? context.save()
        notice = "Taken out of \(drawer.name). It is still in the drawer of every stub."
    }

    /// One place earlier or later in its year, for VoiceOver's actions.
    private func nudge(_ stub: Stub, by step: Int) {
        let order = shown.map(\.id)
        let year = Cabinet.year(of: stub)
        let same = shown.filter { Cabinet.year(of: $0) == year }.map(\.id)
        guard let i = same.firstIndex(of: stub.id), same.indices.contains(i + step) else { return }
        let next = Cabinet.move(stub.id, to: same[i + step], in: order, sameYear: sameYear)
        if Cabinet.commit(next, stubs: stubs, in: open) > 0 { try? context.save() }
    }

    /// As the detail throws a stub away: out of every drawer, then gone.
    private func throwAway(_ stub: Stub) {
        let title = stub.title
        withAnimation(Motion.place) {
            for drawer in drawers { Cabinet.takeOut(stub.id, of: drawer) }
            context.delete(stub)
        }
        try? context.save()
        throwing = nil
        notice = "\(title) is thrown away."
    }

    private func make(_ name: String, filing: UUID?) {
        let drawer = StubDrawer(name: name, position: Cabinet.nextPosition(after: drawers))
        context.insert(drawer)
        if let filing, let stub = stubs.first(where: { $0.id == filing }) { Cabinet.file(stub, in: drawer, among: stubs) }
        try? context.save()
        withAnimation(Motion.place) {
            openID = drawer.id.uuidString
            page = drawer.id.uuidString
        }
        if filing != nil { notice = "Filed in \(name)." }
    }

    private func remove(_ drawer: StubDrawer) {
        let name = drawer.name
        withAnimation(Motion.place) {
            openID = ""
            page = "every"
        }
        context.delete(drawer)
        try? context.save()
        notice = "The drawer \(name) is taken out."
        removing = nil
    }

    /// Prints, one release at a time, the editions of the drawer's stubs that have none yet.
    private func printMissing() async {
        let editions = Editions.shared
        for stub in shown where editions.edition(for: stub.title) == nil {
            if Task.isCancelled { return }
            let year = stub.screenedAt.map { Calendar.current.component(.year, from: $0) }
            _ = await editions.decide(title: stub.title, year: year, screen: stub.screen)
        }
    }

    private func takeArrival() {
        guard importing == nil, keeping == nil, reach.arrival != nil, let arrival = reach.take() else { return }
        importing = ImportRequest(arrival: arrival)
    }
}

#if DEBUG || PERF
/// `-stage-scroll`: the drawer scrolled to its foot and back three times on its own, so Instruments can record the drawer's
/// scroll without a test runner attached (docs/decisions/004-budgets.md).
private struct StagedScroll: ViewModifier {
    @State private var position = ScrollPosition(edge: .top)

    func body(content: Content) -> some View {
        content
            .scrollPosition($position)
            .task {
                guard ProcessInfo.processInfo.arguments.contains("-stage-scroll") else { return }
                try? await Task.sleep(for: .seconds(3))
                for _ in 0..<3 {
                    Stage.log.info("stage: scroll down")
                    withAnimation(.easeInOut(duration: 2.5)) { position.scrollTo(edge: .bottom) }
                    try? await Task.sleep(for: .seconds(3))
                    withAnimation(.easeInOut(duration: 2.5)) { position.scrollTo(edge: .top) }
                    try? await Task.sleep(for: .seconds(3))
                }
            }
    }
}
#endif

/// Every stub's viewing of its release, counted again only when the drawer's stubs or their titles or nights change. A
/// reference, so recounting from the table's body redraws nothing.
@MainActor
final class Viewings {
    private(set) var of: [UUID: (viewing: Int, of: Int)] = [:]
    private var signature: [String] = []
    /// Changes whenever the drawer's stubs, titles or nights do: what Spotlight's index follows.
    private(set) var count = 0

    func refresh(_ stubs: [Stub]) {
        let now = stubs.map { "\($0.id)\($0.title)\(($0.screenedAt ?? $0.createdAt).timeIntervalSince1970)" }
        guard now != signature else { return }
        signature = now
        of = Copy.viewings(in: stubs)
        count &+= 1
    }
}

/// When a carried stub was last seen moving. A reference, so marking it on every drag update redraws nothing.
final class CarryClock {
    private var last = Date.distantPast
    func mark() { last = .now }
    func quiet(for seconds: TimeInterval) -> Bool { Date.now.timeIntervalSince(last) > seconds }
}

/// A stub pressed in the drawer: it sits up straight and the print lifts, through the card's own `pressed`.
struct CardPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .environment(\.cardPressed, configuration.isPressed)
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed) { _, now in now }
    }
}

extension EnvironmentValues {
    @Entry var cardPressed = false
}

/// What a drawer with nothing to show says, and the one thing to do about it.
struct Invitation: View {
    let title: String
    let words: String
    let button: String
    let symbol: String
    let act: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(Type.reading(21)).foregroundStyle(Ink.ink).fixedSize(horizontal: false, vertical: true)
            Text(words).font(Type.words(15)).foregroundStyle(Ink.soft(0.7)).fixedSize(horizontal: false, vertical: true)
            Button(action: act) {
                HStack(spacing: 8) {
                    Image(systemName: symbol).font(.system(size: 15, weight: .medium))
                    Text(button)
                }
            }
            .buttonStyle(.stub(.ink))
            .padding(.top, 6)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
    }
}

extension Dock {
    var keepButton: some View {
        Button(action: keep) {
            HStack(spacing: 8) {
                Image(systemName: "camera").font(Type.display(15))
                Text("Keep a stub")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.stub(.ink))
        .accessibilityShowsLargeContentViewer()
        .accessibilityHint("Opens the camera on a ticket. A photograph or typing it in are there too.")
    }
}

/// A drawer's label further along the cabinet: a little smaller and in shadow, so the one in the middle is the drawer open.
struct PlaqueDepth: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let still = reduceMotion
        return content.scrollTransition(.interactive, axis: .horizontal) { view, phase in
            view
                .scaleEffect(still || phase.isIdentity ? 1 : 0.9)
                .brightness(phase.isIdentity ? 0 : -0.06)
                .opacity(phase.isIdentity ? 1 : 0.8)
        }
    }
}

/// A year's stubs going into their folder: up under its front, a little shorter and fainter, as cards slide into a file.
struct Filed: ViewModifier {
    var away: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(x: away ? 0.96 : 1, y: away ? 0.7 : 1, anchor: .top)
            .offset(y: away ? -40 : 0)
            .opacity(away ? 0 : 1)
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
            // The empty drawer's one sentence: what the drawer is for. Reading type, smaller and quieter than the season's.
            Text(SeasonSummary().handSentence)
                .font(Type.reading(19))
                .foregroundStyle(Ink.soft(0.8))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: add) {
                HStack(spacing: 8) {
                    Image(systemName: "camera").font(.system(size: 15, weight: .medium))
                    Text("Keep the first stub")
                }
            }
            .buttonStyle(.stub(.ink))
        }
    }
}

/// One presentation of the import sheet: blank, or on an arrival, and the drawer a kept stub is filed in besides.
struct ImportRequest: Identifiable {
    let id = UUID()
    var arrival: Arrival?
    var drawer: StubDrawer?
}

/// The drawer's two doors, at the bottom of the table where a thumb is (ADR-022): the season, with how many films it
/// counts, and Keep a stub, the one act the app is for. Stamps on the parchment, which fades in under them; no glass.
struct Dock: View {
    let films: Int
    let season: () -> Void
    let keep: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        // Side by side; one over the other at the accessibility sizes, Keep on top, so neither word is broken.
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 14))
        layout {
            if typeSize.isAccessibilitySize { keepButton }
            Button(action: season) {
                HStack(spacing: 8) {
                    Text("The season")
                    Text("\(films)").font(Type.numbers(14)).foregroundStyle(Ink.grey)
                }
                .frame(maxWidth: typeSize.isAccessibilitySize ? .infinity : nil)
            }
            .buttonStyle(.stub(.paper))
            .accessibilityShowsLargeContentViewer()
            .accessibilityLabel("The season, \(films) \(films == 1 ? "film" : "films")")
            .accessibilityHint("The numbers behind the sentence.")

            if !typeSize.isAccessibilitySize { keepButton }
        }
        .padding(.horizontal, 20)
        .padding(.top, 44)
        .padding(.bottom, 8)
        // A bar that stays on screen grows to the first accessibility size and no further, and a hold shows its words
        // large, as the system's own bars do; otherwise the doors would cover a third of the drawer (decision 005).
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        // For the audit: the drawer scrolls under the doors' fade on purpose (decision 005).
        .accessibilityIdentifier("bar")
        .background {
            LinearGradient(stops: [.init(color: Ink.paper.opacity(0), location: 0), .init(color: Ink.paper.opacity(0.92), location: 0.42),
                                   .init(color: Ink.paper, location: 0.6)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .bottom)
        }
    }
}

#if DEBUG || PERF
/// The table's launch arguments: everything a screenshot needs that a finger would otherwise do (ADR-009).
private struct TableDebug: ViewModifier {
    let stubs: [Stub]
    let drawers: [StubDrawer]
    @Binding var selected: Stub?
    @Binding var showSeason: Bool
    @Binding var importing: ImportRequest?
    @Binding var keeping: ImportRequest?
    @Binding var showCard: Bool
    @Binding var openID: String
    @Binding var page: String?
    @Binding var face: DrawerFace
    @Binding var carried: UUID?
    @Binding var moving: Bool
    @Binding var working: [UUID]?
    let shown: [Stub]
    @Environment(\.modelContext) private var context

    func body(content: Content) -> some View {
        content
            .onAppear { if let face = DebugDrive.face { self.face = face } }
            .onChange(of: DebugDrive.shared.openNewest) { _, now in
                guard now else { return }
                DebugDrive.shared.openNewest = false
                Task {
                    try? await Task.sleep(for: .seconds(1.1))
                    DebugDrive.log.info("preview: open")
                    selected = stubs.first
                }
            }
            .task {
                // `-import`: open the import sheet after the seed has settled, so it can be screenshotted.
                guard DebugDrive.wantsImport else { return }
                do { try await Task.sleep(for: .seconds(DebugDrive.curtain)) } catch { return }
                importing = ImportRequest()
            }
            .task {
                // `-card`: open Your card once the drawer has settled.
                guard ProcessInfo.processInfo.arguments.contains("-card") else { return }
                do { try await Task.sleep(for: .seconds(2.5)) } catch { return }
                showCard = true
            }
            .task {
                // `-keep`: press Keep a stub once the drawer has settled: the viewfinder opens.
                guard DebugDrive.wantsKeep else { return }
                do { try await Task.sleep(for: .seconds(2.5)) } catch { return }
                keeping = ImportRequest()
            }
            .task(id: stubs.count) {
                // `-drive`: press, open, hold and close on a timer, so the simulator can be filmed without hands.
                guard DebugDrive.requested, !DebugDrive.wantsPress, !stubs.isEmpty, !DebugDrive.shared.hasRun else { return }
                DebugDrive.shared.run(stubs: stubs) { selected = $0 }
            }
            .task(id: stubs.count) {
                // `-edition`: open the newest stub once the drawer has sat still after the seed (ADR-015).
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
            .task(id: stubs.count) {
                // `-cabinet`: two drawers, filed as a person would, once the seed has settled (ADR-026).
                guard DebugDrive.wantsCabinet, drawers.isEmpty, stubs.count >= 6 else { return }
                do { try await Task.sleep(for: .seconds(2)) } catch { return }
                guard !DebugSeed.requested || DebugSeed.finished, drawers.isEmpty else { return }
                let festival = StubDrawer(name: "Festival 2025", position: 1)
                let mum = StubDrawer(name: "With Mum", position: 2)
                context.insert(festival)
                context.insert(mum)
                let ordered = Cabinet.order(stubs, in: nil)
                for stub in ordered where Cabinet.year(of: stub) == 2025 { Cabinet.file(stub, in: festival, among: stubs) }
                for stub in ordered.enumerated().filter({ $0.offset % 3 == 1 }).map(\.element) { Cabinet.file(stub, in: mum, among: stubs) }
                try? context.save()
                DebugDrive.log.info("cabinet: two drawers made")
            }
            .task(id: drawers.count) {
                // `-drawer "With Mum"`: open that drawer.
                guard let name = DebugDrive.drawerName, let drawer = drawers.first(where: { $0.name == name }) else { return }
                openID = drawer.id.uuidString
                page = drawer.id.uuidString
            }
            .task(id: stubs.count) {
                // `-carry`: hold the drawer's second stub up, as a finger would, so the rail shows.
                guard DebugDrive.wantsCarry, shown.count > 1 else { return }
                do { try await Task.sleep(for: .seconds(3)) } catch { return }
                working = shown.map(\.id)
                carried = shown[1].id
                moving = true
            }
    }
}
#endif
