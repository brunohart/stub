import CoreGraphics
import QuartzCore

/// Separations (ADR-016, brief §5.4): the card taken apart into the layers it was printed in, each a sheet of film with
/// only its own ink on it, lifted apart in depth and seen from above and to one side, the way a printer thinks of a
/// card. One number says how far apart they are: 0 is the card flat, 1 is the sheets fully spread.
enum Separation {
    /// The printed card's layers, from the stock at the bottom to the type on top.
    enum Layer: Int, CaseIterable, Sendable {
        case stock, first, second, foil, type

        /// The plate whose marks this layer carries; the stock and the foil carry none of their own.
        var plate: Plate? {
            switch self {
            case .first: .first
            case .second: .second
            case .type: .type
            case .stock, .foil: nil
            }
        }

        var name: String {
            switch self {
            case .stock: "the stock"
            case .first: "the first plate"
            case .second: "the second plate"
            case .foil: "the foil"
            case .type: "the type"
            }
        }
    }

    /// The tilt the sheets are seen at, fully apart: back about the card's width, then turned in its own plane.
    static let tiltX = 52.0
    static let tiltZ = -24.0
    /// The perspective: a viewer about nine hundred points away.
    static let m34: CGFloat = -1.0 / 900
    /// How far apart two sheets lift, fully apart.
    static let spread: CGFloat = 38
    /// Fully apart, the stack is drawn this much smaller so it stays on the bed.
    static let shrink: CGFloat = 0.2

    /// The layers a composition has: the foil only on a foil or holographic stock.
    static func layers(metallic: Bool) -> [Layer] {
        Layer.allCases.filter { $0 != .foil || metallic }
    }

    /// Where sheet `index` (0 the stock) of the stack is drawn, at separation `s`, in card points: lifted `index`
    /// spreads toward the viewer, turned in its plane, tilted back, seen in perspective, about the card's centre.
    static func transform(index: Int, separation s: CGFloat) -> CATransform3D {
        let c = CGPoint(x: Card.width / 2, y: Card.height / 2)
        let fit = 1 - shrink * s
        var m = CATransform3DMakeTranslation(-c.x, -c.y, 0)
        m = CATransform3DConcat(m, CATransform3DMakeTranslation(0, 0, CGFloat(index) * spread * s))
        m = CATransform3DConcat(m, CATransform3DMakeRotation(CGFloat(tiltZ * .pi / 180) * s, 0, 0, 1))
        m = CATransform3DConcat(m, CATransform3DMakeRotation(CGFloat(tiltX * .pi / 180) * s, 1, 0, 0))
        m = CATransform3DConcat(m, CATransform3DMakeScale(fit, fit, fit))
        var perspective = CATransform3DIdentity
        perspective.m34 = m34 * s
        m = CATransform3DConcat(m, perspective)
        return CATransform3DConcat(m, CATransform3DMakeTranslation(c.x, c.y, 0))
    }

    /// The point on sheet `index` (card points, on the sheet's own plane) that a finger at `point` is over, or `nil`
    /// when the finger is looking past the sheet's edge-on horizon. SwiftUI's hit-testing does not follow a
    /// projection, so the press carries the finger back through each sheet's transform itself.
    static func unproject(_ point: CGPoint, index: Int, separation s: CGFloat) -> CGPoint? {
        let m = transform(index: index, separation: s)
        // A point (u, v) on the sheet's plane lands at ([u v 1] · H) / w, where H is the plane's part of m.
        let h: [[Double]] = [
            [Double(m.m11), Double(m.m12), Double(m.m14)],
            [Double(m.m21), Double(m.m22), Double(m.m24)],
            [Double(m.m41), Double(m.m42), Double(m.m44)],
        ]
        guard let inverse = invert(h) else { return nil }
        let x = Double(point.x), y = Double(point.y)
        let u = x * inverse[0][0] + y * inverse[1][0] + inverse[2][0]
        let v = x * inverse[0][1] + y * inverse[1][1] + inverse[2][1]
        let w = x * inverse[0][2] + y * inverse[1][2] + inverse[2][2]
        guard abs(w) > 1e-9 else { return nil }
        return CGPoint(x: u / w, y: v / w)
    }

    /// Where a point on sheet `index` is drawn: the forward of `unproject`, for tests and for placing things.
    static func project(_ point: CGPoint, index: Int, separation s: CGFloat) -> CGPoint {
        let m = transform(index: index, separation: s)
        let x = point.x * m.m11 + point.y * m.m21 + m.m41
        let y = point.x * m.m12 + point.y * m.m22 + m.m42
        let w = point.x * m.m14 + point.y * m.m24 + m.m44
        return CGPoint(x: x / w, y: y / w)
    }

    private static func invert(_ a: [[Double]]) -> [[Double]]? {
        let det = a[0][0] * (a[1][1] * a[2][2] - a[1][2] * a[2][1])
            - a[0][1] * (a[1][0] * a[2][2] - a[1][2] * a[2][0])
            + a[0][2] * (a[1][0] * a[2][1] - a[1][1] * a[2][0])
        guard abs(det) > 1e-12 else { return nil }
        let d = 1 / det
        return [
            [(a[1][1] * a[2][2] - a[1][2] * a[2][1]) * d, (a[0][2] * a[2][1] - a[0][1] * a[2][2]) * d, (a[0][1] * a[1][2] - a[0][2] * a[1][1]) * d],
            [(a[1][2] * a[2][0] - a[1][0] * a[2][2]) * d, (a[0][0] * a[2][2] - a[0][2] * a[2][0]) * d, (a[0][2] * a[1][0] - a[0][0] * a[1][2]) * d],
            [(a[1][0] * a[2][1] - a[1][1] * a[2][0]) * d, (a[0][1] * a[2][0] - a[0][0] * a[2][1]) * d, (a[0][0] * a[1][1] - a[0][1] * a[1][0]) * d],
        ]
    }
}

extension Composition {
    /// Whether `mark` is printed on `layer`: the foil takes the foil marks on a metallic stock, and each plate the
    /// rest of its own.
    func prints(_ mark: Mark, on layer: Separation.Layer) -> Bool {
        if layer == .foil { return isMetallic && mark.foil }
        guard let plate = layer.plate else { return false }
        return mark.plate == plate && !(isMetallic && mark.foil)
    }

    /// The part under `point` on one sheet of the separations.
    func part(at point: CGPoint, on layer: Separation.Layer, slop: CGFloat = 6) -> Part.ID? {
        guard Card.posterRect.contains(point) else { return nil }
        return hitOrder.first { prints($0, on: layer) && $0.contains(point, slop: slop) }?.part
    }
}
