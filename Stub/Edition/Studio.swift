import SwiftUI

/// One act at the press's studio (ADR-046): a pass pulled across the card through a screen, or a rubber stamp pressed on
/// it. Acts are kept with the proof, in order, and laid over the edition's drawing as a printmaker's last passes are, so
/// the card is made the way ephemera are made: by being acted on. Nothing here can break the edition: every act prints in
/// one of the edition's own inks, through a form the edition already speaks, and a stamp prints the copy's own night, so a
/// second viewing's card stamps its own date.
struct Act: Codable, Hashable, Sendable {
    enum Kind: String, Codable, Sendable { case pull, stamp }

    /// The screen a pass is pulled through.
    enum Screen: String, Codable, CaseIterable, Sendable {
        /// Three discs along the stroke, overprinting one another (after Karel Martens).
        case discs
        /// A dot screen that swells where the stroke ends.
        case dots
        /// Bars along the stroke, each a tone lighter (after Otl Aicher's bands).
        case bands
        /// The title's first letter, enormous (after Corita Kent).
        case letter
        /// The stub's own photograph, silkscreened along the stroke (after Rauschenberg's transfers). Drawn by the card,
        /// which has the photograph; offered only where there is one.
        case stub

        var name: String {
            switch self {
            case .discs: "Discs"
            case .dots: "Dots"
            case .bands: "Bands"
            case .letter: "Letter"
            case .stub: "The stub"
            }
        }
    }

    /// The rubber stamps on the press's tray: each prints a fact of the copy's own night.
    enum Stamp: String, Codable, CaseIterable, Sendable {
        /// The date, as a library card is stamped.
        case date
        case admit
        /// The seat, in a ring.
        case seat
        /// Which viewing it was.
        case viewing
        /// The cinema's postmark: its name and the date in two rings, and the cancellation lines.
        case postmark

        var name: String {
            switch self {
            case .date: "Date"
            case .admit: "Admit one"
            case .seat: "Seat"
            case .viewing: "Viewing"
            case .postmark: "Postmark"
            }
        }
    }

    /// Which of the edition's inks it is printed in.
    enum Inking: String, Codable, CaseIterable, Sendable {
        case primary, secondary, ink
        var role: Role {
            switch self {
            case .primary: .primary
            case .secondary: .secondary
            case .ink: .ink
            }
        }
    }

    var kind: Kind
    var screen: Screen?
    var stamp: Stamp?
    var inking: Inking
    /// Card points: where a pull began, or a stamp's centre.
    var x: Double
    var y: Double
    /// A pull's stroke, in card points. Zero for a stamp.
    var dx: Double = 0
    var dy: Double = 0
    /// A stamp's tilt, in degrees: a hand never presses one level.
    var angle: Double = 0

    static func pull(_ screen: Screen, in inking: Inking, from start: CGPoint, to end: CGPoint) -> Act {
        Act(kind: .pull, screen: screen, inking: inking, x: start.x, y: start.y, dx: end.x - start.x, dy: end.y - start.y)
    }

    /// A stamp pressed at `point`, tilted as a hand tilts it: a few degrees, the same for the same place every time.
    static func stamp(_ stamp: Stamp, in inking: Inking, at point: CGPoint) -> Act {
        var dice = Dice(seed: Release.fnv("stamp/\(Int(point.x))/\(Int(point.y))/\(stamp.rawValue)"))
        return Act(kind: .stamp, stamp: stamp, inking: inking, x: point.x, y: point.y, angle: dice.between(-9, 9))
    }

    /// The act's words for VoiceOver and the pencil: "a dots pass", "the date stamp".
    var spoken: String {
        switch kind {
        case .pull: "a \(screen?.name.lowercased() ?? "") pass in \(inking.rawValue)"
        case .stamp: "the \(stamp?.name.lowercased() ?? "") stamp in \(inking.rawValue)"
        }
    }
}

/// How the studio's acts print (ADR-046).
enum Studio {
    /// The acts' marks, in order, over the edition: multiplied into a light poster, screened onto a dark one.
    static func marks(_ acts: [Act], copy: Copy, inks: EditionInks, field: Role, title: String) -> [Mark] {
        let light = EditionInks.luminance(inks.hex(field)) > 0.35
        let blend: Mark.Blend = light ? .multiply : .screen
        return acts.flatMap { act -> [Mark] in
            // On a dark poster the ink has to be the lighter one to show at all.
            let role: Role = !light && act.inking == .ink ? .light : act.inking.role
            switch act.kind {
            case .pull: return pull(act, role: role, blend: blend, title: title)
            case .stamp: return stamp(act, role: role, blend: blend, copy: copy)
            }
        }
    }

