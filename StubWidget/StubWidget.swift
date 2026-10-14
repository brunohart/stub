import WidgetKit
import SwiftUI
import SwiftData
import AppIntents
import OSLog

/// The drawer on the home screen and the lock screen (ADR-027): a stub's edition, drawn from the edition's own marks (the
/// same `Composition` and `Printer` the app prints with), so it is sharp at every size, tints with the home screen, and can
/// be dealt and turned over in place. It reads the shared store (`SharedStore`) and what the press keeps in it; the app
/// reloads it whenever the drawer changes, and the two buttons reload it themselves.
@main
struct StubWidgetBundle: WidgetBundle {
    var body: some Widget {
        DeckWidget()
    }
}

struct DeckEntry: TimelineEntry {
    let date: Date
    /// `nil` is an empty drawer, or a store the widget could not open.
    let card: Deck.Card?
    var turned = false
}

struct DeckProvider: TimelineProvider {
    func placeholder(in context: Context) -> DeckEntry {
        DeckEntry(date: .now, card: Self.sample)
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (DeckEntry) -> Void) {
        completion(context.isPreview ? DeckEntry(date: .now, card: Self.sample) : Self.read())
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<DeckEntry>) -> Void) {
        completion(Timeline(entries: [Self.read()], policy: .never))
    }

    /// The card the deck is on. Read-only: the app is the only writer to the store.
    static func read() -> DeckEntry {
        guard let container = try? SharedStore.container(readOnly: true) else { return DeckEntry(date: .now, card: nil) }
        let (card, turned) = Deck.current(in: ModelContext(container))
        Logger(subsystem: "com.designedbybruno.stub", category: "widget")
            .info("Deck: \(card?.title ?? "empty") at \(card?.position ?? -1) of \(card?.count ?? 0)\(turned ? ", turned" : "")")
        return DeckEntry(date: .now, card: card, turned: turned)
    }

    /// What the gallery shows before there is a drawer: a release's edition from its title alone.
    static var sample: Deck.Card {
        let copy = Copy(title: "Past Lives", cinema: "Penthouse Cinema", date: "09 FEB 2024", time: "18:00", screen: "4", seat: "K9", price: "$14.00")
        return Deck.Card(id: UUID(), composition: Composition(edition: Genome.floor(for: "Past Lives"), copy: copy), title: "Past Lives",
                         cinema: "Penthouse Cinema", numbers: "09 FEB 24 · K9", photo: nil, position: 0, count: 1)
    }
}

struct DeckWidget: Widget {
    /// The kind the last-stub widget had, so a widget already on someone's home screen becomes this one.
    let kind = "com.designedbybruno.stub.last"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DeckProvider()) { entry in
            // A film, a date and a seat are the owner's: redacted on a locked phone (Lock Screen, Always-On, StandBy).
            DeckView(entry: entry).privacySensitive()
        }
        .configurationDisplayName("The drawer")
        .description("A stub's edition. Turn it over for the ticket as you kept it, or deal another.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryInline])
        .contentMarginsDisabled()
    }
}

// MARK: The buttons

/// Deals the next stub from the drawer, face up.
struct DealIntent: AppIntent {
    static let title: LocalizedStringResource = "Deal another stub"
    static let isDiscoverable = false
    func perform() async throws -> some IntentResult {
        Deck.deal()
        return .result()
    }
}

/// Turns the stub over: the edition, or the ticket as it was kept.
struct TurnIntent: AppIntent {
    static let title: LocalizedStringResource = "Turn the stub over"
    static let isDiscoverable = false
    func perform() async throws -> some IntentResult {
        Deck.turn()
        return .result()
    }
}

// MARK: The views

