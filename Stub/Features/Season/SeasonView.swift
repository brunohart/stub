import SwiftUI

/// The season, on one sheet. The sentence in Newsreader italic, the numbers in Fragment Mono, nothing else.
struct SeasonView: View {
    let summary: SeasonSummary
    let sentence: String

    var body: some View {
        ZStack {
            Paper()
            ScrollView {
                VStack(alignment: .leading, spacing: 34) {
                    Text(sentence)
                        .font(Type.italic(26))
                        .foregroundStyle(Ink.navy)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .contentTransition(.opacity)
                        .animation(Motion.place, value: sentence)

                    VStack(alignment: .leading, spacing: 22) {
                        Count("\(summary.films)", summary.films == 1 ? "film" : "films")
                        Count("\(summary.cinemas.count)", summary.cinemas.count == 1 ? "cinema" : "cinemas")
                        if let most = summary.mostVisited, most.count >= 2 {
                            Named(most.name, "most visited, \(SeasonSummary.times(most.count))")
                        }
                        if let month = summary.busiestMonth {
                            Count(month.name, "busiest month, \(SeasonSummary.spelled(month.count)) \(month.count == 1 ? "film" : "films")", size: 22)
                        }
                        if !summary.paid.isEmpty {
                            Count(paidLine, "paid", size: summary.paid.count == 1 ? 34 : 22)
                        }
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
