import SwiftUI
import SwiftData
import CoreTransferable
import UniformTypeIdentifiers

/// Your card (ADR-028): who keeps this drawer, and the few things about it that are settings. Stub has no account to sign in
/// to: the drawer is the person's, on their phone and in their own iCloud, so the card is a reader's card of the kind a
/// library gives, typed with their name if they give it, the night they started, what the drawer holds, and their
/// signature if they have signed at the press. Under it, plainly: the icon, where the drawer is kept, the drawer as a
/// file, and what Stub is.
struct YourCard: View {
    @Query(sort: \Stub.createdAt) private var stubs: [Stub]
    @Query private var drawers: [StubDrawer]
    @Query(filter: #Predicate<PressRecord> { $0.kind == "owner" }) private var owner: [PressRecord]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage("drawer.face") private var face: DrawerFace = .ticket
    @AppStorage(Drawer.syncKey) private var keepsInICloud = true
    @State private var icons = IconDrawer.shared
    @State private var naming = false
    @State private var name = ""
    @FocusState private var typing: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 34) {
                    ReadersCard(name: savedName, since: since, stubs: stubs.count,
                                cinemas: Set(stubs.compactMap { $0.venue ?? $0.cinema }).count, drawers: drawers.count,
                                signature: Signatures.shared.image) {
                        name = savedName ?? ""
                        naming = true
                    }
                    if naming { nameField }
                    iconSection
                    drawerSection
                    aboutSection
                }
                .padding(20)
                .padding(.bottom, 30)
            }
            .background(Paper())
            .navigationTitle("Your card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.buttonStyle(.stub(.quiet))
                }
                .sharedBackgroundVisibility(.hidden)
            }
            .task { await icons.start() }
            .alert("Icons", isPresented: Binding(get: { icons.failure != nil }, set: { if !$0 { icons.failure = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(icons.failure ?? "")
            }
        }
        .presentationBackground(Ink.paper)
    }

    // MARK: The card

    private var savedName: String? {
        owner.max { $0.updatedAt < $1.updatedAt }.flatMap { String(data: $0.data, encoding: .utf8) }?.nilIfEmpty
    }

    /// The night the drawer starts: its earliest screening, or the first stub kept.
    private var since: Date? {
        stubs.map { $0.screenedAt ?? $0.createdAt }.min()
    }

    private var nameField: some View {
        HStack(spacing: 12) {
            TextField("Your name, as it goes on the card", text: $name)
                .font(Type.words(17))
                .textInputAutocapitalization(.words)
                .focused($typing)
                .submitLabel(.done)
                .onSubmit(saveName)
                .padding(.vertical, 10)
                .overlay(alignment: .bottom) { Rectangle().fill(Ink.ink.opacity(0.18)).frame(height: 1) }
            Button("Type it", action: saveName).buttonStyle(.stub(.ink, tight: true))
        }
        .onAppear { typing = true }
        .sensoryFeedback(.impact(flexibility: .rigid, intensity: 0.35), trigger: name)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    /// The name is kept in the drawer's store, where it syncs with the stubs (ADR-024): the same card on every phone.
    private func saveName() {
        let typed = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
        for record in owner { context.delete(record) }
        context.insert(PressRecord(kind: "owner", key: "name", data: Data(typed.utf8)))
        try? context.save()
        withAnimation(Motion.place) { naming = false }
    }

    // MARK: The icon

    private var iconSection: some View {
        CardSection("The icon") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 5), spacing: 16) {
                ForEach(IconDrawer.icons) { icon in
                    IconChoice(icon: icon, chosen: icons.currentIcon == icon, open: icons.owned || icon.alternate == nil) {
                        Task { await icons.choose(icon) }
                    }
                }
            }
            if icons.owned {
                Text("All ten are yours. Tap one and it goes on the home screen.")
                    .font(Type.words(13)).foregroundStyle(Ink.grey)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Torn is Stub's own. The other nine come with the icon drawer: one payment, kept for good, no subscription.")
                        .font(Type.words(15)).foregroundStyle(Ink.ink.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 14) {
                        Button {
                            Task { await icons.buy() }
                        } label: {
                            HStack(spacing: 8) {
                                if icons.buying { ProgressView().tint(Ink.paper) }
                                Text("Open the icon drawer · \(icons.price)")
                            }
                        }
                        .buttonStyle(.stub(.ink))
                        .disabled(icons.buying)
                        Button("Restore") { Task { await icons.restore() } }
                            .buttonStyle(.stub(.quiet))
                    }
                }
            }
        }
    }

    // MARK: The drawer

    private var drawerSection: some View {
        CardSection("The drawer") {
            Row("Show it as") { FacePicker(face: $face) }
            Toggle(isOn: $keepsInICloud) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Keep it in my iCloud").font(Type.words(16)).foregroundStyle(Ink.ink)
                    Text(SharedStore.isSyncing ? "On this phone and in your own iCloud, private to you."
                                               : "On this phone only. It goes to your iCloud the next time Stub opens.")
                        .font(Type.words(12)).foregroundStyle(Ink.grey)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(Ink.orange)
            ShareLink(item: DrawerExport(stubs: stubs, drawers: drawers), preview: SharePreview("Stub — the drawer.csv")) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text("The drawer as a spreadsheet")
                }
            }
            .buttonStyle(.stub(.paper))
            .disabled(stubs.isEmpty)
        }
    }

    // MARK: Stub

    private var aboutSection: some View {
        CardSection("Stub") {
            Text("Nothing you keep leaves your phone, except to your own iCloud. There is no account, no server of ours, and nothing tracked.")
                .font(Type.reading(17)).foregroundStyle(Ink.ink.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            Link(destination: ShareLinkText.link) {
                HStack(spacing: 6) {
                    Text("designedbybruno.net/stub")
                    Image(systemName: "arrow.up.right").font(.system(size: 12, weight: .medium))
                }
                .font(Type.words(15)).foregroundStyle(Ink.ink)
            }
            Text("Version \(Self.version)").font(Type.numbers(11)).foregroundStyle(Ink.grey)
        }
    }

    private static var version: String {
        let info = Bundle.main.infoDictionary
        return "\(info?["CFBundleShortVersionString"] as? String ?? "1.0") (\(info?["CFBundleVersion"] as? String ?? "1"))"
    }
}

