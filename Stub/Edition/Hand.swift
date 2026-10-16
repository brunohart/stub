import SwiftUI

/// The hand (ADR-045): a master's device laid under a movement's drawing, so that no two releases in one movement come out
/// alike and every edition carries a decision a designer would have made. The movement draws; the hand adds one move of
/// its own, under the movement's marks and clear of its type, in the edition's own inks. Drawn from the release's seed,
/// the same on every phone; the press's moves, the movement, the inks and the stock are untouched.
///
/// The devices, and whose they are (DESIGN.md › Editions rule 9):
/// - `overprint`, after Karel Martens's monoprints: the movement's hero printed again, twice, off register, in its other
///   inks, so the overlaps make colours no plate has; or, where a movement has no hero, discs overprinted on its grid.
/// - `grid`, after Wim Crouwel: the poster's module grid shown as points, and the cells the title's letters fall in filled.
/// - `sequence`, after Otl Aicher's Munich bands: one ink stepped toward the ground in bands across the space the type leaves.
/// - `scale`, after Corita Kent and Paula Scher: the title's first letter, enormous, cropped by the card, a pale overprint.
enum Hand: String, CaseIterable, Sendable {
    case overprint, grid, sequence, scale

    /// The hand's word on the colophon and the detail: plain, and nobody's name.
    var word: String {
        switch self {
        case .overprint: "overprinted"
        case .grid: "on the grid"
        case .sequence: "in sequence"
        case .scale: "at scale"
        }
    }

    /// The hands a movement admits: a device that would fight the movement's own grammar is never offered to it.
    static func admitted(by movement: Movement) -> [Hand] {
        switch movement {
        case .swiss: [.overprint, .grid, .scale]
        case .constructivist: [.overprint, .sequence]
        case .deco: [.overprint]
        case .cutout: [.overprint, .scale]
        case .riso: [.overprint, .sequence]
        case .letterpress: [.grid, .scale, .overprint]
        case .blueprint: [.overprint]
        case .noir: [.scale, .sequence]
        }
    }

    /// The release's hand.
    static func of(_ edition: Edition) -> Hand {
        var dice = Dice(seed: edition.seed).fork("hand")
        return dice.pick(admitted(by: edition.movement))
    }

    /// The marks the hand lays, to go under the movement's own, on the first plate.
    func marks(under poster: [Mark], edition: Edition, inks: EditionInks, field: Role) -> [Mark] {
        var dice = Dice(seed: edition.seed).fork("hand/\(rawValue)")
        let pass = Pass(field: field, inks: inks)
        let taken = Self.typeBounds(poster) + Self.heroBounds(poster) + Self.blocks(poster)
        switch self {
        case .overprint: return Self.overprint(poster, taken: taken, pass: pass, dice: &dice)
        case .grid: return Self.grid(poster, taken: taken, pass: pass, dice: &dice)
        case .sequence: return Self.sequence(taken: Self.typeBounds(poster), pass: pass, dice: &dice)
        case .scale: return Self.scale(poster, pass: pass, dice: &dice)
        }
    }

    /// How a hand prints on the field it lies on: multiplied into a light ground, screened onto a dark one, where the
    /// lighter of the inks carries it.
    private struct Pass {
        let light: Bool
        let blend: Mark.Blend
        let accent: Role
        let second: Role
        init(field: Role, inks: EditionInks) {
            light = EditionInks.luminance(inks.hex(field)) > 0.35
            blend = light ? .multiply : .screen
            accent = light ? .primary : .light
            second = light ? .secondary : .secondary
        }
    }

    // MARK: The devices

    /// The poster's module: six columns between the margins, and eight rows down to the perforation.
    private static var column: CGFloat { (Card.width - 2 * Card.pad) / 6 }
    private static var row: CGFloat { (Card.poster - 2 * Card.pad) / 8 }