    // MARK: Pulls

    private static func pull(_ act: Act, role: Role, blend: Mark.Blend, title: String) -> [Mark] {
        let start = CGPoint(x: act.x, y: act.y)
        let stroke = CGPoint(x: act.dx, y: act.dy)
        let length = max(hypot(stroke.x, stroke.y), 40)
        let angle = atan2(stroke.y, stroke.x)
        let mid = CGPoint(x: start.x + stroke.x / 2, y: start.y + stroke.y / 2)
        let turn = Mark.Turn(degrees: angle * 180 / .pi, around: mid)
        let opacity = blend == .multiply ? 0.62 : 0.5
        switch act.screen ?? .discs {
        case .discs:
            let radius = min(max(length * 0.26, 26), 72)
            return [0.18, 0.5, 0.82].map { t in
                let at = CGPoint(x: start.x + stroke.x * t, y: start.y + stroke.y * t)
                return Mark(.circle(at, radius: radius), role, .type, opacity: opacity, blend: blend)
            }
        case .dots:
            let rect = CGRect(x: mid.x - length / 2, y: mid.y - 46, width: length, height: 92)
            let focus = CGPoint(x: rect.maxX, y: rect.midY)
            return [Mark(.halftone(rect, step: 7, focus: focus, reach: length, dot: 3.4), role, .type, opacity: opacity + 0.2,
                         turn: turn, blend: blend)]
        case .bands:
            return (0..<5).map { i in
                let y = mid.y - 34 + CGFloat(i) * 15
                return Mark(.rect(CGRect(x: mid.x - length / 2, y: y, width: length * (1 - 0.08 * CGFloat(i)), height: 9)), role, .type,
                            opacity: opacity * pow(0.72, Double(i)) + 0.12, turn: turn, blend: blend)
            }
        case .stub:
            // The photograph is the card's to draw (`PhotoPasses`); it has no marks of its own.
            return []
        case .letter:
            guard let letter = title.uppercased().first(where: { $0.isLetter || $0.isNumber }) else { return [] }
            let size = min(max(length * 1.5, 170), 520)
            var mark = Mark.words(String(letter), .groteskExtraBold, size, at: CGPoint(x: mid.x, y: mid.y + size * 0.35), role,
                                  anchor: .center, plate: .type)
            mark.opacity = opacity * 0.7
            mark.blend = blend
            mark.turn = Mark.Turn(degrees: angle * 180 / .pi * 0.25, around: mid)
            return [mark]
        }
    }

    // MARK: Stamps

