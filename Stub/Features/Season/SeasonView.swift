import SwiftUI

/// The season, on one sheet. The sentence in Newsreader italic, the numbers in Fragment Mono, nothing else.
struct SeasonView: View {
    let summary: SeasonSummary
    let sentence: String
    /// A drawer the person made: its name heads the sheet, and the sheet is where it is renamed or taken out (ADR-026).
    var drawer: String? = nil
    var rename: (() -> Void)? = nil
    var remove: (() -> Void)? = nil
    /// The figures are put down one after another when the sheet opens.
    @State private var placed = false

    var body: some View {
        ZStack {
            Paper()
            ScrollView {
                VStack(alignment: .leading, spacing: 34) {
                    if let drawer {
                        Text(drawer).displayText(17).foregroundStyle(Ink.grey)
                            .accessibilityAddTraits(.isHeader)
                            .padding(.bottom, -18)
                    }
                    Text(sentence)
                        .font(Type.italic(26))
                        .foregroundStyle(Ink.navy)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .contentTransition(.opacity)
                        .animation(Motion.place, value: sentence)

                    VStack(alignment: .leading, spacing: 22) {
                        Count("\(summary.films)", summary.films == 1 ? "film" : "films")
                            .placedInTurn(0, placed: placed)
                        Count("\(summary.cinemas.count)", summary.cinemas.count == 1 ? "cinema" : "cinemas")
                            .placedInTurn(1, placed: placed)
                        // The circuits, quietly: how many chains, and which (ADR-024).
                        if !summary.circuits.isEmpty {
                            Count("\(summary.circuits.count)", circuitsLine, size: 22)
                                .placedInTurn(2, placed: placed)
                        }
                        if summary.frontRow > 0 {
                            Count("\(summary.frontRow)", summary.frontRow == 1 ? "night in the front row" : "nights in the front row", size: 22)
                                .placedInTurn(2, placed: placed)
                        }
                        if let most = summary.mostVisited, most.count >= 2 {
                            Named(most.name, "most visited, \(SeasonSummary.times(most.count))")
                                .placedInTurn(2, placed: placed)
                        }
                        if let month = summary.busiestMonth {
                            Count(month.name, "busiest month, \(SeasonSummary.spelled(month.count)) \(month.count == 1 ? "film" : "films")", size: 22)
                                .placedInTurn(3, placed: placed)
                        }
                        if !summary.paid.isEmpty {
                            Count(paidLine, "paid", size: summary.paid.count == 1 ? 34 : 22)
                                .placedInTurn(4, placed: placed)
                        }
                    }
                    .onAppear { placed = true }

                    // Where the drawer is kept, said plainly (ADR-024).
                    Text(SharedStore.isSyncing ? "Kept on this phone and in your own iCloud, private to you."
                                               : "Kept on this phone only. Settings › Stub keeps it in your iCloud too.")
                        .font(Type.words(12)).foregroundStyle(Ink.grey)
                        .fixedSize(horizontal: false, vertical: true)

                    if let drawer, rename != nil || remove != nil {
                        HStack(spacing: 18) {
                            if let rename {
                                Button("Rename \(drawer)", action: rename).buttonStyle(.stub(.quiet))
                            }
                            if let remove {
                                Button(action: remove) {
                                    Text("Take the drawer out").foregroundStyle(Ink.rust)
                                }
                                .buttonStyle(.stub(.quiet))
                            }
                        }
                        .font(Type.words(14))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 36)
                .padding(.bottom, 48)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }

    /// "circuits: Event ×2 · Lighthouse · Rialto, and five nights at independents".
    private var circuitsLine: String {
        let named = summary.circuits.map { $0.count > 1 ? "\($0.name) ×\($0.count)" : $0.name }.joined(separator: " · ")
        let word = summary.circuits.count == 1 ? "circuit" : "circuits"
        guard summary.independents > 0 else { return "\(word): \(named)" }
        let nights = summary.independents == 1 ? "one night" : "\(SeasonSummary.spelled(summary.independents)) nights"
        return "\(word): \(named), and \(nights) at independents"
    }

    private var paidLine: String {
        summary.paid
            .map { $0.amount.formatted(.currency(code: $0.currency).precision(.fractionLength(2))) }
            .joined(separator: " · ")
    }
}

/// A number, large, in the mono; its label in quiet words beneath.
private struct Count: View {
    let value: String
    let label: String
    var size: CGFloat = 34
    init(_ value: String, _ label: String, size: CGFloat = 34) { self.value = value; self.label = label; self.size = size }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(Type.numbers(size)).foregroundStyle(Ink.ink)
            Text(label).font(Type.words(13)).foregroundStyle(Ink.grey)
        }
        .accessibilityElement(children: .combine)
    }
}

/// A name is words, not a number: Host Grotesk, not the mono (ADR-006).
private struct Named: View {
    let value: String
    let label: String
    init(_ value: String, _ label: String) { self.value = value; self.label = label }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).displayText(24).fixedSize(horizontal: false, vertical: true)
            Text(label).font(Type.words(13)).foregroundStyle(Ink.grey)
        }
        .accessibilityElement(children: .combine)
    }
}
