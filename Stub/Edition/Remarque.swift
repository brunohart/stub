import SwiftUI
import UIKit

/// A remarque: the printmaker's word for a small mark that tells one impression from another. Here it is a punch
/// through the strip, the way a conductor punches a ticket: viewing *n* of a release has *n − 1* of them (brief §6.1).
///
/// A punch is a copy fact, like the seat: which viewing this card was. It is never the design. It goes through both
/// faces, so the table shows through the hole and the back has the same holes, mirrored. The shape is the movement's
/// own; where it falls is rolled from the release's seed inside the strip's clear zone, so the same viewing is punched
/// in the same place on every phone, and a punch never lands on a word or on the Aztec code.
struct Punch: Equatable, Sendable {
    /// The punch's die: the shape it cuts.
    enum Die: String, Sendable, CaseIterable {
        case square, circle, steppedDiamond, triangle, pair, slot, hexagon, crescent
    }

    var die: Die
    /// Its centre on the front, in card points.
    var centre: CGPoint
    /// How the punch was held, in degrees clockwise.
    var degrees: Double

    /// Every die fits inside a circle this big, in points: about three millimetres across on a card sixty-four wide. Any
    /// smaller and a cut shape reads as a printed glyph rather than a hole.
    static let radius: CGFloat = 8

    /// Where it lies on the front: the square its circle fits in.
    var bounds: CGRect {
        CGRect(x: centre.x - Self.radius, y: centre.y - Self.radius, width: Self.radius * 2, height: Self.radius * 2)
    }

    /// The hole, drawn into a card of `scale` points a card point with its top left at `origin`. `mirrored` is the
    /// hole seen from the back: the card turned over about its long axis, so the centre and the shape both flip.
    func path(scale: CGFloat, origin: CGPoint, mirrored: Bool) -> Path {
        var place = CGAffineTransform(translationX: centre.x, y: centre.y)
            .rotated(by: degrees * .pi / 180)
            .scaledBy(x: Self.radius, y: Self.radius)
        if mirrored {
            place = place.concatenating(CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: Card.width, ty: 0))
        }
        place = place.concatenating(CGAffineTransform(a: scale, b: 0, c: 0, d: scale, tx: origin.x, ty: origin.y))
        return die.unit.applying(place)
    }
}

extension Punch.Die {
    /// The die's outline inside the unit circle.
    var unit: Path {
        switch self {
        case .circle:
            return Path(ellipseIn: CGRect(x: -0.9, y: -0.9, width: 1.8, height: 1.8))
        case .square:
            return Path(CGRect(x: -0.7, y: -0.7, width: 1.4, height: 1.4))
        case .slot:
            return Path(roundedRect: CGRect(x: -1, y: -0.36, width: 2, height: 0.72), cornerRadius: 0.36)
        case .crescent:
            let moon = Path(ellipseIn: CGRect(x: -0.95, y: -0.95, width: 1.9, height: 1.9))
            return moon.subtracting(Path(ellipseIn: CGRect(x: -0.45, y: -1.1, width: 1.75, height: 1.75)))
        case .triangle:
            return Printer.closed((0..<3).map { Self.point(on: 1, at: -90 + Double($0) * 120) })
        case .hexagon:
            return Printer.closed((0..<6).map { Self.point(on: 0.92, at: Double($0) * 60) })
        case .pair:
            // Two discs a little out of register, the way a riso lays its two inks.
            return Path(ellipseIn: CGRect(x: -0.95, y: -0.72, width: 1.3, height: 1.3))
                .union(Path(ellipseIn: CGRect(x: -0.35, y: -0.58, width: 1.3, height: 1.3)))
        case .steppedDiamond:
            // Three steps a side, the way a deco border climbs.
            let s: CGFloat = 0.62, t: CGFloat = 0.2
            return Printer.closed([
                CGPoint(-t, -1), CGPoint(t, -1), CGPoint(t, -s), CGPoint(s, -s), CGPoint(s, -t), CGPoint(1, -t),
                CGPoint(1, t), CGPoint(s, t), CGPoint(s, s), CGPoint(t, s), CGPoint(t, 1), CGPoint(-t, 1),
                CGPoint(-t, s), CGPoint(-s, s), CGPoint(-s, t), CGPoint(-1, t), CGPoint(-1, -t), CGPoint(-s, -t),
                CGPoint(-s, -s), CGPoint(-t, -s),
            ])
        }
    }

    private static func point(on radius: CGFloat, at degrees: Double) -> CGPoint {
        CGPoint(x: radius * CGFloat(cos(degrees * .pi / 180)), y: radius * CGFloat(sin(degrees * .pi / 180)))
    }
}

extension Movement {
    /// The punch this movement's conductor carries, from the movement's own vocabulary.
    var punch: Punch.Die {
        switch self {
        case .swiss: .square
        case .constructivist: .circle
        case .deco: .steppedDiamond
        // A shard of cut paper.
        case .cutout: .triangle
        // Its two inks, out of register.
        case .riso: .pair
        // A rule, punched.
        case .letterpress: .slot
        // A nut, drawn to scale.
        case .blueprint: .hexagon
        // The night.
        case .noir: .crescent
        }
    }
}