    /// Overprint: the movement's disc printed twice more, stepped off register, in its other inks; or, with no disc, three
    /// discs overlapping where the type is not. Every form hit a second time, a point and a half off, faint.
    private static func overprint(_ poster: [Mark], taken: [CGRect], pass: Pass, dice: inout Dice) -> [Mark] {
        let angle = dice.pick([-30.0, -150.0, 30.0, 150.0, 0.0, 180.0, 90.0]) * .pi / 180
        let direction = CGPoint(x: cos(angle), y: sin(angle))
        let disc = poster.filter { $0.part != nil }.compactMap { mark -> (Mark, CGPoint, CGFloat)? in
            switch mark.shape {
            case .circle(let c, let r) where r >= 28: return (mark, c, r)
            case .ring(let c, let r, _, _) where r >= 28: return (mark, c, r)
            default: return nil
            }
        }.max { $0.2 < $1.2 }
        var laid: [Mark] = []
        if let (hero, centre, radius) = disc {
            let step = radius * dice.between(0.42, 0.6)
            let roles: [Role] = hero.role == pass.accent ? [pass.second, .ink] : [pass.accent, pass.second]
            for (k, role) in roles.enumerated() {
                let shift = step * CGFloat(k + 1)
                let at = CGPoint(x: centre.x + direction.x * shift, y: centre.y + direction.y * shift)
                let shape: Mark.Shape = if case .ring(_, _, let width, _) = hero.shape {
                    .ring(at, radius: radius, width: width * 2)
                } else {
                    .circle(at, radius: radius * (1 - 0.05 * CGFloat(k + 1)))
                }
                laid.append(Mark(shape, role == .ink && !pass.light ? .light : role, .first,
                                 opacity: k == 0 ? 0.6 : 0.42, blend: pass.blend))
            }
        } else {
            let radius = column * dice.between(0.95, 1.25)
            let step = radius * 1.05
            // The first clear place, scanning the grid from a corner the seed chooses.
            var nodes: [CGPoint] = []
            for r in stride(from: 1, through: 7, by: 1) {
                for c in stride(from: 1, through: 5, by: 1) {
                    nodes.append(CGPoint(x: Card.pad + CGFloat(c) * column, y: Card.pad + CGFloat(r) * row))
                }
            }
            if dice.chance(0.5) { nodes.reverse() }
            let fits = { (at: CGPoint) -> Bool in
                (0..<3).allSatisfy { k in
                    let c = CGPoint(x: at.x + direction.x * step * CGFloat(k), y: at.y + direction.y * step * CGFloat(k))
                    let disc = CGRect(x: c.x - radius, y: c.y - radius, width: 2 * radius, height: 2 * radius)
                    return !taken.contains { $0.insetBy(dx: -6, dy: -6).intersects(disc) }
                }
            }
            if let start = nodes.first(where: fits) {
                let roles: [Role] = [pass.accent, pass.second, pass.accent]
                for (k, role) in roles.enumerated() {
                    let at = CGPoint(x: start.x + direction.x * step * CGFloat(k), y: start.y + direction.y * step * CGFloat(k))
                    laid.append(Mark(.circle(at, radius: radius), role, .first, opacity: [0.78, 0.62, 0.38][k], blend: pass.blend))
                }
            }
        }
        let hit = CGPoint(x: dice.between(-1.6, 1.6), y: dice.between(-1.6, 1.6))
        return laid + laid.map { mark in
            var again = mark
            again.opacity *= 0.3
            switch mark.shape {
            case .circle(let c, let r): again.shape = .circle(CGPoint(x: c.x + hit.x, y: c.y + hit.y), radius: r)
            case .ring(let c, let r, let w, let d): again.shape = .ring(CGPoint(x: c.x + hit.x, y: c.y + hit.y), radius: r, width: w, dash: d)
            default: break
            }
            return again
        }
    }

