import CoreGraphics

/// What the press does to a part (ADR-031): a named, designed move, the same set on every part of every movement, engraved
/// round the dial. As drawn is the title's own drawing, exactly; the others redraw the part's marks as a printer would
/// rework a plate: larger or smaller, turned, echoed in fading repeats, cut to an outline, mirrored to the other side of the
/// sheet, its two inks swapped, or redrawn from another roll of its die. A frame carries what hangs from it when it is made
/// larger, smaller, turned or mirrored, so the title stays in its band; it echoes, outlines and swaps its own marks only.
///
/// Every move is geometry: a part's shapes rewritten, never a transform laid over the drawing, so the printer, the widget,
/// the hit test, the punches and the in-betweens all read the result as they read any mark.
enum Treatment: Int, CaseIterable, Sendable {
    case asDrawn = 0, larger, smaller, turned, echo, outline, mirrored, swapped, redrawn

    /// As the dial is engraved and the status line says it.
    var name: String {
        switch self {
        case .asDrawn: "As drawn"
        case .larger: "Larger"
        case .smaller: "Smaller"
        case .turned: "Turned"
        case .echo: "Echo"
        case .outline: "Outline"
        case .mirrored: "Mirrored"
        case .swapped: "Swapped"
        case .redrawn: "Redrawn"
        }
    }

    /// The press's one line on what it did, for VoiceOver and the status line.
    var sentence: String {
        switch self {
        case .asDrawn: "as the title drew it"
        case .larger: "drawn larger"
        case .smaller: "drawn smaller"
        case .turned: "turned"
        case .echo: "echoed"
        case .outline: "cut to an outline"
        case .mirrored: "mirrored to the other side"
        case .swapped: "with its inks swapped"
        case .redrawn: "redrawn from another roll"
        }
    }

    /// The die roll a part's marks are drawn from: its own for every move but Redrawn, which is the next roll.
    var take: Int { self == .redrawn ? 1 : 0 }

    /// A frame carries what hangs from it for these.
    var carriesHangers: Bool { [.larger, .smaller, .turned, .mirrored].contains(self) }

    static let range = 0...(allCases.count - 1)
}

extension Edition {
    /// The move the press has made on `part`.
    func treatment(of part: Part.ID) -> Treatment {
        Treatment(rawValue: takes[part] ?? 0) ?? .asDrawn
    }
}

extension Composer {
    /// The poster with every part's move made, in the order the parts are drawn.
    func treated(_ marks: [Mark]) -> [Mark] {
        var marks = marks
        for part in edition.movement.parts where part.turns {
            let move = edition.treatment(of: part.id)
            guard move != .asDrawn, move != .redrawn else { continue }
            let own: Set<Part.ID> = [part.id]
            let group = part.kind == .frame && move.carriesHangers
                ? own.union(edition.movement.parts.filter(\.hangs).map(\.id)) : own
            guard let centre = Self.centre(of: marks.filter { $0.part == part.id }) else { continue }
            var die = edition.dice(part.id, take: 0).fork("treatment")
            // A frame carries the poster with it, so it moves less than a piece does.
            let k: CGFloat = part.kind == .frame ? 0.18 : 0.34
            switch move {
            case .larger: marks = marks.map { group.contains($0.part ?? "") ? $0.scaled(1 + k, about: centre) : $0 }
            case .smaller: marks = marks.map { group.contains($0.part ?? "") ? $0.scaled(1 - k, about: centre) : $0 }
            case .turned:
                let degrees = die.sign() * (part.kind == .frame ? die.between(6, 10) : die.between(12, 20))
                marks = marks.map { group.contains($0.part ?? "") ? $0.rotated(degrees, about: centre) : $0 }
            case .mirrored: marks = marks.map { group.contains($0.part ?? "") ? $0.mirrored(across: w / 2) : $0 }
            case .outline: marks = marks.map { $0.part == part.id ? $0.outlined : $0 }
            case .swapped: marks = marks.map { $0.part == part.id ? $0.swapped : $0 }
            case .echo:
                let step = CGSize(width: die.sign() * 9, height: 9)
                marks = Self.echoed(marks, part: part.id, step: step)
            case .asDrawn, .redrawn: break
            }
        }
        return marks
    }