    private static func stamp(_ act: Act, role: Role, blend: Mark.Blend, copy: Copy) -> [Mark] {
        let c = CGPoint(x: act.x, y: act.y)
        let turn = Mark.Turn(degrees: act.angle, around: c)
        var marks: [Mark] = []
        func words(_ text: String, _ size: CGFloat, dy: CGFloat, tracking: CGFloat = 0.12, face: Face = .mono) {
            var mark = Mark.words(text, face, size, at: CGPoint(x: c.x, y: c.y + dy), role, anchor: .center, tracking: tracking, plate: .type)
            mark.turn = turn
            mark.blend = blend
            marks.append(mark)
        }
        func shape(_ s: Mark.Shape) {
            marks.append(Mark(s, role, .type, turn: turn, blend: blend))
        }
        switch act.stamp ?? .date {
        case .date:
            words((copy.date ?? "").uppercased(), 17, dy: 6, tracking: 0.08)
        case .admit:
            shape(.frame(CGRect(x: c.x - 64, y: c.y - 19, width: 128, height: 38), width: 2))
            words("ADMIT ONE", 14, dy: 5, tracking: 0.22, face: .groteskBold)
        case .seat:
            shape(.ring(c, radius: 30, width: 2))
            shape(.ring(c, radius: 25.5, width: 0.8))
            words("SEAT", 7.5, dy: -9, tracking: 0.3)
            words(copy.seat?.uppercased() ?? "—", 17, dy: 11, tracking: 0.02, face: .groteskBold)
        case .viewing:
            let ordinal = ["FIRST", "SECOND", "THIRD", "FOURTH", "FIFTH"][min(max(copy.viewing, 1), 5) - 1]
            shape(.line(CGPoint(x: c.x - 62, y: c.y - 15), CGPoint(x: c.x + 62, y: c.y - 15), width: 1.4))
            shape(.line(CGPoint(x: c.x - 62, y: c.y + 13), CGPoint(x: c.x + 62, y: c.y + 13), width: 1.4))
            words("\(ordinal) VIEWING", 12, dy: 4, tracking: 0.24, face: .groteskBold)
        case .postmark:
            shape(.ring(c, radius: 34, width: 1.6))
            shape(.ring(c, radius: 29, width: 0.7))
            let place = (copy.cinema ?? "STUB").uppercased().split(separator: " ").first.map(String.init) ?? "STUB"
            words(String(place.prefix(10)), 8.5, dy: -6, tracking: 0.18)
            words((copy.date ?? "").uppercased(), 7, dy: 8, tracking: 0.06)
            // The cancellation: three waves running off to the right of the ring.
            for line in 0..<3 {
                let y = c.y - 12 + CGFloat(line) * 12
                let points = stride(from: 0.0, through: 1.0, by: 0.05).map { t in
                    CGPoint(x: c.x + 40 + 78 * t, y: y + sin(t * 4 * .pi) * 3)
                }
                for (a, b) in zip(points, points.dropFirst()) { shape(.line(a, b, width: 1.3)) }
            }
        }
        // A rubber stamp's second, lighter kiss: every mark again, a point off, faint.
        let kiss = CGPoint(x: 0.9, y: -0.7)
        let echo = marks.map { mark -> Mark in
            var again = mark
            again.opacity = 0.22
            switch mark.shape {
            case .words(var w): w.at = CGPoint(x: w.at.x + kiss.x, y: w.at.y + kiss.y); again.shape = .words(w)
            case .ring(let p, let r, let width, let d): again.shape = .ring(CGPoint(x: p.x + kiss.x, y: p.y + kiss.y), radius: r, width: width, dash: d)
            case .frame(let r, let width): again.shape = .frame(r.offsetBy(dx: kiss.x, dy: kiss.y), width: width)
            default: break
            }
            return again
        }
        return marks.map { var m = $0; m.opacity = 0.86; return m } + echo
    }
}

/// The stub's photograph, for the card to silkscreen when a pass is pulled through it (ADR-046). Set where the card is
/// drawn with its stub at hand: the detail, the press, the drawer, the share. Where it is not set, those passes are not drawn.
extension EnvironmentValues {
    @Entry var stubPhoto: UIImage? = nil
}

/// The passes pulled through the stub's own photograph: the picture as a silkscreen, its darks printing in the pass's ink,
/// its lights left as the card, laid along the stroke and cut to the poster (after Rauschenberg). In the image layer: over
/// the colour plates, under the type and the other acts.
struct PhotoPasses: View {
    let composition: Composition
    @Environment(\.stubPhoto) private var photo

    var body: some View {
        let c = composition
        let passes = c.edition.acts.filter { $0.kind == .pull && $0.screen == .stub }
        if let photo, !passes.isEmpty {
            let light = EditionInks.luminance(c.inks.hex(c.posterField)) > 0.35
            ZStack(alignment: .topLeading) {
                ForEach(Array(passes.enumerated()), id: \.offset) { _, act in
                    Self.pass(act, photo: photo, colour: c.inks.color(!light && act.inking == .ink ? .light : act.inking.role), light: light)
                }
            }
            .frame(width: Card.width, height: Card.poster, alignment: .topLeading)
            .clipped()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    /// One pass: the photograph the width of the stroke, its darks as ink, turned along it.
    static func pass(_ act: Act, photo: UIImage, colour: Color, light: Bool) -> some View {
        let length = max(hypot(act.dx, act.dy), 140)
        let aspect = photo.size.width / max(photo.size.height, 1)
        let width = min(length * 1.15, 460)
        let height = width / max(aspect, 0.6)
        let mid = CGPoint(x: act.x + act.dx / 2, y: act.y + act.dy / 2)
        let angle = atan2(act.dy, act.dx) * 180 / .pi
        return Rectangle()
            .fill(colour)
            .mask {
                Image(uiImage: photo)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .grayscale(1)
                    .contrast(1.9)
                    .colorInvert()
                    .luminanceToAlpha()
            }
            .frame(width: width, height: height)
            .opacity(light ? 0.8 : 0.62)
            .blendMode(light ? .multiply : .screen)
            // Turned only part of the way along the stroke: a transfer laid down by hand, not spun.
            .rotationEffect(.degrees(angle * 0.35))
            .position(mid)
    }
}
