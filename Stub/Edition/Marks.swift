import SwiftUI
import UIKit

/// The card, in points. Every edition is composed at this size and scaled to wherever it is shown, so it is
/// the same card on every phone, in the print run and in a share.
enum Card {
    static let width: CGFloat = 330
    static let height: CGFloat = 528
    /// Where the poster ends and the tear-off strip begins: the perforation.
    static let poster: CGFloat = 408
    static let pad: CGFloat = 22
    static let corner: CGFloat = 10

    static var size: CGSize { CGSize(width: width, height: height) }
    static var posterRect: CGRect { CGRect(x: 0, y: 0, width: width, height: poster) }
    static var stripRect: CGRect { CGRect(x: 0, y: poster, width: width, height: height - poster) }
}

/// The three faces (ADR-006), with the weights an edition is allowed and the app's chrome is not
/// (DESIGN.md › Editions).
enum Face: Sendable {
    case groteskLight, groteskMedium, groteskBold, groteskExtraBold, serif, serifItalic, mono

    var postScriptName: String {
        switch self {
        case .groteskLight: "HostGrotesk-Light"
        case .groteskMedium: "HostGrotesk-Medium"
        case .groteskBold: "HostGrotesk-Bold"
        case .groteskExtraBold: "HostGrotesk-ExtraBold"
        case .serif: "Newsreader16pt-Regular"
        case .serifItalic: "Newsreader16pt-Italic"
        case .mono: "FragmentMono-Regular"
        }
    }

    /// Fixed, not scaled with Dynamic Type: the card is a picture of a ticket, and a title that grew with the
    /// reader's type size would push the composition off the card. The words on it are spoken whole instead.
    func font(_ size: CGFloat) -> Font { .custom(postScriptName, fixedSize: size) }
}

/// The order a card is printed in. The print run lays the plates down one at a time; foil is stamped last,
/// and whether a mark is foil is the stock's decision, not the plate's.
enum Plate: Int, Comparable, Sendable {
    case first = 1, second, type

    static func < (a: Plate, b: Plate) -> Bool { a.rawValue < b.rawValue }
    /// The pass the foil is stamped on, after every plate.
    static let foil = 4
}

/// One thing printed on the card: a shape or a line of words, an ink, a plate.
struct Mark: Sendable {
    enum Shape: Sendable {
        case rect(CGRect)
        case frame(CGRect, width: CGFloat)
        case circle(CGPoint, radius: CGFloat)
        case ring(CGPoint, radius: CGFloat, width: CGFloat, dash: [CGFloat] = [])
        case polygon([CGPoint])
        case outline([CGPoint], width: CGFloat)
        case line(CGPoint, CGPoint, width: CGFloat, dash: [CGFloat] = [])
        case words(Words)
        /// A dot screen whose dots swell toward `focus` and are gone at `reach`: a risograph's gradient.
        case halftone(CGRect, step: CGFloat, focus: CGPoint, reach: CGFloat, dot: CGFloat)
    }

    /// A line of type. `at` is on the baseline; `anchor` says which end of the line it is.
    struct Words: Sendable {
        var text: String
        var face: Face
        var size: CGFloat
        /// In ems, like `Type.displayTracking`.
        var tracking: CGFloat = 0
        var at: CGPoint
        var anchor: Anchor = .leading
        /// Shrunk to fit, never wrapped.
        var maxWidth: CGFloat? = nil
    }

    enum Anchor: Sendable { case leading, center, trailing }
    enum Blend: Sendable { case normal, multiply, screen }

    /// A rotation about a point, in degrees, clockwise on screen.
    struct Turn: Sendable {
        var degrees: Double
        var around: CGPoint
    }

    var shape: Shape
    var role: Role
    var plate: Plate
    var opacity: Double = 1
    /// Stamped in foil when the stock is foil or holographic; printed in its ink otherwise.
    var foil = false
    var turn: Turn? = nil
    var blend: Blend = .normal

    init(_ shape: Shape, _ role: Role, _ plate: Plate, opacity: Double = 1, foil: Bool = false, turn: Turn? = nil, blend: Blend = .normal) {
        self.shape = shape; self.role = role; self.plate = plate; self.opacity = opacity
        self.foil = foil; self.turn = turn; self.blend = blend
    }