struct DeckView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var mode
    let entry: DeckEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryInline: inline
            case .accessoryRectangular: rectangular.containerBackground(.clear, for: .widget)
            case .systemSmall: small
            default: wide
            }
        }
        .widgetURL(entry.card.map { StubLink.url(for: $0.id) })
    }

    private var accented: Bool { mode != .fullColor }

    // MARK: Small: the poster, the whole of it, on its own ground.

    @ViewBuilder
    private var small: some View {
        if let card = entry.card {
            let ground = card.composition.inks.color(card.composition.posterField)
            ZStack {
                if entry.turned, let photo = card.photo.flatMap(UIImage.init(data:)) {
                    Kept(photo: photo, tilt: card.composition.copy.viewing.isMultiple(of: 2) ? 1.2 : -1.2)
                        .padding(14)
                        .transition(.blurReplace)
                } else {
                    Poster(composition: card.composition, accented: accented)
                        .transition(.push(from: .trailing))
                }
            }
            .id(card.id.uuidString + (entry.turned ? "/back" : ""))
            .containerBackground(for: .widget) { entry.turned ? Ink.paper : ground }
        } else {
            empty.containerBackground(Ink.paper, for: .widget)
        }
    }

    // MARK: Medium and large: the card on the table, what it says beside it, and the two buttons.

    @ViewBuilder
    private var wide: some View {
        if let card = entry.card {
            HStack(alignment: .center, spacing: family == .systemLarge ? 20 : 16) {
                ZStack {
                    if entry.turned, let photo = card.photo.flatMap(UIImage.init(data:)) {
                        Kept(photo: photo, tilt: -1.2)
                            .transition(.blurReplace)
                    } else {
                        WholeCard(composition: card.composition, accented: accented)
                            .rotationEffect(.degrees(accented ? 0 : -1.2))
                            .transition(.push(from: .trailing))
                    }
                }
                .id(card.id.uuidString + (entry.turned ? "/back" : ""))
                .frame(maxWidth: entry.turned ? .infinity : nil)
                VStack(alignment: .leading, spacing: 4) {
                    Text(card.title)
                        .font(Type.display(family == .systemLarge ? 22 : 17))
                        .tracking(Type.displayTracking(17))
                        .foregroundStyle(Ink.ink)
                        .lineLimit(3)
                        .minimumScaleFactor(0.8)
                        .widgetAccentable()
                    if let numbers = card.numbers {
                        Text(numbers).font(Type.numbers(11)).foregroundStyle(Ink.ink.opacity(0.75)).lineLimit(1).minimumScaleFactor(0.8)
                    }
                    if let cinema = card.cinema {
                        Text(cinema).font(Type.words(11)).foregroundStyle(Ink.grey).lineLimit(2)
                    }
                    Spacer(minLength: 6)
                    if card.count > 1 {
                        Text("\(card.position + 1) of \(card.count)")
                            .font(Type.numbers(10)).foregroundStyle(Ink.grey)
                            .contentTransition(.numericText())
                    }
                    HStack(spacing: 6) {
                        Button(intent: TurnIntent()) {
                            Label(entry.turned ? "Front" : "Turn", systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
                        }
                        if card.count > 1 {
                            Button(intent: DealIntent()) {
                                Label("Another", systemImage: "rectangle.stack")
                            }
                        }
                    }
                    .buttonStyle(Stamp())
                }
                .frame(maxWidth: entry.turned ? 150 : .infinity, alignment: .leading)
            }
            .padding(family == .systemLarge ? 20 : 14)
            .containerBackground(Ink.paper, for: .widget)
        } else {
            empty.padding(14).containerBackground(Ink.paper, for: .widget)
        }
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("The drawer").font(Type.display(17)).foregroundStyle(Ink.ink).widgetAccentable()
            Text("Keep a stub and its edition is printed here.")
                .font(Type.words(12))
                .foregroundStyle(Ink.grey)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(12)
    }

    // MARK: The lock screen: words and numbers; the system draws its own paper there.

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let card = entry.card {
                Text(card.title).font(Type.display(15)).lineLimit(2).widgetAccentable()
                if let numbers = card.numbers { Text(numbers).font(Type.numbers(12)) }
                if let cinema = card.cinema, card.numbers == nil { Text(cinema).font(Type.words(12)) }
            } else {
                Text("The drawer").font(Type.display(15)).widgetAccentable()
                Text("Nothing in it yet.").font(Type.words(12))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    private var inline: some View {
        Group {
            if let card = entry.card {
                Text([card.title, card.numbers].compactMap { $0 }.joined(separator: " · "))
            } else {
                Text("Stub: nothing yet")
            }
        }
    }
}

/// The edition's poster, the whole of it, fitted to the widget on its own ground: the strip is left for the card.
private struct Poster: View {
    let composition: Composition
    let accented: Bool

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / Card.width, proxy.size.height / Card.poster)
            Plates(composition: composition, accented: accented, poster: true)
                .frame(width: Card.width, height: Card.poster)
                .scaleEffect(scale)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

/// The whole card, poster and strip, cut to the ticket, scaled to the height it is given.
private struct WholeCard: View {
    let composition: Composition
    let accented: Bool

    var body: some View {
        GeometryReader { proxy in
            let scale = proxy.size.height / Card.height
            // The outline as a path, worked out here: the system draws a widget from what the extension hands it, and it
            // knows a path but not the app's own shapes.
            let outline = TicketShape(punches: composition.punches).path(in: CGRect(origin: .zero, size: Card.size))
            Plates(composition: composition, accented: accented, poster: false)
                .frame(width: Card.width, height: Card.height)
                .clipShape(outline)
                .background(
                    outline
                        .fill(Color(hex: EditionInks.mix(composition.inks.hex(composition.stripField), 0x000000, 0.35)))
                        .offset(x: 1.2, y: 1.8)
                        .opacity(accented ? 0 : 1)
                )
                .scaleEffect(scale)
                .frame(width: Card.width * scale, height: proxy.size.height)
        }
        .aspectRatio(Card.width / Card.height, contentMode: .fit)
    }
}

/// The edition's layers as the press lays them down: the stock, each plate, the foil, the type. The marks are canvases of
/// the marks themselves; the lines of type over each are set as text, because the system that draws a widget cannot draw
/// the app's variable faces from a canvas (ADR-027). Tinted on the home screen, the stock goes and the first plate and the
/// foil take the tint.
private struct Plates: View {
    let composition: Composition
    let accented: Bool
    /// Only the poster, without the strip.
    let poster: Bool

    var body: some View {
        var printer = Printer(composition: composition)
        printer.setsWords = false
        let c = composition
        let metal = LinearGradient(colors: [Color(hex: EditionInks.mix(c.inks.foilBase, 0xFFFFFF, 0.45)), Color(hex: c.inks.foilBase),
                                            Color(hex: EditionInks.mix(c.inks.foilBase, 0x000000, 0.3))],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
        return ZStack(alignment: .topLeading) {
            if !accented {
                Canvas { context, _ in
                    context.fill(Path(Card.posterRect), with: .color(c.inks.color(c.posterField)))
                    if !poster { context.fill(Path(Card.stripRect), with: .color(c.inks.color(c.stripField))) }
                }
            }
            ZStack(alignment: .topLeading) {
                Canvas { context, _ in clip(&context); printer.inks(into: context, plates: .first ... .first) }
                Words(composition: c, marks: words(.first), poster: poster)
            }
            .widgetAccentable()
            Canvas { context, _ in clip(&context); printer.inks(into: context, plates: .second ... .second) }
            Words(composition: c, marks: words(.second), poster: poster)
            if c.isMetallic {
                // The foil in its metal, lit from where the lamp rests: no shader, a metal's own gradient.
                ZStack(alignment: .topLeading) {
                    metal.mask(Canvas { context, _ in clip(&context); printer.foil(into: context) })
                    Words(composition: c, marks: c.poster.filter { $0.foil && Self.isWords($0) }, poster: poster, metal: metal)
                }
                .widgetAccentable()
            }
            Canvas { context, _ in clip(&context); printer.inks(into: context, plates: .type ... .type) }
            Words(composition: c, marks: words(.type), poster: poster)
        }
    }

    /// One plate's lines of type, the poster's then the strip's, less any the foil takes.
    private func words(_ plate: Plate) -> [Mark] {
        let c = composition
        let fromPoster = c.poster.filter { $0.plate == plate && Self.isWords($0) && !($0.foil && c.isMetallic) }
        let fromStrip = poster ? [] : c.strip.filter { $0.plate == plate && Self.isWords($0) }
        return fromPoster + fromStrip.map { var m = $0; m.part = Parts.stripPart; return m }
    }

    static func isWords(_ mark: Mark) -> Bool {
        if case .words = mark.shape { return true }
        return false
    }

    private func clip(_ context: inout GraphicsContext) {
        if poster { context.clip(to: Path(Card.posterRect)) }
    }
}

/// Lines of type, set where the canvas would have set them: on their baseline, shrunk to their width, turned about their
/// point, the poster's kept to the poster.
private struct Words: View {
    let composition: Composition
    let marks: [Mark]
    let poster: Bool
    var metal: LinearGradient? = nil

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(marks.enumerated()), id: \.offset) { _, mark in
                if case .words(let w) = mark.shape { line(w, mark) }
            }
        }
        .frame(width: Card.width, height: Card.height, alignment: .topLeading)
    }

    private func line(_ w: Mark.Words, _ mark: Mark) -> some View {
        let natural = Measure.width(w.text, face: w.face, size: w.size, tracking: w.tracking)
        let size = w.maxWidth.map { natural > $0 && natural > 0 ? w.size * $0 / natural : w.size } ?? w.size
        let width = Measure.width(w.text, face: w.face, size: size, tracking: w.tracking)
        let ascent = UIFont(name: w.face.postScriptName, size: size)?.ascender ?? size * 0.8
        let x: CGFloat = switch w.anchor {
        case .leading: w.at.x
        case .center: w.at.x - width / 2
        case .trailing: w.at.x - width
        }
        let inPoster = mark.part != Parts.stripPart
        let turn = mark.turn ?? Mark.Turn(degrees: 0, around: .zero)
        return Text(w.text)
            .font(w.face.font(size))
            .tracking(w.tracking * size)
            .foregroundStyle(metal.map { AnyShapeStyle($0) } ?? AnyShapeStyle(composition.inks.color(mark.role)))
            .lineLimit(1)
            .fixedSize()
            .offset(x: x, y: w.at.y - ascent)
            .frame(width: Card.width, height: Card.height, alignment: .topLeading)
            .opacity(mark.opacity)
            .rotationEffect(.degrees(turn.degrees), anchor: UnitPoint(x: turn.around.x / Card.width, y: turn.around.y / Card.height))
            .clipShape(Path(inPoster ? Card.posterRect : CGRect(origin: .zero, size: Card.size)))
    }
}

private extension Parts {
    /// Marks the strip's lines of type, which have no part of their own, so they are not kept to the poster.
    static let stripPart = "strip/words"
}

/// The ticket as it was kept, on the table, with its shadow.
private struct Kept: View {
    let photo: UIImage
    let tilt: Double

    var body: some View {
        Image(uiImage: photo)
            .resizable()
            .widgetAccentedRenderingMode(.fullColor)
            .aspectRatio(contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .shadow(color: .black.opacity(0.18), radius: 6, x: 3, y: 5)
            .rotationEffect(.degrees(tilt))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The widget's buttons: small paper stamps, the word beside its mark.
private struct Stamp: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Type.words(11))
            .labelStyle(.titleAndIcon)
            .foregroundStyle(Ink.ink)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Ink.cream))
            .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Ink.navy.opacity(0.16)).offset(x: 2, y: 2.5))
            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(Ink.ink.opacity(0.14), lineWidth: 0.75))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