    /// The middle of a part's marks where they show: on the poster.
    static func centre(of marks: [Mark]) -> CGPoint? {
        let boxes = marks.map { $0.bounds.intersection(Card.posterRect) }.filter { !$0.isNull && !$0.isEmpty }
        guard let first = boxes.first else { return nil }
        let box = boxes.dropFirst().reduce(first) { $0.union($1) }
        return CGPoint(x: box.midX, y: box.midY)
    }

    /// Two fading repeats of a part's shapes, stepped out behind it, as a riso prints a plate twice off register.
    static func echoed(_ marks: [Mark], part: Part.ID, step: CGSize) -> [Mark] {
        var out: [Mark] = []
        for mark in marks {
            if mark.part == part, case .words = mark.shape {} else if mark.part == part {
                for (n, fade) in [(2.0, 0.22), (1.0, 0.45)] {
                    var echo = mark.translated(by: CGSize(width: step.width * n, height: step.height * n))
                    echo.opacity *= fade
                    out.append(echo)
                }
            }
            out.append(mark)
        }
        return out
    }
}

// MARK: Geometry

extension Mark {
    /// This mark `k` times its size, about `c`.
    func scaled(_ k: CGFloat, about c: CGPoint) -> Mark {
        func p(_ x: CGPoint) -> CGPoint { CGPoint(x: c.x + k * (x.x - c.x), y: c.y + k * (x.y - c.y)) }
        func r(_ x: CGRect) -> CGRect { CGRect(origin: p(x.origin), size: CGSize(width: x.width * k, height: x.height * k)) }
        var m = self
        m.shape = switch shape {
        case .rect(let x): .rect(r(x))
        case .frame(let x, let w): .frame(r(x), width: w * k)
        case .circle(let o, let radius): .circle(p(o), radius: radius * k)
        case .ring(let o, let radius, let w, let dash): .ring(p(o), radius: radius * k, width: w * k, dash: dash.map { $0 * k })
        case .polygon(let pts): .polygon(pts.map(p))
        case .outline(let pts, let w): .outline(pts.map(p), width: w * k)
        case .line(let a, let b, let w, let dash): .line(p(a), p(b), width: w * k, dash: dash.map { $0 * k })
        case .words(var words):
            {
                words.at = p(words.at)
                words.size *= k
                words.maxWidth = words.maxWidth.map { $0 * k }
                return .words(words)
            }()
        case .halftone(let x, let step, let focus, let reach, let dot):
            .halftone(r(x), step: step * k, focus: p(focus), reach: reach * k, dot: dot * k)
        }
        if let turn { m.turn = Turn(degrees: turn.degrees, around: p(turn.around)) }
        return m
    }

    /// This mark moved by `d`.
    func translated(by d: CGSize) -> Mark {
        func p(_ x: CGPoint) -> CGPoint { CGPoint(x: x.x + d.width, y: x.y + d.height) }
        var m = self
        m.shape = switch shape {
        case .rect(let x): .rect(x.offsetBy(dx: d.width, dy: d.height))
        case .frame(let x, let w): .frame(x.offsetBy(dx: d.width, dy: d.height), width: w)
        case .circle(let o, let radius): .circle(p(o), radius: radius)
        case .ring(let o, let radius, let w, let dash): .ring(p(o), radius: radius, width: w, dash: dash)
        case .polygon(let pts): .polygon(pts.map(p))
        case .outline(let pts, let w): .outline(pts.map(p), width: w)
        case .line(let a, let b, let w, let dash): .line(p(a), p(b), width: w, dash: dash)
        case .words(var words):
            {
                words.at = p(words.at)
                return .words(words)
            }()
        case .halftone(let x, let step, let focus, let reach, let dot):
            .halftone(x.offsetBy(dx: d.width, dy: d.height), step: step, focus: p(focus), reach: reach, dot: dot)
        }
        if let turn { m.turn = Turn(degrees: turn.degrees, around: p(turn.around)) }
        return m
    }