/// A heading and what is under it, in the card's own words: no boxes, no uppercase.
private struct CardSection<Content: View>: View {
    let title: String
    let content: Content
    init(_ title: String, @ViewBuilder content: () -> Content) { self.title = title; self.content = content() }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(Type.display(20)).tracking(Type.displayTracking(20)).foregroundStyle(Ink.ink)
                .accessibilityAddTraits(.isHeader)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct Row<Content: View>: View {
    let label: String
    let content: Content
    init(_ label: String, @ViewBuilder content: () -> Content) { self.label = label; self.content = content() }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(Type.words(13)).foregroundStyle(Ink.grey)
            content
        }
    }
}

/// One icon to choose: the icon as the home screen masks it, a ring of ink round the one on the home screen, and a small
/// lock on the ones in the closed drawer.
private struct IconChoice: View {
    let icon: IconDrawer.Icon
    let chosen: Bool
    let open: Bool
    let choose: () -> Void

    var body: some View {
        Button(action: choose) {
            VStack(spacing: 6) {
                Image(icon.preview)
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .strokeBorder(Ink.orange, lineWidth: chosen ? 2.5 : 0)
                            .padding(-4)
                    }
                    .overlay(alignment: .bottomTrailing) {
                        if !open {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(Ink.paper)
                                .frame(width: 18, height: 18)
                                .background(Circle().fill(Ink.ink.opacity(0.75)))
                                .offset(x: 4, y: 4)
                        }
                    }
                    .opacity(open ? 1 : 0.55)
                    .shadow(color: .black.opacity(0.12), radius: 3, x: 1, y: 2)
                Text(icon.name).font(Type.words(11)).foregroundStyle(chosen ? Ink.ink : Ink.grey).lineLimit(1).minimumScaleFactor(0.8)
            }
        }
        .buttonStyle(.plain)
        .disabled(!open)
        .sensoryFeedback(.selection, trigger: chosen) { _, now in now }
        .accessibilityLabel("\(icon.name) icon\(chosen ? ", on the home screen" : "")\(open ? "" : ", in the icon drawer")")
        .accessibilityAddTraits(chosen ? .isSelected : [])
    }
}

/// The reader's card: cream card, a ruled line for each thing typed on it, the name in the face, the numbers in the mono, the
/// signature on its line, a brass eyelet where it would hang, and a perforated end, as a ticket has.
struct ReadersCard: View {
    let name: String?
    let since: Date?
    let stubs: Int
    let cinemas: Int
    let drawers: Int
    let signature: UIImage?
    let typeName: () -> Void