    /// Grid: the module grid's register crosses, and the title's initial built from the grid's own cells, a monogram set
    /// in the first corner that is clear.
    private static func grid(_ poster: [Mark], taken: [CGRect], pass: Pass, dice: inout Dice) -> [Mark] {
        var laid: [Mark] = []
        let arm: CGFloat = 3
        for r in 0...8 {
            for c in 0...6 {
                let at = CGPoint(x: Card.pad + CGFloat(c) * column, y: Card.pad + CGFloat(r) * row)
                laid.append(Mark(.line(CGPoint(x: at.x - arm, y: at.y), CGPoint(x: at.x + arm, y: at.y), width: 0.6), .ink, .first, opacity: 0.38))
                laid.append(Mark(.line(CGPoint(x: at.x, y: at.y - arm), CGPoint(x: at.x, y: at.y + arm), width: 0.6), .ink, .first, opacity: 0.38))
            }
        }
        guard let initial = title(poster)?.uppercased().first(where: { Self.glyphs[String($0)] != nil }),
              let rows = Self.glyphs[String(initial)] else { return laid }
        let cell = column / 3
        let size = CGSize(width: cell * 5, height: cell * 7)
        let corners = [
            CGPoint(x: Card.pad, y: Card.pad), CGPoint(x: Card.width - Card.pad - size.width, y: Card.pad),
            CGPoint(x: Card.width - Card.pad - size.width, y: Card.poster - Card.pad - size.height),
            CGPoint(x: Card.pad, y: Card.poster - Card.pad - size.height),
        ]
        // The clear place nearest a corner the seed chooses, looking every half module.
        let corner = corners[dice.index(corners.count)]
        var places: [CGPoint] = []
        for y in stride(from: Card.pad, through: Card.poster - Card.pad - size.height, by: cell) {
            for x in stride(from: Card.pad, through: Card.width - Card.pad - size.width, by: cell) { places.append(CGPoint(x: x, y: y)) }
        }
        let clear = places.filter { o in !taken.contains { $0.insetBy(dx: -6, dy: -6).intersects(CGRect(origin: o, size: size)) } }
        guard let origin = clear.min(by: { hypot($0.x - corner.x, $0.y - corner.y) < hypot($1.x - corner.x, $1.y - corner.y) })
        else { return laid }
        for (y, line) in rows.enumerated() {
            for (x, on) in line.enumerated() where on == "#" {
                let square = CGRect(x: origin.x + CGFloat(x) * cell, y: origin.y + CGFloat(y) * cell, width: cell, height: cell)
                laid.append(Mark(.rect(square.insetBy(dx: 0.8, dy: 0.8)), pass.accent, .first, opacity: 0.9, blend: pass.blend))
            }
        }
        return laid
    }

    /// Sequence: one ink stepped toward the ground in bands, each shorter than the last, across the tallest stretch of
    /// the poster no type crosses.
    private static func sequence(taken: [CGRect], pass: Pass, dice: inout Dice) -> [Mark] {
        let edges = ([0, Card.poster] + taken.flatMap { [$0.minY - 6, $0.maxY + 6] }).map { min(max($0, 0), Card.poster) }.sorted()
        var best = (from: CGFloat(0), to: CGFloat(0))
        for (a, b) in zip(edges, edges.dropFirst()) where b - a > best.to - best.from {
            if !taken.contains(where: { $0.minY - 6 < b && $0.maxY + 6 > a }) { best = (a, b) }
        }
        let space = best.to - best.from
        guard space > 40 else { return [] }
        let count = min(7, max(4, Int(space / 22)))
        let band = space / CGFloat(count) * 0.62
        let gap = space / CGFloat(count) * 0.38
        let role: Role = pass.light ? (dice.chance(0.5) ? .primary : .secondary) : .light
        let fromLeft = dice.chance(0.5)
        return (0..<count).map { i in
            let y = best.from + CGFloat(i) * (band + gap) + gap / 2
            let width = Card.width * (1 - 0.1 * CGFloat(i))
            return Mark(.rect(CGRect(x: fromLeft ? 0 : Card.width - width, y: y, width: width, height: band)), role, .first,
                        opacity: (pass.light ? 0.9 : 0.5) * pow(0.68, Double(i)), blend: pass.blend)
        }
    }

    /// Scale: the title's first letter, larger than the poster, turned a few degrees and cropped by the card, a pale
    /// overprint under everything.
    private static func scale(_ poster: [Mark], pass: Pass, dice: inout Dice) -> [Mark] {
        guard let letter = title(poster)?.uppercased().first(where: { $0.isLetter || $0.isNumber }) else { return [] }
        let size = Card.poster * dice.between(0.92, 1.2)
        let at = CGPoint(x: Card.width * dice.between(0.3, 0.72), y: Card.poster * dice.between(0.72, 0.98))
        var mark = Mark.words(String(letter), .groteskExtraBold, size, at: at, pass.light ? .secondary : .light, anchor: .center, plate: .first)
        mark.opacity = pass.light ? 0.26 : 0.17
        mark.blend = pass.blend
        mark.turn = Mark.Turn(degrees: dice.between(-9, 9), around: at)
        return [mark]
    }

