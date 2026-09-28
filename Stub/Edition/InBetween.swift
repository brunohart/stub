import CoreGraphics

/// The space between two takes (ADR-016). The wheel does not cut from take 13 to take 14; it draws what lies between
/// them, the way an animator draws the in-betweens between two key drawings.
extension Composition {
    /// The poster `t` of the way from `a` to `b`. Marks are paired by part and by their place within the part. A pair
    /// of the same shape, ink and plate interpolates its numbers; anything else (a mark only one of them has, a pair
    /// whose shape or words differ, and the halftone, whose dots are too many to redraw every frame) cross-fades.
    /// Only the part being turned differs between two takes, so only its marks move: the dependency rule, made visible.
    ///
    /// `between(a, b, t: 0)` is `a.poster` and `between(a, b, t: 1)` is `b.poster`, exactly.
    static func between(_ a: Composition, _ b: Composition, t: CGFloat) -> [Mark] {
        if t <= 0 { return a.poster }
        if t >= 1 { return b.poster }
        let from = grouped(a.poster), to = grouped(b.poster)
        var order = from.map(\.part)
        for group in to where !order.contains(group.part) { order.append(group.part) }
        var marks: [Mark] = []
        for part in order {
            let xs = from.first { $0.part == part }?.marks ?? []
            let ys = to.first { $0.part == part }?.marks ?? []
            for i in 0..<max(xs.count, ys.count) {
                let x = i < xs.count ? xs[i] : nil
                let y = i < ys.count ? ys[i] : nil
                if let x, let y, x == y {
                    marks.append(x)
                } else if let x, let y, let mark = Mark.lerp(x, y, t) {
                    marks.append(mark)
                } else {
                    if let x { marks.append(x.faded(1 - t)) }
                    if let y { marks.append(y.faded(t)) }
                }
            }
        }
        return marks
    }

    /// The poster's marks by part, in the order the parts are drawn. A movement draws each part's marks together, so
    /// this keeps the drawing order.
    private static func grouped(_ marks: [Mark]) -> [(part: Part.ID?, marks: [Mark])] {
        var groups: [(part: Part.ID?, marks: [Mark])] = []
        for mark in marks {
            if let last = groups.indices.last, groups[last].part == mark.part {
                groups[last].marks.append(mark)
            } else {
                groups.append((mark.part, [mark]))
            }
        }
        return groups
    }
}

extension Mark {
    /// `a` and `b` interpolated, or `nil` when they are not the same kind of mark.
    static func lerp(_ a: Mark, _ b: Mark, _ t: CGFloat) -> Mark? {
        guard a.role == b.role, a.plate == b.plate, a.foil == b.foil, a.blend == b.blend, a.part == b.part,
              let shape = Shape.lerp(a.shape, b.shape, t) else { return nil }
        var mark = a
        mark.shape = shape
        mark.opacity = Double(mix(CGFloat(a.opacity), CGFloat(b.opacity), t))
        mark.turn = Turn.lerp(a.turn, b.turn, t)
        return mark
    }

    /// This mark at `amount` of its own opacity.
    func faded(_ amount: CGFloat) -> Mark {
        var mark = self
        mark.opacity *= Double(amount)
        return mark
    }
}

extension Mark.Shape {
    static func lerp(_ a: Mark.Shape, _ b: Mark.Shape, _ t: CGFloat) -> Mark.Shape? {
        switch (a, b) {
        case let (.rect(x), .rect(y)):
            return .rect(mix(x, y, t))
        case let (.frame(x, wx), .frame(y, wy)):
            return .frame(mix(x, y, t), width: mix(wx, wy, t))
        case let (.circle(cx, rx), .circle(cy, ry)):
            return .circle(mix(cx, cy, t), radius: mix(rx, ry, t))
        case let (.ring(cx, rx, wx, dx), .ring(cy, ry, wy, dy)) where dx == dy:
            return .ring(mix(cx, cy, t), radius: mix(rx, ry, t), width: mix(wx, wy, t), dash: dx)
        case let (.polygon(px), .polygon(py)) where px.count == py.count:
            return .polygon(zip(px, py).map { mix($0, $1, t) })
        case let (.outline(px, wx), .outline(py, wy)) where px.count == py.count:
            return .outline(zip(px, py).map { mix($0, $1, t) }, width: mix(wx, wy, t))
        case let (.line(ax, bx, wx, dx), .line(ay, by, wy, dy)) where dx == dy:
            return .line(mix(ax, ay, t), mix(bx, by, t), width: mix(wx, wy, t), dash: dx)
        case let (.words(x), .words(y)) where x.text == y.text && x.face == y.face && x.anchor == y.anchor
            && (x.maxWidth == nil) == (y.maxWidth == nil):
            var words = x
            words.at = mix(x.at, y.at, t)
            words.size = mix(x.size, y.size, t)
            words.tracking = mix(x.tracking, y.tracking, t)
            if let mx = x.maxWidth, let my = y.maxWidth { words.maxWidth = mix(mx, my, t) }
            return .words(words)
        default:
            // The halftone included: a dot screen rebuilt every frame of a scrub is the one mark likely to drop frames
            // (brief §4.5), so its takes cross-fade between two screens whose dots are cached (`Printer.dots`).
            return nil
        }
    }
}

extension Mark.Turn {
    /// A turn that is absent is a turn of nothing about the other's centre.
    static func lerp(_ a: Mark.Turn?, _ b: Mark.Turn?, _ t: CGFloat) -> Mark.Turn? {
        switch (a, b) {
        case (nil, nil): return nil
        case let (x?, nil): return Mark.Turn(degrees: Double(mix(CGFloat(x.degrees), 0, t)), around: x.around)
        case let (nil, y?): return Mark.Turn(degrees: Double(mix(0, CGFloat(y.degrees), t)), around: y.around)
        case let (x?, y?): return Mark.Turn(degrees: Double(mix(CGFloat(x.degrees), CGFloat(y.degrees), t)), around: mix(x.around, y.around, t))
        }
    }
}

/// `a` at 0, `b` at 1, each exactly.
func mix(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a * (1 - t) + b * t }
func mix(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint { CGPoint(x: mix(a.x, b.x, t), y: mix(a.y, b.y, t)) }
func mix(_ a: CGRect, _ b: CGRect, _ t: CGFloat) -> CGRect {
    CGRect(x: mix(a.minX, b.minX, t), y: mix(a.minY, b.minY, t), width: mix(a.width, b.width, t), height: mix(a.height, b.height, t))
}
