import SwiftUI

/// Two faces and a mono, never a fourth.
/// Host Grotesk for words. Newsreader for the one italic moment and for reading. Fragment Mono for numbers only.
/// Hierarchy comes from size and space, never from weight.
enum Type {
    static func display(_ size: CGFloat) -> Font { .custom("HostGrotesk-Medium", size: size) }
    static func words(_ size: CGFloat) -> Font { .custom("HostGrotesk-Regular", size: size) }
    static func stamp(_ size: CGFloat) -> Font { .custom("HostGrotesk-SemiBold", size: size) }
    static func reading(_ size: CGFloat) -> Font { .custom("Newsreader16pt-Regular", size: size) }
    static func italic(_ size: CGFloat) -> Font { .custom("Newsreader16pt-Italic", size: size) }
    static func numbers(_ size: CGFloat) -> Font { .custom("FragmentMono-Regular", size: size) }

    /// Display tracking: -0.03em.
    static func displayTracking(_ size: CGFloat) -> CGFloat { -0.03 * size }
}

extension View {
    /// Host Grotesk 500, tight, for the words that carry the screen.
    func displayText(_ size: CGFloat) -> some View {
        self.font(Type.display(size)).tracking(Type.displayTracking(size)).foregroundStyle(Ink.ink)
    }
    /// Fragment Mono for anything that is a number: a date, a seat, a price.
    func numberText(_ size: CGFloat) -> some View {
        self.font(Type.numbers(size)).foregroundStyle(Ink.ink.opacity(0.75))
    }
}

/// Display words with the misregistered orange plate behind them. One colour pass that did not line up.
struct DisplayTitle: View {
    let text: String
    let size: CGFloat
    var offset: CGSize = CGSize(width: 3, height: 1.5)
    var amount: Double = 0.3

    init(_ text: String, size: CGFloat, offset: CGSize = CGSize(width: 3, height: 1.5), amount: Double = 0.3) {
        self.text = text; self.size = size; self.offset = offset; self.amount = amount
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Text(text)
                .font(Type.display(size)).tracking(Type.displayTracking(size))
                .foregroundStyle(Ink.orange.opacity(amount))
                .offset(x: offset.width, y: offset.height)
                .blendMode(.multiply)
                .accessibilityHidden(true)
            Text(text)
                .font(Type.display(size)).tracking(Type.displayTracking(size))
                .foregroundStyle(Ink.ink)
        }
    }
}

#if DEBUG
enum FontAudit {
    /// Prints which brand faces actually registered. Run once at launch in Debug so a missing font is a log line, not a guess.
    static func run() {
        let wanted = ["Host Grotesk", "Newsreader", "Fragment Mono"]
        for family in wanted {
            let names = UIFont.fontNames(forFamilyName: family)
            print("[fonts] \(family): \(names.isEmpty ? "MISSING" : names.joined(separator: ", "))")
        }
    }
}
#endif
