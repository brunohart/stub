import SwiftUI

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
        if LookEngine.current.isMetal {
            // One layer, two plates: the shader samples the text's own alpha shifted by `offset`
            // and lays orange under it wherever the ink is not.
            Text(text)
                .font(Type.display(size)).tracking(Type.displayTracking(size))
                .foregroundStyle(Ink.ink)
                .layerEffect(
                    ShaderLibrary.misregister(.float2(offset), .color(Ink.orange), .float(amount)),
                    maxSampleOffset: CGSize(width: abs(offset.width) + 1, height: abs(offset.height) + 1)
                )
        } else {
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