    init(name: String?, since: Date?, stubs: Int, cinemas: Int, drawers: Int, signature: UIImage?, typeName: @escaping () -> Void) {
        self.name = name; self.since = since; self.stubs = stubs; self.cinemas = cinemas; self.drawers = drawers
        self.signature = signature; self.typeName = typeName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Stub").font(Type.display(26)).tracking(Type.displayTracking(26)).foregroundStyle(Ink.ink)
                Text("Reader's card").font(Type.words(13)).foregroundStyle(Ink.grey)
                Spacer()
                Circle()
                    .fill(RadialGradient(colors: [Color(hex: 0xFBE9BE), Color(hex: 0xC09450), Color(hex: 0x6E4F22)],
                                         center: UnitPoint(x: 0.32, y: 0.3), startRadius: 0, endRadius: 9))
                    .overlay(Circle().fill(Ink.paper).padding(4))
                    .frame(width: 16, height: 16)
                    .accessibilityHidden(true)
            }
            .padding(.bottom, 16)
            Button(action: typeName) {
                line("Kept by") {
                    Text(name ?? "Type your name")
                        .font(Type.display(19))
                        .foregroundStyle(name == nil ? Ink.grey : Ink.ink)
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint("Types your name on the card.")
            line("Since") {
                Text(since.map { $0.formatted(.dateTime.day(.twoDigits).month(.abbreviated).year()).uppercased() } ?? "—")
                    .font(Type.numbers(15)).foregroundStyle(Ink.ink)
            }
            HStack(spacing: 0) {
                figure(stubs, stubs == 1 ? "stub" : "stubs")
                figure(cinemas, cinemas == 1 ? "cinema" : "cinemas")
                figure(drawers + 1, drawers == 0 ? "drawer" : "drawers")
            }
            .padding(.vertical, 12)
            .overlay(alignment: .bottom) { rule }
            line("Signed") {
                if let signature {
                    Image(uiImage: signature).resizable().scaledToFit().frame(height: 34)
                        .accessibilityLabel("Your signature")
                } else {
                    Text("Sign it on the back of a proof, at the press").font(Type.words(13)).foregroundStyle(Ink.grey)
                }
            }
        }
        .padding(.leading, 22)
        .padding(.trailing, 40)
        .padding(.vertical, 20)
        .background {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(LinearGradient(colors: [Ink.cream, Color(hex: 0xEDE4CF)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(alignment: .trailing) { perforation }
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Ink.navy.opacity(0.12)).offset(x: 5, y: 6))
        }
        .rotationEffect(.degrees(-0.6))
        .accessibilityElement(children: .contain)
    }

    private var rule: some View { Rectangle().fill(Ink.ink.opacity(0.14)).frame(height: 1) }

    private func line<V: View>(_ label: String, @ViewBuilder value: () -> V) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(label).font(Type.words(12)).foregroundStyle(Ink.grey).frame(width: 58, alignment: .leading)
            value()
            Spacer(minLength: 0)
        }
        .padding(.vertical, 11)
        .frame(minHeight: 44)
        .overlay(alignment: .bottom) { rule }
        .contentShape(Rectangle())
    }

    private func figure(_ n: Int, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(n)").font(Type.numbers(22)).foregroundStyle(Ink.ink)
            Text(label).font(Type.words(12)).foregroundStyle(Ink.grey)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var perforation: some View {
        VStack(spacing: 6) {
            ForEach(0..<22, id: \.self) { _ in Circle().fill(Ink.grey.opacity(0.3)).frame(width: 3.5, height: 3.5) }
        }
        .padding(.trailing, 16)
        .accessibilityHidden(true)
    }
}

/// The button that opens Your card: the reader's initials on a slip of card in a ring of brass, or a ticket when the card
/// has no name yet.
struct CardButton: View {
    let initials: String?
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            ZStack {
                Circle().fill(Ink.cream)
                Circle().strokeBorder(LinearGradient(colors: [Color(hex: 0xE6CD93), Color(hex: 0xA77E3F)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                      lineWidth: 2)
                if let initials {
                    Text(initials).font(Type.display(14)).foregroundStyle(Ink.ink)
                } else {
                    Image(systemName: "person.text.rectangle").font(.system(size: 15, weight: .regular)).foregroundStyle(Ink.ink)
                }
            }
            .frame(width: 38, height: 38)
            .shadow(color: Color(hex: 0x3B2A12).opacity(0.18), radius: 3, x: 1, y: 2)
            .frame(width: 44, height: 44)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Your card")
        .accessibilityHint("Your name, the icon, where the drawer is kept, and what Stub is.")
    }

    static func initials(_ name: String?) -> String? {
        guard let name, !name.isEmpty else { return nil }
        let letters = name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined()
        return letters.isEmpty ? nil : letters.uppercased()
    }
}

/// The whole drawer as a spreadsheet, one stub to a row, for the person to keep wherever they like (ADR-028).
struct DrawerExport: Transferable {
    let rows: String

    init(stubs: [Stub], drawers: [StubDrawer]) {
        rows = Self.csv(stubs: stubs, drawers: drawers)
    }

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { export in
            let url = FileManager.default.temporaryDirectory.appending(path: "Stub — the drawer.csv")
            try Data(export.rows.utf8).write(to: url)
            return SentTransferredFile(url)
        }
    }

    static func csv(stubs: [Stub], drawers: [StubDrawer]) -> String {
        let iso = DateFormatter()
        iso.locale = Locale(identifier: "en_US_POSIX")
        iso.dateFormat = "yyyy-MM-dd HH:mm"
        func cell(_ s: String?) -> String {
            guard let s, !s.isEmpty else { return "" }
            return s.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" }) ? "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\"" : s
        }
        var lines = ["Film,Cinema,Venue,Circuit,Screened,Screen,Seat,Price,Currency,Read by,Drawers"]
        for stub in Cabinet.order(stubs, in: nil) {
            let filed = drawers.filter { $0.stubIDs.contains(stub.id) }.map(\.name).joined(separator: "; ")
            lines.append([cell(stub.title), cell(stub.cinema), cell(stub.venue), cell(stub.circuit),
                          cell(stub.screenedAt.map { iso.string(from: $0) }), cell(stub.screen), cell(stub.seat),
                          cell(stub.price.map { "\($0)" }), cell(stub.currency), cell(stub.readBy), cell(filed)].joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }
}
