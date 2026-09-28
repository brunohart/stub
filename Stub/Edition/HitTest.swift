import CoreGraphics

/// Which part a finger is on (ADR-016). In card space, against each mark's own shape, from the top of the card down.
/// SwiftUI's hit-testing knows nothing of marks drawn inside a `Canvas`, so the press asks the composition.
extension Composition {
    /// The part under `point` (card points), or `nil` for bare stock. `slop` widens hairlines and small shapes to a
    /// finger; a filled shape is hit only inside itself.
    func part(at point: CGPoint, slop: CGFloat = 6) -> Part.ID? {
        guard Card.posterRect.contains(point) else { return nil }
        return hitOrder.first { $0.contains(point, slop: slop) }?.part
    }

    /// The poster's marks from the top of the card down, as `EditionFace` stacks them: the type, then the foil, then
    /// the second plate, then the first; within a layer, the last drawn first.
    var hitOrder: [Mark] {
        let metallic = isMetallic
        func layer(_ mark: Mark) -> Int {
            if metallic, mark.foil { return 3 }
            switch mark.plate {
            case .first: return 1
            case .second: return 2
            case .type: return 4
            }
        }
        return poster.enumerated()
            .sorted { (layer($0.element), $0.offset) > (layer($1.element), $1.offset) }
            .map(\.element)
    }

    /// Where a part lies on the poster, for VoiceOver's rotor: every mark's bounds together, cut to the poster.
    func bounds(of part: Part.ID) -> CGRect? {
        let rect = poster.filter { $0.part == part }.map(\.bounds).reduce(CGRect.null) { $0.union($1) }
        let cut = rect.intersection(Card.posterRect)
        return cut.isNull || cut.isEmpty ? nil : cut
    }
}

extension Mark {
    func contains(_ point: CGPoint, slop: CGFloat) -> Bool {
        let p = turn.map { $0.unturning(point) } ?? point
        switch shape {
        case .rect(let rect):
            return rect.contains(p)
        case .frame(let rect, let width):
            return rect.insetBy(dx: -width / 2 - slop, dy: -width / 2 - slop).contains(p)
                && !rect.insetBy(dx: width / 2 + slop, dy: width / 2 + slop).contains(p)
        case .circle(let centre, let radius):
            return p.distance(to: centre) <= radius
        case .ring(let centre, let radius, let width, _):
            return abs(p.distance(to: centre) - radius) <= width / 2 + slop
        case .polygon(let points):
            return Self.inside(p, points)
        case .outline(let points, let width):
            return zip(points, points.dropFirst() + points.prefix(1)).contains { p.distance(toSegment: $0, $1) <= width / 2 + slop }
        case .line(let a, let b, let width, _):
            return p.distance(toSegment: a, b) <= width / 2 + slop
        case .words(let words):
            return words.box.insetBy(dx: -slop / 2, dy: -slop / 2).contains(p)
        case .halftone(let rect, _, let focus, let reach, _):
            // The dots are gone before the edge of their reach (`Printer.dots`).
            return rect.contains(p) && p.distance(to: focus) < reach * 0.96
        }
    }

    /// The mark's extent on the card, turned.
    var bounds: CGRect {
        let flat: CGRect = switch shape {
        case .rect(let rect): rect
        case .frame(let rect, let width): rect.insetBy(dx: -width / 2, dy: -width / 2)
        case .circle(let c, let r): CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)
        case .ring(let c, let r, let w, _): CGRect(x: c.x - r - w / 2, y: c.y - r - w / 2, width: r * 2 + w, height: r * 2 + w)
        case .polygon(let points), .outline(let points, _): Self.enclosing(points)
        case .line(let a, let b, let w, _): Self.enclosing([a, b]).insetBy(dx: -w / 2, dy: -w / 2)
        case .words(let words): words.box
        case .halftone(let rect, _, let f, let reach, _):
            rect.intersection(CGRect(x: f.x - reach, y: f.y - reach, width: reach * 2, height: reach * 2))
        }
        guard let turn, !flat.isNull else { return flat }
        let corners = [CGPoint(x: flat.minX, y: flat.minY), CGPoint(x: flat.maxX, y: flat.minY),
                       CGPoint(x: flat.maxX, y: flat.maxY), CGPoint(x: flat.minX, y: flat.maxY)]
        return Self.enclosing(corners.map(turn.turning))
    }

    static func enclosing(_ points: [CGPoint]) -> CGRect {
        guard let first = points.first else { return .null }
        return points.dropFirst().reduce(CGRect(origin: first, size: .zero)) { $0.union(CGRect(origin: $1, size: .zero)) }
    }

    /// Even-odd, as the canvas fills.
    static func inside(_ p: CGPoint, _ points: [CGPoint]) -> Bool {
        var inside = false
        var j = points.count - 1
        for i in points.indices {
            let a = points[i], b = points[j]
            if (a.y > p.y) != (b.y > p.y), p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x { inside.toggle() }
            j = i
        }
        return inside
    }
}

extension Mark.Words {
    /// The line's box: its measured width, shrunk to `maxWidth` as the printer shrinks it, from a little above the
    /// cap height to a little below the baseline.
    var box: CGRect {
        var width = Measure.width(text, face: face, size: size, tracking: tracking)
        var size = self.size
        if let maxWidth, width > maxWidth, width > 0 {
            size *= maxWidth / width
            width = maxWidth
        }
        let x: CGFloat = switch anchor {
        case .leading: at.x
        case .center: at.x - width / 2
        case .trailing: at.x - width
        }
        return CGRect(x: x, y: at.y - size * 0.78, width: width, height: size)
    }
}

extension Mark.Turn {
    /// A point on the turned mark, carried back to where it would be unturned.
    func unturning(_ p: CGPoint) -> CGPoint { rotate(p, by: -degrees) }
    /// A point on the unturned mark, carried to where the turn puts it.
    func turning(_ p: CGPoint) -> CGPoint { rotate(p, by: degrees) }

    private func rotate(_ p: CGPoint, by degrees: Double) -> CGPoint {
        let a = degrees * .pi / 180
        let dx = Double(p.x - around.x), dy = Double(p.y - around.y)
        return CGPoint(x: around.x + CGFloat(dx * cos(a) - dy * sin(a)), y: around.y + CGFloat(dx * sin(a) + dy * cos(a)))
    }
}

extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat { hypot(x - other.x, y - other.y) }

    func distance(toSegment a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x, dy = b.y - a.y
        let length = dx * dx + dy * dy
        guard length > 0 else { return distance(to: a) }
        let t = max(0, min(1, ((x - a.x) * dx + (y - a.y) * dy) / length))
        return distance(to: CGPoint(x: a.x + t * dx, y: a.y + t * dy))
    }
}
