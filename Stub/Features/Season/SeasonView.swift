import SwiftUI

/// The season, on one sheet, set like the drawer's own record (ADR-034). The sentence in Newsreader, upright. Under
/// it the figures in a row, as a ticket prints its fields; the nights month by month, a dot a night, the busiest month
/// in the orange; and what has a name on ruled lines. One size for figures, one for words, one for labels.
struct SeasonView: View {
    let summary: SeasonSummary
    let sentence: String
    /// A drawer the person made: its name heads the sheet, and the sheet is where it is renamed or taken out (ADR-026).
    var drawer: String? = nil
    var rename: (() -> Void)? = nil
    var remove: (() -> Void)? = nil
    /// The figures are put down one after another when the sheet opens.
    @State private var placed = false
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ZStack {
            Paper()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let drawer {
                        Text(drawer).displayText(17).foregroundStyle(Ink.grey)
                            .accessibilityAddTraits(.isHeader)
                            .padding(.bottom, 16)
                    }
                    Text(sentence)
                        .font(Type.reading(26))
                        .foregroundStyle(Ink.navy)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .contentTransition(.opacity)
                        .animation(Motion.place, value: sentence)

                    // The figures in a row, as the ticket sets Date, Seat and Paid; they stack where they would not fit.
                    let row = AnyLayout(typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 18))
                                                                     : AnyLayout(HStackLayout(alignment: .top, spacing: 34)))
                    row {
                        Figure(summary.films == 1 ? "film" : "films", "\(summary.films)", size: 26)
                        Figure(summary.cinemas.count == 1 ? "cinema" : "cinemas", "\(summary.cinemas.count)", size: 26)
                        if !summary.paid.isEmpty { Figure("paid", paidLine, size: 26) }
                    }
                    .padding(.top, 30)
                    .placedInTurn(0, placed: placed)

                    if !summary.nights.isEmpty {
                        // Twelve columns where they fit; a ruled list of months at the accessibility sizes (decision 005).
                        Nights(summary: summary)
                            .padding(.top, 34)
                            .placedInTurn(1, placed: placed)
                    }

                    if !ledger.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(Array(ledger.enumerated()), id: \.offset) { i, line in
                                Line(label: line.label, value: line.value, accent: line.accent)
                                    .placedInTurn(2 + i, placed: placed)
                            }
                        }
                        .padding(.top, 30)
                    }

                    // Where the drawer is kept, said plainly (ADR-024).
                    Text(SharedStore.isSyncing ? "Kept on this phone and in your own iCloud, private to you."
                                               : "Kept on this phone only. Settings › Stub keeps it in your iCloud too.")
                        .font(Type.words(12)).foregroundStyle(Ink.grey)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 28)

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
                        .padding(.top, 22)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 36)
                .padding(.bottom, 48)
            }
        }
        .onAppear { placed = true }
        // The sheet's own ground: what shows above it at half height is the drawer, dimmed and out of reach (decision 005).
        .accessibilityIdentifier("sheet")
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }

    /// What has a name rather than a number, one fact to a ruled line.
    private var ledger: [(label: String, value: String, accent: Bool)] {
        var lines: [(label: String, value: String, accent: Bool)] = []
        if let most = summary.mostVisited, most.count >= 2 {
            lines.append(("Most visited", "\(most.name), \(SeasonSummary.times(most.count))", false))
        }
        if let month = summary.busiestMonth, month.count >= 2 {
            lines.append(("Busiest month", "\(month.name), \(SeasonSummary.spelled(month.count)) films", true))
        }
        if let day = summary.busiestWeekday, day.count >= 2, summary.weekdays.count >= 2 {
            lines.append(("Busiest day", "\(day.name)s, \(SeasonSummary.spelled(day.count)) films", false))
        }
        // The circuits, quietly: which chains and how often, and the nights at independents (ADR-024).
        if !summary.circuits.isEmpty {
            lines.append(("Circuits", summary.circuits.map { $0.count > 1 ? "\($0.name) ×\($0.count)" : $0.name }
                .joined(separator: " · "), false))
        }
        if summary.independents > 0 {
            lines.append(("Independents", nights(summary.independents), false))
        }
        if summary.frontRow > 0 {
            lines.append(("Front row", nights(summary.frontRow), false))
        }
        return lines
    }

    private func nights(_ n: Int) -> String { n == 1 ? "one night" : "\(SeasonSummary.spelled(n)) nights" }

    /// One currency to a line, the largest sum first, so a second currency never breaks the first in two.
    private var paidLine: String {
        summary.paid
            .sorted { $0.amount > $1.amount }
            .map { $0.amount.formatted(.currency(code: $0.currency).precision(.fractionLength(2))) }
            .joined(separator: "\n")
    }
}

/// The season month by month: a row for each year, newest first, a column for each month, and a dot for each night,
/// stacked on the year's line like stubs on a shelf. The busiest month is in the orange, the sheet's one mark.
private struct Nights: View {
    let summary: SeasonSummary
    @ScaledMetric(relativeTo: .caption) private var yearWidth: CGFloat = 44
    @ScaledMetric(relativeTo: .caption) private var dot: CGFloat = 6
    @Environment(\.dynamicTypeSize) private var typeSize

