import SwiftUI

#if DEBUG || PERF
/// `-a11y-lab`: the app's type in each of its inks, sizes and tilts on one sheet, so the accessibility audit's contrast
/// check can be read against known colours (docs/decisions/005-accessibility.md). Never in a Release build.
struct ContrastLab: View {
    private let inks: [(String, UInt32)] = [("A", 0x8A8578), ("B", 0x5A574E), ("C", 0x48463F), ("D", 0x3A3833), ("E", 0x1A1A1A)]

    var body: some View {
        if ProcessInfo.processInfo.arguments.contains("-a11y-lab-card") { card } else { sheet }
    }

    /// Your card's printed card, and variants of what it does, to find what the audit's contrast check objects to.
    private var card: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                mock("R1 rotated gradient card").rotationEffect(.degrees(-0.6))
                mock("R2 level gradient card")
                mock("R3 rotated plain card", plain: true).rotationEffect(.degrees(-0.6))
                mock("R8 level shadowed card", shadowed: true)
                Text("R5 identity scale").font(Type.words(12)).foregroundStyle(Ink.grey).scaleEffect(1)
                Text("R6 identity offset").font(Type.words(12)).foregroundStyle(Ink.grey).offset(y: 0)
                Text("R7 placed in turn").font(Type.words(12)).foregroundStyle(Ink.grey).placedInTurn(0, placed: true)
                VStack { Text("R9 contained").font(Type.words(12)).foregroundStyle(Ink.grey) }
                    .accessibilityElement(children: .contain)
                VStack { Text("R10 combined").font(Type.words(12)).foregroundStyle(Ink.grey) }
                    .accessibilityElement(children: .combine)
                VStack { Text("R11 ignored").font(Type.words(12)).foregroundStyle(Ink.grey) }
                    .accessibilityElement(children: .ignore).accessibilityLabel("R11")
            }
            .padding(20)
        }
        .background(Ink.paper)
    }

    private func mock(_ words: String, plain: Bool = false, shadowed: Bool = false) -> some View {
        Text(words).font(Type.words(12)).foregroundStyle(Ink.grey)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(plain ? AnyShapeStyle(Ink.cream)
                                : AnyShapeStyle(LinearGradient(colors: [Ink.cream, Color(hex: 0xEDE4CF)], startPoint: .topLeading, endPoint: .bottomTrailing)))
                    .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Ink.navy.opacity(shadowed ? 0.12 : 0)).offset(x: 5, y: 6))
            }
    }

    private var sheet: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(inks, id: \.0) { name, hex in
                HStack(spacing: 10) {
                    Text("\(name) words eleven").font(Type.words(11))
                    Text("\(name) words thirteen").font(Type.words(13))
                    Text("\(name)12 MONO").font(Type.numbers(12))
                }
                .foregroundStyle(Color(hex: hex))
            }
            Text("E display sixteen level").font(Type.display(16)).foregroundStyle(Ink.ink)
            Text("E display sixteen tilted").font(Type.display(16)).foregroundStyle(Ink.ink).rotationEffect(.degrees(-1.5))
            Text("E words thirteen tilted").font(Type.words(13)).foregroundStyle(Ink.ink).rotationEffect(.degrees(-0.6))
            Text("E15 MONO TILTED").font(Type.numbers(15)).foregroundStyle(Ink.ink).rotationEffect(.degrees(-0.6))
            Text("B words thirteen tilted").font(Type.words(13)).foregroundStyle(Ink.grey).rotationEffect(.degrees(-0.6))
            Text("E15 MONO LEVEL").font(Type.numbers(15)).foregroundStyle(Ink.ink)
            Text("S75 11 MONO").font(Type.numbers(11)).foregroundStyle(Ink.soft(0.75))
            Text("S85 11 MONO").font(Type.numbers(11)).foregroundStyle(Ink.soft(0.85))
            VStack(alignment: .leading, spacing: 6) {
                Text("B words twelve on cream").font(Type.words(12)).foregroundStyle(Ink.grey)
                Text("E words twelve on cream").font(Type.words(12)).foregroundStyle(Ink.ink)
                Text("C words twelve on cream").font(Type.words(12)).foregroundStyle(Color(hex: 0x48463F))
            }
            .padding(12)
            .background(LinearGradient(colors: [Ink.cream, Color(hex: 0xEDE4CF)], startPoint: .topLeading, endPoint: .bottomTrailing))
            VStack(alignment: .leading, spacing: 6) {
                Text("B words twelve on manila").font(Type.words(12)).foregroundStyle(Ink.grey)
                Text("E words twelve on manila").font(Type.words(12)).foregroundStyle(Ink.ink)
            }
            .padding(12)
            .background(Color(hex: 0xEFE5CF))
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Ink.paper)
    }
}
#endif