    /// The title's first line as the movement set it: the title part's, never a cinema or a caption.
    private static func title(_ poster: [Mark]) -> String? {
        let lines = poster.compactMap { mark -> String? in
            guard case .words(let w) = mark.shape, mark.part?.hasSuffix("/title") == true else { return nil }
            return w.text
        }
        return lines.first
    }

    /// The movement's large forms, which a device keeps clear of as it keeps clear of type.
    static func heroBounds(_ poster: [Mark]) -> [CGRect] {
        poster.compactMap { mark in
            guard mark.part != nil else { return nil }
            switch mark.shape {
            case .circle(let c, let r) where r >= 28: return CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)
            case .ring(let c, let r, _, _) where r >= 28: return CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)
            default: return nil
            }
        }
    }

    /// The movement's blocks: rectangles large enough to hide a device, short of the field it lays first.
    static func blocks(_ poster: [Mark]) -> [CGRect] {
        poster.compactMap { mark in
            guard mark.part != nil, case .rect(let rect) = mark.shape, mark.turn == nil else { return nil }
            let area = rect.width * rect.height
            return area > 1500 && area < 0.55 * Card.width * Card.poster ? rect : nil
        }
    }

    /// The hand's marks laid into the movement's: over the field it lays first, if it lays one, and under everything else.
    static func laid(_ hand: [Mark], into drawn: [Mark]) -> [Mark] {
        let poster = Card.width * Card.poster
        let fields = drawn.prefix { mark in
            switch mark.shape {
            case .rect(let rect): rect.width * rect.height >= 0.55 * poster
            case .halftone(let rect, _, _, _, _): rect.width * rect.height >= 0.55 * poster
            default: false
            }
        }.count
        return Array(drawn.prefix(fields)) + hand + Array(drawn.dropFirst(fields))
    }

    /// A five-by-seven alphabet on the grid, for the monogram.
    static let glyphs: [String: [String]] = [
        "A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
        "B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
        "C": [".####", "#....", "#....", "#....", "#....", "#....", ".####"],
        "D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
        "E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
        "F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
        "G": [".####", "#....", "#....", "#.###", "#...#", "#...#", ".###."],
        "H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
        "I": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "#####"],
        "J": ["..###", "...#.", "...#.", "...#.", "...#.", "#..#.", ".##.."],
        "K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
        "L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
        "M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
        "N": ["#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#", "#...#"],
        "O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
        "P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
        "Q": [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
        "R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
        "S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
        "T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
        "U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
        "V": ["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
        "W": ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "##.##", "#...#"],
        "X": ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
        "Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
        "Z": ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"],
        "0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
        "1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
        "2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
        "3": ["####.", "....#", "....#", ".###.", "....#", "....#", "####."],
        "4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
        "5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
        "6": [".###.", "#....", "#....", "####.", "#...#", "#...#", ".###."],
        "7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
        "8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
        "9": [".###.", "#...#", "#...#", ".####", "....#", "....#", ".###."]
    ]

    // MARK: Where the type is

    /// Every line of the poster's type as a box, turned as it is printed, so a device never prints across a word.
    static func typeBounds(_ poster: [Mark]) -> [CGRect] {
        poster.compactMap { mark in
            guard case .words(let w) = mark.shape else { return nil }
            let measured = Measure.width(w.text, face: w.face, size: w.size, tracking: w.tracking)
            let width = min(measured, w.maxWidth ?? measured)
            let x: CGFloat = switch w.anchor {
            case .leading: w.at.x
            case .center: w.at.x - width / 2
            case .trailing: w.at.x - width
            }
            let box = CGRect(x: x, y: w.at.y - w.size * 0.82, width: width, height: w.size * 1.08)
            guard let turn = mark.turn, turn.degrees != 0 else { return box }
            let t = CGAffineTransform(translationX: turn.around.x, y: turn.around.y)
                .rotated(by: turn.degrees * .pi / 180)
                .translatedBy(x: -turn.around.x, y: -turn.around.y)
            return box.applying(t)
        }
    }
}