    static func words(_ text: String, _ face: Face, _ size: CGFloat, at: CGPoint, _ role: Role, anchor: Anchor = .leading,
                      tracking: CGFloat = 0, maxWidth: CGFloat? = nil, opacity: Double = 1, plate: Plate = .type) -> Mark {
        Mark(.words(Words(text: text, face: face, size: size, tracking: tracking, at: at, anchor: anchor, maxWidth: maxWidth)),
             role, plate, opacity: opacity)
    }
}

/// How wide a line of type is, from the font itself. CoreText here; a canvas in `docs/editions/edition.js`.
enum Measure {
    static func width(_ text: String, face: Face, size: CGFloat, tracking: CGFloat = 0) -> CGFloat {
        let font = UIFont(name: face.postScriptName, size: size) ?? .systemFont(ofSize: size)
        let width = (text as NSString).size(withAttributes: [.font: font]).width
        return width + tracking * size * CGFloat(text.count)
    }
}

/// A title set as large as its box allows: one to `maxLines` lines, broken where the lines come out most even,
/// sized by measured width, never past `maxSize`.
struct Setting: Sendable {
    var lines: [String]
    var size: CGFloat

    enum Casing: Sendable { case asPrinted, upper, lower }
    /// Which line's baseline a title's `y` names: the last (the title sits on it) or the first (it hangs from it).
    enum Baseline: Sendable { case first, last }

    static func fit(_ text: String, width: CGFloat, height: CGFloat, maxSize: CGFloat, face: Face, lead: CGFloat = 0.95,
                    maxLines: Int = 4, casing: Casing = .asPrinted, tracking: CGFloat = 0) -> Setting {
        let cased = switch casing {
        case .asPrinted: text
        case .upper: text.uppercased()
        case .lower: text.lowercased()
        }
        let words = cased.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else { return Setting(lines: [cased], size: maxSize) }
        var best: Setting?
        for n in 1...min(maxLines, words.count) {
            let lines = balanced(words, into: n)
            let widest = lines.map { Measure.width($0, face: face, size: 1, tracking: tracking) }.max() ?? 1
            let size = min(maxSize, width / max(widest, 0.01), height / (CGFloat(n) * lead))
            // A line more has to earn half a point, or the fewer lines win.
            if best == nil || size > best!.size + 0.5 { best = Setting(lines: lines, size: size) }
        }
        return best!
    }

    /// `words` in `n` lines with the longest line as short as it can be. Brute force: titles are short.
    static func balanced(_ words: [String], into n: Int) -> [String] {
        guard n > 1, words.count > 1 else { return [words.joined(separator: " ")] }
        let n = min(n, words.count)
        var best: (longest: Int, lines: [String])?
        func split(from start: Int, left: Int, done: [String]) {
            if left == 1 {
                let all = done + [words[start...].joined(separator: " ")]
                let longest = all.map(\.count).max() ?? 0
                if best == nil || longest < best!.longest { best = (longest, all) }
                return
            }
            for end in (start + 1)...(words.count - left + 1) {
                split(from: end, left: left - 1, done: done + [words[start..<end].joined(separator: " ")])
            }
        }
        split(from: 0, left: n, done: [])
        return best?.lines ?? [words.joined(separator: " ")]
    }

    /// One mark per line, `lead` ems apart.
    func marks(x: CGFloat, y: CGFloat, face: Face, role: Role = .ink, anchor: Mark.Anchor = .leading, lead: CGFloat,
               tracking: CGFloat = 0, plate: Plate = .type, foil: Bool = false, turn: Mark.Turn? = nil, opacity: Double = 1,
               maxWidth: CGFloat? = nil, blend: Mark.Blend = .normal, from baseline: Baseline = .last) -> [Mark] {
        let step = size * lead
        let first = baseline == .last ? y - step * CGFloat(lines.count - 1) : y
        return lines.enumerated().map { i, line in
            Mark(.words(Mark.Words(text: line, face: face, size: size, tracking: tracking, at: CGPoint(x: x, y: first + CGFloat(i) * step),
                                   anchor: anchor, maxWidth: maxWidth)),
                 role, plate, opacity: opacity, foil: foil, turn: turn, blend: blend)
        }
    }
}

extension Dice {
    /// `between`, in points. One roll, the same as `between`, so the JavaScript specimen stays in step.
    mutating func span(_ low: CGFloat, _ high: CGFloat) -> CGFloat {
        CGFloat(between(Double(low), Double(high)))
    }
}