/// Where the punches go.
enum Remarque {
    /// How far a punch keeps from a word, from the Aztec code and from another punch, in points, beyond its own edge.
    static let clearance: CGFloat = 3

    /// The punches for one copy: none for a first viewing, one for a second, *n − 1* for viewing *n*. Punch *k* is rolled
    /// from its own die, `punch/k`, so viewing 3's second punch never moves viewing 3's first. Each die rolls points in
    /// the strip until one is clear of every word on the front, the back's words and code seen through the card, and
    /// the punches before it; failing that, it bites the strip's edge, which is always clear. A viewing with nowhere
    /// left to punch goes unpunched rather than punching through a word.
    static func punches(for edition: Edition, copy: Copy, strip: [Mark]) -> [Punch] {
        guard copy.viewing > 1 else { return [] }
        let r = Punch.radius
        let keepOut = (strip.map(\.bounds) + EditionBack.clearZones(for: copy, edition: edition).map(mirror))
            .map { $0.insetBy(dx: -(r + clearance), dy: -(r + clearance)) }
        var placed: [Punch] = []
        func clear(_ p: CGPoint) -> Bool {
            !keepOut.contains { $0.contains(p) } && placed.allSatisfy { $0.centre.distance(to: p) >= 2 * r + clearance * 2 }
        }
        let inside = CGRect(x: 8 + r, y: Card.poster + 6 + r, width: Card.width - 2 * (8 + r),
                            height: Card.height - Card.poster - (6 + r) - (8 + r))
        for k in 2...copy.viewing {
            var dice = Dice(seed: edition.seed).fork("punch/\(k)")
            let degrees = dice.between(-24, 24)
            var found: CGPoint?
            for _ in 0..<96 where found == nil {
                let p = CGPoint(dice.span(inside.minX, inside.maxX), dice.span(inside.minY, inside.maxY))
                if clear(p) { found = p }
            }
            // The edges: the bottom of the strip, or either side below the notches. Half the punch is off the card.
            for _ in 0..<48 where found == nil {
                let p: CGPoint = switch dice.index(3) {
                case 0: CGPoint(dice.span(26, Card.width - 26), Card.height)
                case 1: CGPoint(0, dice.span(Card.poster + 18, Card.height - 22))
                default: CGPoint(Card.width, dice.span(Card.poster + 18, Card.height - 22))
                }
                if clear(p) { found = p }
            }
            guard let found else { continue }
            placed.append(Punch(die: edition.movement.punch, centre: found, degrees: degrees))
        }
        return placed
    }

    /// A rect on the back, as it lies on the front: the card turned over about its long axis.
    static func mirror(_ rect: CGRect) -> CGRect {
        CGRect(x: Card.width - rect.maxX, y: rect.minY, width: rect.width, height: rect.height)
    }

    /// "punched once", for VoiceOver; `nil` for a card with none.
    static func spoken(_ punches: [Punch]) -> String? {
        switch punches.count {
        case 0: nil
        case 1: "punched once"
        case 2: "punched twice"
        default: "punched \(Pencil.spelled(punches.count)) times"
        }
    }
}

// Arithmetic on the back's layout, so it belongs to no actor: `EditionBack` is a `View`, main-actor by inference, and a
// composition is drawn off it (a test, a share).
extension EditionBack {
    /// The back's strip: its inset from the card's edges, and the Aztec code's side, in points.
    nonisolated static let stripInset = CGSize(width: 20, height: 22)
    nonisolated static let codeSide: CGFloat = 62

    /// What on the back a punch must miss, in the back's own card points: the Aztec code, and the words beside it (which
    /// viewing, and the serial). Measured from the faces the back sets them in, so a longer "Eleventh viewing" is
    /// cleared as well as a "Second".
    nonisolated static func clearZones(for copy: Copy, edition: Edition) -> [CGRect] {
        let inset = stripInset
        let bottom = Card.height - inset.height
        let code = CGRect(x: Card.width - inset.width - codeSide, y: bottom - codeSide, width: codeSide, height: codeSide)
        let viewing = UIFont(name: Face.serifItalic.postScriptName, size: 14) ?? .italicSystemFont(ofSize: 14)
        let serial = UIFont(name: Face.mono.postScriptName, size: 11) ?? .monospacedSystemFont(ofSize: 11, weight: .regular)
        let width = max(Measure.width(copy.viewingWords, face: .serifItalic, size: 14),
                        Measure.width(Self.serial(edition), face: .mono, size: 11))
        let height = viewing.lineHeight + 4 + serial.lineHeight
        let words = CGRect(x: inset.width, y: bottom - height, width: width, height: height)
        return [code, words]
    }

    /// "No. 915EFA9A": the release's hash, which every copy of the edition carries.
    nonisolated static func serial(_ edition: Edition) -> String {
        "No. " + String(edition.seed >> 32, radix: 16).uppercased()
    }
}