    /// More nights than this in one month are written as a number rather than drawn.
    private let most = 8

    var body: some View {
        if typeSize.isAccessibilitySize { months } else { calendar }
    }

    /// At the accessibility sizes: the months that had nights, one to a ruled line, at the person's own size.
    private var months: some View {
        VStack(spacing: 0) {
            ForEach(years, id: \.self) { year in
                ForEach(Array((summary.nights[year] ?? []).enumerated()).filter { $0.element > 0 }, id: \.offset) { month, count in
                    HStack(alignment: .firstTextBaseline) {
                        Text(verbatim: "\(Calendar.current.monthSymbols[month]) \(year)").font(Type.words(15)).foregroundStyle(Ink.ink)
                        Spacer(minLength: 12)
                        Text(count == 1 ? "One night" : "\(SeasonSummary.spelled(count).prefix(1).uppercased() + SeasonSummary.spelled(count).dropFirst()) nights")
                            .font(Type.words(15)).foregroundStyle(isBusiest(year, month) ? Ink.orange : Ink.grey)
                    }
                    .padding(.vertical, 10)
                    .overlay(alignment: .bottom) { Rectangle().fill(Ink.ink.opacity(0.14)).frame(height: 0.5) }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private var calendar: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 0) {
                Color.clear.frame(width: yearWidth, height: 1)
                ForEach(Array(Calendar.current.veryShortMonthSymbols.enumerated()), id: \.offset) { _, initial in
                    Text(initial).font(Type.words(12)).foregroundStyle(Ink.grey).frame(maxWidth: .infinity)
                }
            }
            ForEach(years, id: \.self) { year in
                let counts = summary.nights[year] ?? Array(repeating: 0, count: 12)
                let tallest = min(max(counts.max() ?? 0, 1), most)
                HStack(alignment: .bottom, spacing: 0) {
                    Text(String(year)).font(Type.numbers(12)).foregroundStyle(Ink.grey)
                        .frame(width: yearWidth, alignment: .leading)
                    ForEach(0..<12, id: \.self) { month in
                        column(counts[month], busiest: isBusiest(year, month))
                            .frame(maxWidth: .infinity, minHeight: CGFloat(tallest) * (dot + 2), alignment: .bottom)
                    }
                }
                .padding(.bottom, 6)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Ink.ink.opacity(0.14)).frame(height: 0.5).padding(.leading, yearWidth)
                }
            }
        }
        // One element, read year by year as its months: "2024: February, one night; March, four nights". Each year's row
        // was its own element once, and too small to touch (decision 005).
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Nights by month")
        .accessibilityValue(years.map { "\($0): \(spoken($0))" }.joined(separator: ". "))
    }

    @ViewBuilder private func column(_ count: Int, busiest: Bool) -> some View {
        let ink = busiest ? Ink.orange : Ink.soft(0.78)
        if count > most {
            Text("\(count)").font(Type.numbers(12)).foregroundStyle(ink)
        } else {
            VStack(spacing: 2) {
                ForEach(0..<count, id: \.self) { _ in Circle().fill(ink).frame(width: dot, height: dot) }
            }
        }
    }

    /// Every year from the first night to the last, newest first: an empty year is part of the season too.
    private var years: [Int] {
        guard let first = summary.nights.keys.min(), let last = summary.nights.keys.max() else { return [] }
        return Array((first...last).reversed())
    }

    private func isBusiest(_ year: Int, _ month: Int) -> Bool {
        guard let busiest = summary.busiestMonth, busiest.count >= 2 else { return false }
        return busiest.name == "\(Calendar.current.monthSymbols[month]) \(year)"
    }

    private func spoken(_ year: Int) -> String {
        let months = (summary.nights[year] ?? []).enumerated().compactMap { month, count -> String? in
            count == 0 ? nil : "\(Calendar.current.monthSymbols[month]), \(count == 1 ? "one night" : "\(count) nights")"
        }
        return months.isEmpty ? "No nights" : months.joined(separator: "; ")
    }
}

/// One ruled line of the ledger: the label in the quiet grey, the fact in words. The label stands above the fact
/// where the two would not fit side by side.
private struct Line: View {
    let label: String
    let value: String
    var accent = false
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var labelWidth: CGFloat = 112

    var body: some View {
        let layout = AnyLayout(typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                                                            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 12)))
        layout {
            Text(label).font(Type.words(13)).foregroundStyle(Ink.grey)
                // The busiest month's line wears the calendar's orange dot, hung in the margin so the labels stay in line.
                .overlay(alignment: .leading) {
                    if accent { Circle().fill(Ink.orange).frame(width: 6, height: 6).offset(x: -13).accessibilityHidden(true) }
                }
                .frame(width: typeSize.isAccessibilitySize ? nil : labelWidth, alignment: .leading)
            Text(value.prefix(1).uppercased() + value.dropFirst()).font(Type.words(15)).foregroundStyle(Ink.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 13)
        .overlay(alignment: .bottom) { Rectangle().fill(Ink.ink.opacity(0.14)).frame(height: 0.5) }
        .accessibilityElement(children: .combine)
    }
}