    /// This mark turned `degrees` (clockwise on screen) about `c`. A rigid turn of a mark that is already turned is still
    /// one turn: the mark is moved so its reference point lands where the two turns together take it, and turned about
    /// that point by both angles at once.
    func rotated(_ degrees: Double, about c: CGPoint) -> Mark {
        let reference: CGPoint = switch shape {
        case .rect(let x), .frame(let x, _), .halftone(let x, _, _, _, _): x.origin
        case .circle(let o, _), .ring(let o, _, _, _): o
        case .polygon(let pts), .outline(let pts, _): pts.first ?? c
        case .line(let a, _, _, _): a
        case .words(let words): words.at
        }
        func spin(_ x: CGPoint, _ deg: Double, _ about: CGPoint) -> CGPoint {
            let a = deg * .pi / 180
            let dx = x.x - about.x, dy = x.y - about.y
            return CGPoint(x: about.x + dx * cos(a) - dy * sin(a), y: about.y + dx * sin(a) + dy * cos(a))
        }
        let already = turn.map { spin(reference, $0.degrees, $0.around) } ?? reference
        let landed = spin(already, degrees, c)
        var m = translated(by: CGSize(width: landed.x - reference.x, height: landed.y - reference.y))
        m.turn = Turn(degrees: (turn?.degrees ?? 0) + degrees, around: landed)
        return m
    }

    /// This mark reflected across the vertical line `x0`. Words land on the other side reading the right way round.
    func mirrored(across x0: CGFloat) -> Mark {
        func p(_ x: CGPoint) -> CGPoint { CGPoint(x: 2 * x0 - x.x, y: x.y) }
        func r(_ x: CGRect) -> CGRect { CGRect(x: 2 * x0 - x.maxX, y: x.minY, width: x.width, height: x.height) }
        var m = self
        m.shape = switch shape {
        case .rect(let x): .rect(r(x))
        case .frame(let x, let w): .frame(r(x), width: w)
        case .circle(let o, let radius): .circle(p(o), radius: radius)
        case .ring(let o, let radius, let w, let dash): .ring(p(o), radius: radius, width: w, dash: dash)
        case .polygon(let pts): .polygon(pts.map(p))
        case .outline(let pts, let w): .outline(pts.map(p), width: w)
        case .line(let a, let b, let w, let dash): .line(p(a), p(b), width: w, dash: dash)
        case .words(var words):
            {
                words.at = p(words.at)
                words.anchor = switch words.anchor {
                case .leading: .trailing
                case .trailing: .leading
                case .center: .center
                }
                return .words(words)
            }()
        case .halftone(let x, let step, let focus, let reach, let dot):
            .halftone(r(x), step: step, focus: p(focus), reach: reach, dot: dot)
        }
        if let turn { m.turn = Turn(degrees: -turn.degrees, around: p(turn.around)) }
        return m
    }

    /// Solid shapes cut to their outline; a line, a ring, a frame, words and a dot screen stay as they are.
    var outlined: Mark {
        var m = self
        switch shape {
        case .rect(let x): m.shape = .frame(x.insetBy(dx: 1.5, dy: 1.5), width: 3)
        case .circle(let o, let radius): m.shape = .ring(o, radius: radius - 1.5, width: 3)
        case .polygon(let pts): m.shape = .outline(pts, width: 3)
        default: break
        }
        return m
    }

    /// The first ink and the second traded.
    var swapped: Mark {
        var m = self
        switch role {
        case .primary: m.role = .secondary
        case .secondary: m.role = .primary
        default: break
        }
        return m
    }
}
