import WidgetKit
import SwiftUI
import SwiftData

/// The last stub, on the home screen and the lock screen. A single widget: the drawer's most recent card,
/// printed on parchment. It reads the shared store (`SharedStore`) and is reloaded by the app whenever the
/// drawer changes, so the timeline has one entry and no schedule.
@main
struct StubWidgetBundle: WidgetBundle {
    var body: some Widget {
        LastStubWidget()
    }
}

struct LastStubEntry: TimelineEntry {
    let date: Date
    /// `nil` is an empty drawer, or a store the widget could not open.
    let stub: LastStub?
}

struct LastStubProvider: TimelineProvider {
    func placeholder(in context: Context) -> LastStubEntry {
        LastStubEntry(date: .now, stub: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (LastStubEntry) -> Void) {
        completion(LastStubEntry(date: .now, stub: context.isPreview ? .placeholder : Self.read()))
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<LastStubEntry>) -> Void) {
        completion(Timeline(entries: [LastStubEntry(date: .now, stub: Self.read())], policy: .never))
    }

    /// The drawer's last card, or nothing. Read-only: the app is the only writer.
    static func read() -> LastStub? {
        guard let container = try? SharedStore.container(readOnly: true) else { return nil }
        let context = ModelContext(container)
        return SharedStore.lastStub(in: context).map(LastStub.init)
    }
}

struct LastStubWidget: Widget {
    let kind = "com.designedbybruno.stub.last"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LastStubProvider()) { entry in
            LastStubView(entry: entry)
        }
        .configurationDisplayName("Last stub")
        .description("The last film you kept.")
        .supportedFamilies([.systemSmall, .accessoryRectangular, .accessoryInline])
    }
}

/// One card on parchment. The home-screen widget is the table's card without its photograph: a cream stub,
/// tilted, the orange plate a little out of register beneath it. The lock screen gets the words and the
/// numbers only; the system draws its own paper there.
struct LastStubView: View {
    @Environment(\.widgetFamily) private var family
    let entry: LastStubEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            inline
        case .accessoryRectangular:
            rectangular
                .containerBackground(.clear, for: .widget)
        default:
            small
                .containerBackground(Ink.paper, for: .widget)
        }
    }

    private var small: some View {
        ZStack(alignment: .topLeading) {
            if let stub = entry.stub {
                card(stub)
            } else {
                empty
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// The card. Tilted like everything on the table (DESIGN.md rule 3), never level.
    private func card(_ stub: LastStub) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Ink.cream)
                .background(RoundedRectangle(cornerRadius: 3).fill(Ink.orange.opacity(0.14)).offset(x: 4, y: 5))
                .overlay(perforation, alignment: .trailing)
            VStack(alignment: .leading, spacing: 5) {
                Text(stub.title)
                    .displayText(17)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
                if let numbers = stub.numbers {
                    Text(numbers).numberText(11)
                }
                if let cinema = stub.cinema {
                    Text(cinema)
                        .font(Type.words(11))
                        .foregroundStyle(Ink.grey)
                        .lineLimit(2)
                }
            }
            .padding(11)
            .padding(.trailing, 20)
        }
        .rotationEffect(.degrees(-0.8))
        .padding(4)
    }

    private var perforation: some View {
        VStack(spacing: 5) {
            ForEach(0..<9, id: \.self) { _ in
                Circle().fill(Ink.grey.opacity(0.35)).frame(width: 3, height: 3)
            }
        }
        .padding(.trailing, 10)
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Stub").displayText(20)
            Text("Nothing in the drawer yet.")
                .font(Type.words(13))
                .foregroundStyle(Ink.grey)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(4)
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let stub = entry.stub {
                Text(stub.title)
                    .font(Type.display(15))
                    .lineLimit(2)
                    .widgetAccentable()
                if let numbers = stub.numbers {
                    Text(numbers).font(Type.numbers(12))
                }
                if let cinema = stub.cinema, stub.numbers == nil {
                    Text(cinema).font(Type.words(12))
                }
            } else {
                Text("Stub").font(Type.display(15)).widgetAccentable()
                Text("Nothing in the drawer yet.").font(Type.words(12))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var inline: some View {
        Group {
            if let stub = entry.stub {
                Text([stub.title, stub.seat].compactMap { $0 }.joined(separator: " · "))
            } else {
                Text("Stub: nothing yet")
            }
        }
    }
}
