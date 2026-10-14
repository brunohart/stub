#!/usr/bin/env swift
// The app's icons (ADR-028): ten, drawn in CoreGraphics in the app's own faces, every random thing from a fixed seed, so the
// same icons come out every time. The first, Torn, is the app's; the other nine are the icons a person can choose in
// Your card once they have bought the icon drawer. The source is this file, as the fixtures' (ADR-003) and the project's
// (ADR-004) are theirs.
// Usage: swift scripts/make-icons.swift [out dir] [--install]   (default build/icons)
// Writes NN-name.png at 1024 for each, sheet.png (the ten side by side, masked as the home screen masks them) and home.png
// (the ten at home-screen size on a light and a dark wallpaper). --install also writes them into the asset catalogue: Torn
// as AppIcon, the rest as AppIcon-<Name>, and a small copy of each as Icon-<Name> for the chooser.
import Foundation
import AppKit
import CoreText

let arguments = CommandLine.arguments.dropFirst()
let outDir = arguments.first { !$0.hasPrefix("--") } ?? "build/icons"
let installs = arguments.contains("--install")
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
for name in ["HostGrotesk-Variable.ttf", "FragmentMono-Regular.ttf", "Newsreader-Variable.ttf", "Newsreader-Italic-Variable.ttf"] {
    CTFontManagerRegisterFontsForURL(root.appending(path: "Stub/Resources/Fonts/\(name)") as CFURL, .process, nil)
}
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

let S: CGFloat = 1024
let space = CGColorSpace(name: CGColorSpace.displayP3)!

func p3(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: space, components: [CGFloat((hex >> 16) & 0xFF) / 255, CGFloat((hex >> 8) & 0xFF) / 255,
                                            CGFloat(hex & 0xFF) / 255, a])!
}

func gradient(_ stops: [(CGColor, CGFloat)]) -> CGGradient {
    CGGradient(colorsSpace: space, colors: stops.map(\.0) as CFArray, locations: stops.map(\.1))!
}

struct Seeded {
    var state: UInt64
    mutating func next() -> CGFloat {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat((state >> 33) & 0xFFFFFF) / CGFloat(0xFFFFFF)
    }
    mutating func between(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * next() }
}

extension CGContext {
    func group(_ body: () -> Void) { saveGState(); body(); restoreGState() }
    func fill(_ path: CGPath, _ color: CGColor, evenOdd: Bool = false) {
        addPath(path); setFillColor(color); fillPath(using: evenOdd ? .evenOdd : .winding)
    }
    func stroke(_ path: CGPath, _ color: CGColor, _ width: CGFloat, dash: [CGFloat] = [], cap: CGLineCap = .butt) {
        group {
            addPath(path); setStrokeColor(color); setLineWidth(width); setLineCap(cap)
            if !dash.isEmpty { setLineDash(phase: 0, lengths: dash) }
            strokePath()
        }
    }
    func clipPath(_ path: CGPath, evenOdd: Bool = false) { addPath(path); clip(using: evenOdd ? .evenOdd : .winding) }
    func linear(_ g: CGGradient, _ a: CGPoint, _ b: CGPoint) {
        drawLinearGradient(g, start: a, end: b, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }
    func radial(_ g: CGGradient, _ c: CGPoint, _ r: CGFloat) {
        drawRadialGradient(g, startCenter: c, startRadius: 0, endCenter: c, endRadius: r, options: [.drawsAfterEndLocation])
    }
    /// A shadow inside `path`, cast by its own edges.
    func innerShadow(_ path: CGPath, offset: CGSize, blur: CGFloat, color: CGColor) {
        group {
            clipPath(path)
            let outer = CGMutablePath()
            outer.addRect(path.boundingBoxOfPath.insetBy(dx: -800, dy: -800))
            outer.addPath(path)
            setShadow(offset: offset, blur: blur, color: color)
            addPath(outer); setFillColor(p3(0x000000)); fillPath(using: .evenOdd)
        }
    }
    /// The shape's shadow alone, the shape itself drawn out of sight. Only at an unrotated, unscaled transform.
    func shadowOnly(_ path: CGPath, offset: CGSize, blur: CGFloat, color: CGColor, evenOdd: Bool = false) {
        group {
            let far: CGFloat = 6000
            setShadow(offset: CGSize(width: offset.width + far, height: offset.height), blur: blur, color: color)
            translateBy(x: -far, y: 0)
            fill(path, p3(0x000000), evenOdd: evenOdd)
        }
    }
    /// A soft-edged fill: light, a glow, a sheen. Only at an unrotated, unscaled transform.
    func blurred(_ path: CGPath, blur: CGFloat, color: CGColor) { shadowOnly(path, offset: .zero, blur: blur, color: color) }
}

func canvas(_ w: CGFloat = S, _ h: CGFloat = S, alpha: Bool = false) -> CGContext {
    let c = CGContext(data: nil, width: Int(w), height: Int(h), bitsPerComponent: 8, bytesPerRow: 0, space: space,
                      bitmapInfo: (alpha ? CGImageAlphaInfo.premultipliedLast : CGImageAlphaInfo.noneSkipLast).rawValue)!
    c.interpolationQuality = .high
    c.setShouldAntialias(true)
    return c
}

func write(_ image: CGImage, _ name: String) {
    let rep = NSBitmapImageRep(cgImage: image)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(outDir)/\(name)"))
}

// MARK: Type, as outlines, so it can be pressed, knocked out and lit like anything else.

func font(_ name: String, _ size: CGFloat) -> CTFont { CTFontCreateWithName(name as CFString, size, nil) }

/// The text's outline with its baseline at y = 0 and its left at x = 0, and its advance.
func words(_ text: String, _ f: CTFont, kern: CGFloat = 0) -> (path: CGPath, width: CGFloat) {
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [.font: f, .kern: kern]))
    let path = CGMutablePath()
    for run in CTLineGetGlyphRuns(line) as! [CTRun] {
        let n = CTRunGetGlyphCount(run)
        var glyphs = [CGGlyph](repeating: 0, count: n)
        var positions = [CGPoint](repeating: .zero, count: n)
        CTRunGetGlyphs(run, CFRange(location: 0, length: 0), &glyphs)
        CTRunGetPositions(run, CFRange(location: 0, length: 0), &positions)
        let runFont = (CTRunGetAttributes(run) as NSDictionary)[kCTFontAttributeName as String] as! CTFont
        for i in 0..<n {
            var t = CGAffineTransform(translationX: positions[i].x, y: positions[i].y)
            if let g = CTFontCreatePathForGlyph(runFont, glyphs[i], &t) { path.addPath(g) }
        }
    }
    return (path, CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil)))
}

/// `text` set so its left baseline sits at `at` (or its centre, or its right), turned `degrees` about that point.
func setText(_ text: String, _ f: CTFont, at: CGPoint, anchor: CGFloat = 0, degrees: CGFloat = 0, kern: CGFloat = 0) -> CGPath {
    let (p, w) = words(text, f, kern: kern)
    var t = CGAffineTransform(translationX: at.x, y: at.y).rotated(by: degrees * .pi / 180).translatedBy(x: -w * anchor, y: 0)
    return p.copy(using: &t)!
}

/// The largest size at which `text` is no wider than `width`.
func fitting(_ text: String, _ name: String, width: CGFloat, max: CGFloat, kern: CGFloat = 0) -> CGFloat {
    let w = words(text, font(name, 100), kern: kern * 1).width / 100
    return min(max, width / w)
}

func transformed(_ path: CGPath, _ t: CGAffineTransform) -> CGPath { var t = t; return path.copy(using: &t)! }
func circle(_ c: CGPoint, _ r: CGFloat) -> CGPath { CGPath(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r), transform: nil) }
func ellipse(_ c: CGPoint, _ rx: CGFloat, _ ry: CGFloat) -> CGPath {
    CGPath(ellipseIn: CGRect(x: c.x - rx, y: c.y - ry, width: 2 * rx, height: 2 * ry), transform: nil)
}
func rounded(_ r: CGRect, _ corner: CGFloat) -> CGPath { CGPath(roundedRect: r, cornerWidth: corner, cornerHeight: corner, transform: nil) }
func union(_ paths: [CGPath]) -> CGPath { let m = CGMutablePath(); paths.forEach { m.addPath($0) }; return m }

/// A landscape ticket with a half-moon notch top and bottom at its perforation.
func ticket(_ r: CGRect, corner: CGFloat, notchX: CGFloat, notch: CGFloat) -> CGPath {
    rounded(r, corner).subtracting(union([circle(CGPoint(x: notchX, y: r.maxY), notch), circle(CGPoint(x: notchX, y: r.minY), notch)]))
}

/// An edition's card, portrait, centred on the origin: rounded, a notch each side at the perforation, the perforation punched.
func editionCard(w: CGFloat, h: CGFloat) -> (shape: CGPath, perforation: CGFloat) {
    let s = w / 330
    let y = -h / 2 + (528 - 408) * s
    var cuts: [CGPath] = [circle(CGPoint(x: -w / 2, y: y), 8 * s), circle(CGPoint(x: w / 2, y: y), 8 * s)]
    var x = -w / 2 + 16 * s
    while x < w / 2 - 14 * s { cuts.append(circle(CGPoint(x: x, y: y), 1.7 * s)); x += 7.5 * s }
    return (rounded(CGRect(x: -w / 2, y: -h / 2, width: w, height: h), 10 * s).subtracting(union(cuts)), y)
}

let stockLight = gradient([(p3(0xFCF7EB), 0), (p3(0xF3EBD8), 0.55), (p3(0xE2D5BB), 1)])
let brass = gradient([(p3(0xFBEBB4), 0), (p3(0xE4C26E), 0.28), (p3(0xBC9242), 0.6), (p3(0x8A6627), 0.84), (p3(0xC9A453), 1)])
let ink: UInt32 = 0x1A1A1A, orange: UInt32 = 0xD4622B, navy: UInt32 = 0x1B2D4F, cream: UInt32 = 0xF5F0E1

/// Type printed into stock: the bite (a highlight where the lamp lights the far wall of the impression), the orange plate a
/// pass out of register, then the ink.
func press(_ ctx: CGContext, _ path: CGPath, ink color: CGColor = p3(ink, 0.93), plate: CGSize? = nil, plateColor: CGColor = p3(orange, 0.85)) {
    ctx.group { ctx.translateBy(x: 1.6, y: -1.8); ctx.fill(path, p3(0xFFFFFF, 0.5)) }
    if let plate { ctx.group { ctx.setBlendMode(.multiply); ctx.translateBy(x: plate.width, y: plate.height); ctx.fill(path, plateColor) } }
    ctx.fill(path, color)
}

/// The lamp's table: warm dark, lit from the upper left.
func table(_ ctx: CGContext, _ colors: [UInt32] = [0x4A4038, 0x2A2420, 0x110F0D], lamp: CGPoint = CGPoint(x: 300, y: 790)) {
    ctx.radial(gradient([(p3(colors[0]), 0), (p3(colors[1]), 0.45), (p3(colors[2]), 1)]), lamp, 1000)
}

// MARK: 01 Torn — the ticket torn along its perforation, the half you keep and the half the usher took, still parting.

func torn(_ ctx: CGContext) {
    table(ctx, [0x35425E, 0x19233A, 0x090E19], lamp: CGPoint(x: 280, y: 820))
    var dice = Seeded(state: 0x70A9)
    let w: CGFloat = 790, h: CGFloat = 410, corner: CGFloat = 26, tear: CGFloat = 168
    let r: CGFloat = 10, pitch: CGFloat = 30
    let top = h / 2, bottom = -h / 2
    let count = Int((h - pitch) / pitch)
    let first = top - (h - CGFloat(count - 1) * pitch) / 2
    var left: [CGPoint] = [], right: [CGPoint] = [], bridges: [[CGPoint]] = []
    var y = top
    func bridge(to end: CGFloat) -> [CGPoint] {
        var pts: [CGPoint] = []
        var yy = y
        while yy > end + 1.2 { yy -= dice.between(1.3, 3.0); pts.append(CGPoint(x: tear + dice.between(-2.8, 2.8), y: max(yy, end))) }
        return pts
    }
    for i in 0..<count {
        let cy = first - CGFloat(i) * pitch
        let b = bridge(to: cy + r); left += b; right += b; bridges.append(b)
        for k in 0...12 {
            let a = CGFloat.pi / 2 + .pi * CGFloat(k) / 12
            left.append(CGPoint(x: tear + r * cos(a), y: cy + r * sin(a)))
            let a2 = CGFloat.pi / 2 - .pi * CGFloat(k) / 12
            right.append(CGPoint(x: tear + r * cos(a2), y: cy + r * sin(a2)))
        }
        y = cy - r
    }
    let tail = bridge(to: bottom); left += tail; right += tail; bridges.append(tail)

    let kept = CGMutablePath()
    kept.move(to: CGPoint(x: -w / 2, y: top - corner))
    kept.addQuadCurve(to: CGPoint(x: -w / 2 + corner, y: top), control: CGPoint(x: -w / 2, y: top))
    kept.addLine(to: CGPoint(x: tear, y: top))
    left.forEach { kept.addLine(to: $0) }
    kept.addLine(to: CGPoint(x: tear, y: bottom))
    kept.addLine(to: CGPoint(x: -w / 2 + corner, y: bottom))
    kept.addQuadCurve(to: CGPoint(x: -w / 2, y: bottom + corner), control: CGPoint(x: -w / 2, y: bottom))
    kept.closeSubpath()
    let taken = CGMutablePath()
    taken.move(to: CGPoint(x: tear, y: top))
    taken.addLine(to: CGPoint(x: w / 2 - corner, y: top))
    taken.addQuadCurve(to: CGPoint(x: w / 2, y: top - corner), control: CGPoint(x: w / 2, y: top))
    taken.addLine(to: CGPoint(x: w / 2, y: bottom + corner))
    taken.addQuadCurve(to: CGPoint(x: w / 2 - corner, y: bottom), control: CGPoint(x: w / 2, y: bottom))
    taken.addLine(to: CGPoint(x: tear, y: bottom))
    right.reversed().forEach { taken.addLine(to: $0) }
    taken.closeSubpath()

    let place = CGAffineTransform(translationX: 488, y: 520).rotated(by: -9 * .pi / 180)
    let parted = place.translatedBy(x: tear, y: 0).translatedBy(x: 46, y: -16).rotated(by: 7 * .pi / 180).translatedBy(x: -tear, y: 0)

    // What is printed across the whole ticket; each half shows its share of it.
    let size = fitting("ADMIT", "HostGrotesk-ExtraBold", width: 420, max: 150, kern: -2)
    let admit = setText("ADMIT", font("HostGrotesk-ExtraBold", size), at: CGPoint(x: -w / 2 + 70, y: 14), kern: -2)
    let one = setText("ONE", font("HostGrotesk-ExtraBold", size), at: CGPoint(x: -w / 2 + 70, y: 14 - size * 0.86), kern: -2)
    let number = setText("Nº 0412", font("FragmentMono-Regular", 34), at: CGPoint(x: (tear + w / 2) / 2 + 12, y: -88), degrees: 90)
    func printing() {
        ctx.stroke(rounded(CGRect(x: -w / 2 + 30, y: bottom + 26, width: w - 56, height: h - 52), 8), p3(ink, 0.5), 2.2)
        ctx.stroke(rounded(CGRect(x: -w / 2 + 38, y: bottom + 34, width: w - 72, height: h - 68), 5), p3(ink, 0.4), 1)
        press(ctx, admit, plate: CGSize(width: 7, height: -5))
        press(ctx, one, plate: CGSize(width: 7, height: -5))
        press(ctx, number, ink: p3(0xC4391D, 0.9))
    }
    func piece(_ shape: CGPath, at t: CGAffineTransform, lift: CGFloat, outward: CGFloat) {
        ctx.shadowOnly(transformed(shape, t), offset: CGSize(width: 22 * lift, height: -30 * lift), blur: 48 * lift, color: p3(0, 0.6))
        ctx.shadowOnly(transformed(shape, t), offset: CGSize(width: 4, height: -6), blur: 8, color: p3(0, 0.5))
        ctx.group {
            ctx.concatenate(t)
            ctx.clipPath(shape)
            ctx.linear(stockLight, CGPoint(x: -w / 2, y: h / 2), CGPoint(x: w / 2, y: -h / 2))
            printing()
            // Torn paper is lighter at the tear, where its fibres stand up.
            for b in bridges where b.count > 1 {
                let edge = CGMutablePath(); edge.addLines(between: b)
                ctx.stroke(edge, p3(0xFFFFFF, 0.7), 5)
            }
            ctx.stroke(transformed(rounded(CGRect(x: -w / 2, y: bottom, width: w, height: h), corner), .identity), p3(0xFFFFFF, 0.5), 3)
        }
        ctx.group {
            ctx.concatenate(t)
            var fibres = Seeded(state: outward > 0 ? 0xF1B : 0xF1C)
            for b in bridges { for p in b where fibres.next() < 0.4 {
                let a = fibres.between(-0.6, 0.6), len = fibres.between(2, 7)
                let f = CGMutablePath(); f.move(to: p); f.addLine(to: CGPoint(x: p.x + outward * len * cos(a), y: p.y + len * sin(a)))
                ctx.stroke(f, p3(0xFFFBF0, 0.85), fibres.between(0.7, 1.3), cap: .round)
            } }
        }
    }
    piece(kept, at: place, lift: 1, outward: 1)
    piece(taken, at: parted, lift: 1.35, outward: -1)
}

// MARK: 02 Roll — a roll of tickets on the box office wall, the next one hanging off it.

func roll(_ ctx: CGContext) {
    ctx.radial(gradient([(p3(0xF8F3E8), 0), (p3(0xEDE5D4), 0.5), (p3(0xD8CDB6), 1)]), CGPoint(x: 340, y: 780), 1100)
    let x0: CGFloat = 236, x1: CGFloat = 800, cy: CGFloat = 700, R: CGFloat = 150, rx: CGFloat = 44
    let body = union([CGPath(rect: CGRect(x: x0, y: cy - R, width: x1 - x0, height: 2 * R), transform: nil), ellipse(CGPoint(x: x1, y: cy), rx, R)])
    let strip = CGPath(rect: CGRect(x: x0 + 1, y: -40, width: x1 - x0 - 2, height: cy + 40), transform: nil)
    let cap = ellipse(CGPoint(x: x0, y: cy), rx, R)
    let whole = union([body, strip, cap])
    ctx.shadowOnly(whole, offset: CGSize(width: 26, height: -30), blur: 44, color: p3(0x3A2A1A, 0.45))
    ctx.shadowOnly(whole, offset: CGSize(width: 5, height: -6), blur: 8, color: p3(0x3A2A1A, 0.35))
    // The roll, a cylinder: dark where it turns away at the top, the lamp's highlight a third of the way down, darker below.
    ctx.group {
        ctx.clipPath(body)
        ctx.linear(gradient([(p3(0x8E3B16), 0), (p3(0xE07F50), 0.16), (p3(0xF6A57D), 0.28), (p3(0xDB6A37), 0.5), (p3(0xB04C1D), 0.8),
                             (p3(0x7A3112), 1)]), CGPoint(x: 0, y: cy + R), CGPoint(x: 0, y: cy - R))
        // The edge of the outer layer, where the next ticket is torn from.
        for k in [0.62, 0.86] as [CGFloat] {
            let yy = cy + R * cos(k * .pi / 2)
            let line = CGMutablePath(); line.move(to: CGPoint(x: x0, y: yy)); line.addLine(to: CGPoint(x: x1 + rx, y: yy))
            ctx.stroke(line, p3(0x7A3112, 0.45), 2, dash: [9, 7])
        }
    }
    // The end of the roll: every layer of paper, the cardboard core, the hole.
    ctx.group {
        ctx.clipPath(cap)
        ctx.fill(cap, p3(0xC25A27))
        var ring = R
        var i = 0
        while ring > 54 {
            ctx.stroke(ellipse(CGPoint(x: x0, y: cy), rx * ring / R, ring), i % 2 == 0 ? p3(0x7A3112, 0.28) : p3(0xF7B48F, 0.22), 1.4)
            ring -= 5.5; i += 1
        }
        ctx.fill(ellipse(CGPoint(x: x0, y: cy), rx * 54 / R, 54), p3(0xC9A06F))
        for k in stride(from: 52.0, to: 36, by: -4) { ctx.stroke(ellipse(CGPoint(x: x0, y: cy), rx * k / R, k), p3(0x8B6A44, 0.35), 1) }
        let hole = ellipse(CGPoint(x: x0, y: cy), rx * 36 / R, 36)
        ctx.fill(hole, p3(0x2E2016))
        ctx.innerShadow(hole, offset: CGSize(width: 3, height: -6), blur: 6, color: p3(0, 0.8))
        ctx.linear(gradient([(p3(0xFFFFFF, 0.22), 0), (p3(0xFFFFFF, 0), 0.5), (p3(0x000000, 0.18), 1)]),
                   CGPoint(x: x0 - rx, y: cy + R), CGPoint(x: x0 + rx, y: cy - R))
    }
    ctx.stroke(cap, p3(0x6E2C10, 0.5), 1.5)
    // The ticket hanging from it, its face to the room: shaded where it leaves the roll, flat below.
    ctx.group {
        ctx.clipPath(strip)
        ctx.linear(gradient([(p3(0xD86A39), 0), (p3(0xD15F2E), 1)]), CGPoint(x: x0, y: 0), CGPoint(x: x1, y: 0))
        ctx.linear(gradient([(p3(0xDB6A37, 0), 0), (p3(0x9A4119, 0.55), 1)]), CGPoint(x: 0, y: cy - 60), CGPoint(x: 0, y: cy))
        let tickets: [(CGFloat, String)] = [(cy - 34, "0412"), (cy - 34 - 340, "0413")]
        for (top, no) in tickets {
            let perf = CGMutablePath(); perf.move(to: CGPoint(x: x0, y: top)); perf.addLine(to: CGPoint(x: x1, y: top))
            ctx.stroke(perf, p3(0x7A3112, 0.55), 3, dash: [10, 8])
            let frame = rounded(CGRect(x: x0 + 34, y: top - 340 + 30, width: x1 - x0 - 68, height: 340 - 60), 6)
            ctx.stroke(frame, p3(0x1A1A1A, 0.55), 2.4)
            let size = fitting("ADMIT ONE", "HostGrotesk-ExtraBold", width: x1 - x0 - 140, max: 92, kern: -1)
            let text = setText("ADMIT ONE", font("HostGrotesk-ExtraBold", size), at: CGPoint(x: (x0 + x1) / 2, y: top - 190), anchor: 0.5, kern: -1)
            ctx.group { ctx.setBlendMode(.multiply); ctx.fill(text, p3(0x1A1A1A, 0.92)) }
            let n = setText("Nº \(no)", font("FragmentMono-Regular", 30), at: CGPoint(x: (x0 + x1) / 2, y: top - 262), anchor: 0.5)
            ctx.group { ctx.setBlendMode(.multiply); ctx.fill(n, p3(0x1A1A1A, 0.8)) }
        }
    }
}

// MARK: 03 Label — the home's brass label holder and a card catalogue's cup pull, on the drawer's walnut front.

func label(_ ctx: CGContext) {
    ctx.linear(gradient([(p3(0x6A4530), 0), (p3(0x452A1A), 0.5), (p3(0x26170D), 1)]), CGPoint(x: 160, y: 1024), CGPoint(x: 860, y: 0))
    var dice = Seeded(state: 0xB1A55)
    // The walnut's figure: long soft streaks of sheen across the grain. Light on a material, not noise laid over it.
    for _ in 0..<16 {
        let y = dice.between(40, 1000), h = dice.between(6, 22), dark = dice.next() < 0.5
        ctx.blurred(ellipse(CGPoint(x: dice.between(200, 800), y: y), dice.between(500, 900), h), blur: 14,
                    color: dark ? p3(0x140A04, 0.18) : p3(0xC48A5E, 0.10))
    }
    ctx.radial(gradient([(p3(0xFFDDB0, 0.16), 0), (p3(0xFFDDB0, 0), 1)]), CGPoint(x: 300, y: 820), 700)
    // The drawer front's routed edge.
    let panel = rounded(CGRect(x: 64, y: 64, width: 896, height: 896), 40)
    ctx.stroke(panel, p3(0x000000, 0.35), 4)
    ctx.group { ctx.translateBy(x: 2, y: -3); ctx.stroke(panel, p3(0xE8B98C, 0.14), 2) }

    let frame = CGRect(x: 512 - 330, y: 520, width: 660, height: 300)
    let window = CGRect(x: frame.minX + 84, y: frame.minY + 46, width: frame.width - 168, height: frame.height - 92)
    let holder = rounded(frame, 32).subtracting(rounded(window, 12))
    ctx.shadowOnly(rounded(frame, 32), offset: CGSize(width: 8, height: -16), blur: 24, color: p3(0, 0.6))
    // The card in the window, the frame's shadow across its top.
    ctx.group {
        ctx.clipPath(rounded(window, 12))
        ctx.linear(gradient([(p3(0xFAF5E8), 0), (p3(0xEDE4CF), 1)]), CGPoint(x: window.minX, y: window.maxY), CGPoint(x: window.maxX, y: window.minY))
        let typed = setText("STUB", font("FragmentMono-Regular", 118), at: CGPoint(x: window.midX, y: window.midY - 38), anchor: 0.5, kern: 4)
        ctx.fill(typed, p3(ink, 0.9))
        ctx.innerShadow(rounded(window, 12), offset: CGSize(width: 3, height: -7), blur: 10, color: p3(0, 0.5))
    }
    // Brass: its colour, a sheen across it from the lamp, and its edges lit and shaded.
    ctx.group {
        ctx.clipPath(holder, evenOdd: false)
        ctx.linear(brass, CGPoint(x: frame.minX, y: frame.maxY), CGPoint(x: frame.maxX, y: frame.minY))
        ctx.linear(gradient([(p3(0xFFFFFF, 0), 0.30), (p3(0xFFF6DA, 0.55), 0.42), (p3(0xFFFFFF, 0), 0.52)]),
                   CGPoint(x: frame.minX, y: frame.maxY), CGPoint(x: frame.maxX, y: frame.minY))
    }
    ctx.innerShadow(holder, offset: CGSize(width: 0, height: -4), blur: 3, color: p3(0xFFF8DC, 0.8))
    ctx.innerShadow(holder, offset: CGSize(width: -2, height: 4), blur: 4, color: p3(0x3A2808, 0.55))
    for x in [frame.minX + 42, frame.maxX - 42] {
        let rivet = circle(CGPoint(x: x, y: frame.midY), 15)
        ctx.shadowOnly(rivet, offset: CGSize(width: 2, height: -3), blur: 3, color: p3(0x2A1A05, 0.7))
        ctx.group { ctx.clipPath(rivet); ctx.radial(gradient([(p3(0xFFF7D2), 0), (p3(0xD8B05A), 0.45), (p3(0x6E4F1C), 1)]), CGPoint(x: x - 5, y: frame.midY + 6), 22) }
    }
    // The cup pull, below: a half moon of brass on a flange, two screws.
    let cupTop: CGFloat = 400
    let cup = CGMutablePath()
    cup.move(to: CGPoint(x: 292, y: cupTop))
    cup.addLine(to: CGPoint(x: 732, y: cupTop))
    cup.addCurve(to: CGPoint(x: 512, y: 236), control1: CGPoint(x: 732, y: 300), control2: CGPoint(x: 640, y: 236))
    cup.addCurve(to: CGPoint(x: 292, y: cupTop), control1: CGPoint(x: 384, y: 236), control2: CGPoint(x: 292, y: 300))
    cup.closeSubpath()
    let flange = rounded(CGRect(x: 262, y: cupTop - 8, width: 500, height: 34), 17)
    ctx.shadowOnly(union([cup, flange]), offset: CGSize(width: 8, height: -20), blur: 26, color: p3(0, 0.6))
    ctx.group {
        ctx.clipPath(cup)
        ctx.linear(gradient([(p3(0x5E4418), 0), (p3(0x9C7834), 0.25), (p3(0xE9CB7E), 0.62), (p3(0xFFF0C2), 0.8), (p3(0xB28A3E), 1)]),
                   CGPoint(x: 0, y: cupTop), CGPoint(x: 0, y: 236))
        ctx.linear(gradient([(p3(0x000000, 0.25), 0), (p3(0x000000, 0), 0.3), (p3(0x000000, 0), 0.7), (p3(0x000000, 0.3), 1)]),
                   CGPoint(x: 292, y: 0), CGPoint(x: 732, y: 0))
    }
    ctx.group {
        ctx.clipPath(flange)
        ctx.linear(brass, CGPoint(x: 262, y: cupTop + 26), CGPoint(x: 762, y: cupTop - 8))
    }
    ctx.innerShadow(flange, offset: CGSize(width: 0, height: -3), blur: 2, color: p3(0xFFF8DC, 0.8))
    for x: CGFloat in [286, 738] {
        let screw = circle(CGPoint(x: x, y: cupTop + 9), 9)
        ctx.group { ctx.clipPath(screw); ctx.radial(gradient([(p3(0xFFF2C6), 0), (p3(0x8A6A2A), 1)]), CGPoint(x: x - 3, y: cupTop + 12), 12) }
        let slot = CGMutablePath(); slot.move(to: CGPoint(x: x - 6, y: cupTop + 6)); slot.addLine(to: CGPoint(x: x + 6, y: cupTop + 12))
        ctx.stroke(slot, p3(0x3A2808, 0.8), 2)
    }
}

// MARK: 04 Riso — two inks overprinted and out of register: an orange sun, a blue ticket, where they cross a third colour.

func riso(_ ctx: CGContext) {
    ctx.radial(gradient([(p3(0xF8F3E7), 0), (p3(0xEEE6D3), 1)]), CGPoint(x: 400, y: 700), 900)
    let fluoro = p3(0xEF5B2C), blue = p3(0x2C54A6)
    ctx.group {
        ctx.setBlendMode(.multiply)
        let sun = CGPoint(x: 612, y: 628), r: CGFloat = 268
        ctx.fill(circle(sun, r), fluoro)
        // The halftone falling off around it: the riso's gradient, every dot a dot of the same ink.
        let step: CGFloat = 24
        var y: CGFloat = 0, row = 0
        while y < S {
            var x: CGFloat = row % 2 == 0 ? 0 : step / 2
            while x < S {
                let d = hypot(x - sun.x, y - sun.y)
                if d > r + 6 && d < r + 190 {
                    let t = 1 - (d - r) / 190
                    ctx.fill(circle(CGPoint(x: x, y: y), 10.5 * sqrt(t)), fluoro)
                }
                x += step
            }
            y += step * 0.866; row += 1
        }
    }
    let t = CGAffineTransform(translationX: 452, y: 420).rotated(by: -11 * .pi / 180)
    let w: CGFloat = 680, h: CGFloat = 350
    let shape = ticket(CGRect(x: -w / 2, y: -h / 2, width: w, height: h), corner: 22, notchX: 176, notch: 26)
    var dots: [CGPath] = []
    var yy = -h / 2 + 34
    while yy < h / 2 - 30 { dots.append(circle(CGPoint(x: 176, y: yy), 5)); yy += 22 }
    let size = fitting("ADMIT", "HostGrotesk-ExtraBold", width: 390, max: 140, kern: -2)
    let type = union([setText("ADMIT", font("HostGrotesk-ExtraBold", size), at: CGPoint(x: -w / 2 + 52, y: 12), kern: -2),
                      setText("ONE", font("HostGrotesk-ExtraBold", size), at: CGPoint(x: -w / 2 + 52, y: 12 - size * 0.86), kern: -2)])
    let number = setText("0412", font("FragmentMono-Regular", 40), at: CGPoint(x: 262, y: -14), anchor: 0.5, degrees: 90)
    ctx.group {
        ctx.setBlendMode(.multiply)
        ctx.concatenate(t)
        ctx.fill(shape.subtracting(union(dots + [type, number])), blue)
    }
    ctx.group {
        ctx.setBlendMode(.multiply)
        ctx.concatenate(t)
        ctx.translateBy(x: 10, y: -8)
        ctx.fill(type, fluoro)
    }
}

// MARK: 05 Punched — the stock itself, full bleed: a blind-embossed border, a number, and the conductor's crescent punched clean through.

func crescent(_ c: CGPoint, _ r: CGFloat) -> CGPath {
    let bite = r * 0.82
    return circle(c, r).subtracting(circle(CGPoint(x: c.x + r * 0.48, y: c.y + r * 0.22), bite))
}

func punched(_ ctx: CGContext) {
    let full = CGRect(x: 0, y: 0, width: S, height: S)
    let moon = crescent(CGPoint(x: 548, y: 470), 236)
    let holes = (0..<11).map { circle(CGPoint(x: 172 + CGFloat($0) * 68, y: 132), 10) }
    let card = CGPath(rect: full, transform: nil).subtracting(union([moon] + holes))
    // The table under the card, seen through the holes.
    ctx.radial(gradient([(p3(0x3A2C22), 0), (p3(0x15100C), 1)]), CGPoint(x: 520, y: 460), 400)
    ctx.group {
        ctx.clipPath(card)
        ctx.linear(gradient([(p3(0xFDF8EE), 0), (p3(0xF3EBD9), 0.5), (p3(0xE4D8C0), 1)]), CGPoint(x: 0, y: S), CGPoint(x: S, y: 0))
        ctx.radial(gradient([(p3(0x000000, 0), 0.6), (p3(0x6B5636, 0.12), 1)]), CGPoint(x: 460, y: 560), 760)
        // The border, pressed in with no ink: dark on the wall the lamp cannot see, light on the one it can.
        for (inset, width) in [(108, 6), (124, 2.5)] as [(CGFloat, CGFloat)] {
            let rule = rounded(full.insetBy(dx: inset, dy: inset), 14).copy(strokingWithWidth: width, lineCap: .butt, lineJoin: .miter, miterLimit: 4)
            ctx.fill(rule, p3(0xE2D5BA))
            ctx.innerShadow(rule, offset: CGSize(width: 2, height: -2.5), blur: 2, color: p3(0x6B5636, 0.7))
            ctx.innerShadow(rule, offset: CGSize(width: -1.5, height: 2), blur: 1.5, color: p3(0xFFFFFF, 0.9))
        }
        let number = setText("Nº 0001", font("FragmentMono-Regular", 58), at: CGPoint(x: 168, y: 812))
        press(ctx, number, ink: p3(0xC4391D, 0.92))
    }
    // The punch's wall, and the card's own shadow on the table inside every hole.
    for hole in [moon] + holes {
        ctx.innerShadow(hole, offset: CGSize(width: 9, height: -12), blur: 14, color: p3(0, 0.85))
        ctx.group { ctx.clipPath(hole); ctx.stroke(transformed(hole, CGAffineTransform(translationX: -2.5, y: 3)), p3(0xD8C9AA, 0.9), 4) }
    }
}

// MARK: 06 Letterpress — one letter pressed deep into cotton, the orange plate over a navy one that missed by a few points.

func letterpress(_ ctx: CGContext) {
    ctx.linear(gradient([(p3(0xF8F2E6), 0), (p3(0xEFE6D4), 0.5), (p3(0xE0D3BA), 1)]), CGPoint(x: 0, y: S), CGPoint(x: S, y: 0))
    ctx.radial(gradient([(p3(0x000000, 0), 0.55), (p3(0x5A4A30, 0.10), 1)]), CGPoint(x: 470, y: 560), 760)
    let (glyph, _) = words("S", font("HostGrotesk-ExtraBold", 880))
    let box = glyph.boundingBoxOfPath
    let letter = transformed(glyph, CGAffineTransform(translationX: 512 - box.midX + 8, y: 512 - box.midY + 6))
    let missed = transformed(letter, CGAffineTransform(translationX: -15, y: 11))
    let pressed = letter.union(missed)
    ctx.fill(missed, p3(navy))
    ctx.fill(letter, p3(orange))
    // Ink squeezed to the edges of the impression.
    ctx.group { ctx.clipPath(letter); ctx.stroke(letter, p3(0x9E4116, 0.35), 12) }
    ctx.innerShadow(pressed, offset: CGSize(width: 6, height: -8), blur: 9, color: p3(0x000000, 0.5))
    ctx.innerShadow(pressed, offset: CGSize(width: -3, height: 4), blur: 4, color: p3(0xFFFFFF, 0.55))
    // The paper around the letter, pushed up a little by it.
    ctx.group {
        ctx.clipPath(CGPath(rect: CGRect(x: 0, y: 0, width: S, height: S), transform: nil).subtracting(pressed))
        ctx.stroke(transformed(pressed, CGAffineTransform(translationX: 2, y: -3)), p3(0xFFFFFF, 0.6), 5)
    }
}

// MARK: 07 Edition — what Stub prints for every film: a poster in its movement, the foil catching the lamp, the strip below.

func edition(_ ctx: CGContext) {
    table(ctx, [0x3E3630, 0x221D19, 0x0D0B0A], lamp: CGPoint(x: 280, y: 820))
    let w: CGFloat = 486, h: CGFloat = 778
    let (card, perf) = editionCard(w: w, h: h)
    let t = CGAffineTransform(translationX: 520, y: 502).rotated(by: -6 * .pi / 180)
    ctx.shadowOnly(transformed(card, t), offset: CGSize(width: 24, height: -34), blur: 52, color: p3(0, 0.65))
    ctx.shadowOnly(transformed(card, t), offset: CGSize(width: 4, height: -6), blur: 8, color: p3(0, 0.5))
    ctx.group {
        ctx.concatenate(t)
        ctx.clipPath(card)
        ctx.fill(CGPath(rect: CGRect(x: -w / 2, y: -h / 2, width: w, height: h), transform: nil), p3(0xEDE0C4))
        ctx.group {
            ctx.clip(to: CGRect(x: -w / 2, y: perf, width: w, height: h / 2 - perf))
            // The disc, in foil: the metal, the lamp's streak across it.
            let disc = circle(CGPoint(x: -64, y: 214), 150)
            ctx.group {
                ctx.clipPath(disc)
                ctx.linear(gradient([(p3(0xFFF1BE), 0), (p3(0xD9B566), 0.3), (p3(0x8E6A2C), 0.55), (p3(0xE8CF8A), 0.75), (p3(0xA78238), 1)]),
                           CGPoint(x: -214, y: 364), CGPoint(x: 86, y: 64))
                ctx.linear(gradient([(p3(0xFFFFFF, 0), 0.38), (p3(0xFFFFFF, 0.7), 0.46), (p3(0xFFFFFF, 0), 0.54)]),
                           CGPoint(x: -214, y: 300), CGPoint(x: 86, y: 128))
            }
            ctx.innerShadow(disc, offset: CGSize(width: -2, height: 3), blur: 3, color: p3(0xFFFFFF, 0.6))
            let angle: CGFloat = 27
            let band = transformed(CGPath(rect: CGRect(x: -500, y: -62, width: 1000, height: 124), transform: nil),
                                   CGAffineTransform(translationX: 10, y: 0).rotated(by: angle * .pi / 180))
            ctx.fill(band, p3(0xB5451B))
            let title = setText("STUB", font("HostGrotesk-ExtraBold", 112), at: CGPoint(x: 14, y: -30), anchor: 0.5, degrees: angle, kern: -2)
            ctx.fill(title, p3(0xEDE0C4))
            for (dy, len, thick) in [(-112, 330, 18), (-150, 210, 9)] as [(CGFloat, CGFloat, CGFloat)] {
                let bar = transformed(CGPath(rect: CGRect(x: -len / 2, y: -thick / 2, width: len, height: thick), transform: nil),
                                      CGAffineTransform(rotationAngle: angle * .pi / 180).translatedBy(x: 40, y: dy))
                ctx.fill(bar, p3(0x2A1D14))
            }
            ctx.fill(setText("2026", font("FragmentMono-Regular", 64), at: CGPoint(x: w / 2 - 30, y: perf + 40), anchor: 1), p3(0x2A1D14))
        }
        let strip = p3(0x2A1D14)
        ctx.fill(setText("Stub", font("HostGrotesk-Medium", 34), at: CGPoint(x: -w / 2 + 30, y: perf - 52)), strip)
        ctx.fill(setText("15 OCT 2026 · 20:30", font("FragmentMono-Regular", 22), at: CGPoint(x: -w / 2 + 30, y: perf - 118)), strip)
        ctx.fill(setText("Screen 2 · F12", font("FragmentMono-Regular", 22), at: CGPoint(x: -w / 2 + 30, y: perf - 146)), strip)
        ctx.fill(setText("First viewing", font("Newsreader16pt-Italic", 28), at: CGPoint(x: w / 2 - 30, y: perf - 146), anchor: 1), p3(0xB5451B))
        // The lamp across the card.
        ctx.linear(gradient([(p3(0xFFFFFF, 0.16), 0), (p3(0xFFFFFF, 0), 0.6), (p3(0x000000, 0.08), 1)]), CGPoint(x: -w / 2, y: h / 2), CGPoint(x: w / 2, y: -h / 2))
    }
}

// MARK: 08 Marquee — the cinema's own sign at night: a red frame of bulbs and the name in black letters on the lit board.

func marquee(_ ctx: CGContext) {
    ctx.linear(gradient([(p3(0x1E2438), 0), (p3(0x0A0D18), 1)]), CGPoint(x: 0, y: S), CGPoint(x: 0, y: 0))
    let outer = CGRect(x: 72, y: 268, width: 880, height: 488)
    let board = outer.insetBy(dx: 92, dy: 92)
    // The board's light on the night around it.
    ctx.blurred(rounded(outer.insetBy(dx: -20, dy: -20), 60), blur: 90, color: p3(0xFFB861, 0.45))
    ctx.shadowOnly(rounded(outer, 40), offset: CGSize(width: 0, height: -26), blur: 40, color: p3(0, 0.7))
    let frame = rounded(outer, 40)
    ctx.group {
        ctx.clipPath(frame)
        ctx.linear(gradient([(p3(0xC8372F), 0), (p3(0x9B1D1B), 0.5), (p3(0x5E0F10), 1)]), CGPoint(x: 0, y: outer.maxY), CGPoint(x: 0, y: outer.minY))
        ctx.linear(gradient([(p3(0xFFFFFF, 0), 0.0), (p3(0xFFFFFF, 0.25), 0.12), (p3(0xFFFFFF, 0), 0.3)]), CGPoint(x: 0, y: outer.maxY), CGPoint(x: 0, y: outer.minY))
    }
    ctx.innerShadow(frame, offset: CGSize(width: 0, height: -4), blur: 3, color: p3(0xFF9B8A, 0.6))
    // The board, lit from behind, its tracks for the letters.
    let lit = rounded(board, 10)
    ctx.group {
        ctx.clipPath(lit)
        ctx.linear(gradient([(p3(0xFFFBEF), 0), (p3(0xFBEFD2), 0.6), (p3(0xF0DDB4), 1)]), CGPoint(x: 0, y: board.maxY), CGPoint(x: 0, y: board.minY))
        var y = board.minY + 26
        while y < board.maxY {
            let track = CGMutablePath(); track.move(to: CGPoint(x: board.minX, y: y)); track.addLine(to: CGPoint(x: board.maxX, y: y))
            ctx.stroke(track, p3(0xC9B48A, 0.55), 3)
            ctx.group { ctx.translateBy(x: 0, y: -3); ctx.stroke(track, p3(0xFFFFFF, 0.6), 1.5) }
            y += 52
        }
        let size = fitting("STUB", "HostGrotesk-Bold", width: board.width - 90, max: 230, kern: 6)
        let name = setText("STUB", font("HostGrotesk-Bold", size), at: CGPoint(x: board.midX, y: board.midY - size * 0.36), anchor: 0.5, kern: 6)
        ctx.shadowOnly(name, offset: CGSize(width: 5, height: -9), blur: 9, color: p3(0x3A2A10, 0.45))
        ctx.fill(name, p3(0x141414))
        ctx.innerShadow(lit, offset: CGSize(width: 0, height: -10), blur: 14, color: p3(0x5E0F10, 0.55))
    }
    // The bulbs, round the board: glass, a hot filament, the light they throw.
    var bulbs: [CGPoint] = []
    let ring = outer.insetBy(dx: 46, dy: 46)
    let across = 12, down = 6
    for i in 0...across {
        let x = ring.minX + ring.width * CGFloat(i) / CGFloat(across)
        bulbs += [CGPoint(x: x, y: ring.maxY), CGPoint(x: x, y: ring.minY)]
    }
    for i in 1..<down {
        let y = ring.minY + ring.height * CGFloat(i) / CGFloat(down)
        bulbs += [CGPoint(x: ring.minX, y: y), CGPoint(x: ring.maxX, y: y)]
    }
    for b in bulbs { ctx.fill(circle(b, 21), p3(0x3A0B0B)); ctx.innerShadow(circle(b, 21), offset: CGSize(width: 0, height: -3), blur: 3, color: p3(0, 0.7)) }
    ctx.group {
        ctx.setBlendMode(.screen)
        for b in bulbs { ctx.radial(gradient([(p3(0xFFD27A, 0.55), 0), (p3(0xFFB050, 0), 1)]), b, 52) }
    }
    for b in bulbs {
        ctx.group { ctx.clipPath(circle(b, 15)); ctx.radial(gradient([(p3(0xFFFFFF), 0), (p3(0xFFF0C2), 0.45), (p3(0xF7B655), 1)]), CGPoint(x: b.x - 3, y: b.y + 4), 18) }
    }
}

// MARK: 09 Hand — three editions fanned like a hand of cards: a riso, a noir, a deco. The drawer, in one glance.

func hand(_ ctx: CGContext) {
    ctx.radial(gradient([(p3(0xF6F1E6), 0), (p3(0xE9E1CF), 0.6), (p3(0xDAD0BB), 1)]), CGPoint(x: 420, y: 760), 1000)
    let w: CGFloat = 372, h: CGFloat = 595
    let (card, perf) = editionCard(w: w, h: h)
    let pivot = CGPoint(x: 512, y: 60)
    func place(_ degrees: CGFloat) -> CGAffineTransform {
        CGAffineTransform(translationX: pivot.x, y: pivot.y).rotated(by: -degrees * .pi / 180).translatedBy(x: 0, y: 452)
    }
    func draw(_ degrees: CGFloat, _ art: (CGFloat) -> Void) {
        let t = place(degrees)
        ctx.shadowOnly(transformed(card, t), offset: CGSize(width: 14, height: -22), blur: 30, color: p3(0x3A2A1A, 0.45))
        ctx.group {
            ctx.concatenate(t)
            ctx.clipPath(card)
            art(perf)
            ctx.linear(gradient([(p3(0xFFFFFF, 0.12), 0), (p3(0xFFFFFF, 0), 0.5), (p3(0x000000, 0.06), 1)]), CGPoint(x: -w / 2, y: h / 2), CGPoint(x: w / 2, y: -h / 2))
        }
    }
    let poster = CGRect(x: -w / 2, y: 0, width: w, height: h / 2)
    draw(-19) { perf in
        ctx.fill(CGPath(rect: CGRect(x: -w / 2, y: -h / 2, width: w, height: h), transform: nil), p3(0xF4E5DA))
        ctx.group {
            ctx.clip(to: CGRect(x: -w / 2, y: perf, width: w, height: h / 2 - perf))
            ctx.setBlendMode(.multiply)
            ctx.fill(circle(CGPoint(x: 30, y: 120), 120), p3(0xEF6A4C))
            ctx.fill(transformed(CGPath(rect: CGRect(x: -120, y: -70, width: 200, height: 140), transform: nil),
                                 CGAffineTransform(translationX: -26, y: 30).rotated(by: 0.14)), p3(0x2F3E75))
            ctx.fill(setText("MATINEE", font("HostGrotesk-ExtraBold", 52), at: CGPoint(x: -w / 2 + 22, y: perf + 30), kern: -1), p3(0x2F3E75))
        }
        ctx.fill(setText("Matinee", font("HostGrotesk-Medium", 22), at: CGPoint(x: -w / 2 + 20, y: perf - 36)), p3(0x2A1F2E))
        ctx.fill(setText("02 JUN 2024 · 16:15", font("FragmentMono-Regular", 15), at: CGPoint(x: -w / 2 + 20, y: perf - 80)), p3(0x2A1F2E))
    }
    draw(19) { perf in
        ctx.fill(CGPath(rect: CGRect(x: -w / 2, y: -h / 2, width: w, height: h), transform: nil), p3(0x15171D))
        ctx.group {
            ctx.clip(to: CGRect(x: -w / 2, y: perf, width: w, height: h / 2 - perf))
            for i in 0..<8 {
                let slat = transformed(CGPath(rect: CGRect(x: -400, y: -9, width: 800, height: 18), transform: nil),
                                       CGAffineTransform(rotationAngle: -0.42).translatedBy(x: 0, y: 220 - CGFloat(i) * 40))
                ctx.fill(slat, p3(0xEDE6D6, 0.13))
            }
            ctx.group { ctx.clipPath(circle(CGPoint(x: 70, y: 170), 52)); ctx.radial(gradient([(p3(0xF4F5F7), 0), (p3(0x9EA4AE), 1)]), CGPoint(x: 56, y: 186), 70) }
            ctx.fill(setText("Night", font("Newsreader16pt-Italic", 92), at: CGPoint(x: -w / 2 + 24, y: perf + 40)), p3(0xC9CCD2))
        }
        ctx.fill(setText("Night", font("Newsreader16pt-Italic", 26), at: CGPoint(x: -w / 2 + 20, y: perf - 36)), p3(0xEDE6D6))
        ctx.fill(setText("19 FEB 2025 · 20:15", font("FragmentMono-Regular", 15), at: CGPoint(x: -w / 2 + 20, y: perf - 80)), p3(0xEDE6D6, 0.8))
    }
    draw(0) { perf in
        ctx.fill(CGPath(rect: CGRect(x: -w / 2, y: -h / 2, width: w, height: h), transform: nil), p3(0x0F2B5C))
        ctx.group {
            ctx.clip(to: CGRect(x: -w / 2, y: perf, width: w, height: h / 2 - perf))
            let origin = CGPoint(x: 0, y: perf + 10)
            let gold = gradient([(p3(0xFFF0BE), 0), (p3(0xD9B566), 0.35), (p3(0x9A7530), 0.7), (p3(0xE6CB86), 1)])
            let rays = CGMutablePath()
            for i in 0..<15 where i % 2 == 0 {
                let a0 = CGFloat.pi * CGFloat(i) / 15, a1 = CGFloat.pi * CGFloat(i + 1) / 15
                rays.move(to: origin)
                rays.addLine(to: CGPoint(x: origin.x + 600 * cos(a0), y: origin.y + 600 * sin(a0)))
                rays.addLine(to: CGPoint(x: origin.x + 600 * cos(a1), y: origin.y + 600 * sin(a1)))
                rays.closeSubpath()
            }
            let arch = circle(origin, 120)
            ctx.group { ctx.clipPath(rays.subtracting(arch)); ctx.linear(gold, CGPoint(x: -w / 2, y: h / 2), CGPoint(x: w / 2, y: perf)) }
            ctx.group { ctx.clipPath(arch.subtracting(circle(origin, 108))); ctx.linear(gold, CGPoint(x: -120, y: perf + 130), CGPoint(x: 120, y: perf)) }
            ctx.group {
                ctx.clipPath(setText("ENCORE", font("HostGrotesk-Light", 40), at: CGPoint(x: 0, y: perf + 160), anchor: 0.5, kern: 9))
                ctx.linear(gold, CGPoint(x: -120, y: perf + 200), CGPoint(x: 120, y: perf + 150))
            }
        }
        ctx.fill(setText("ENCORE", font("HostGrotesk-Light", 20), at: CGPoint(x: -w / 2 + 20, y: perf - 36), kern: 2.4), p3(0xF4F1EA))
        ctx.fill(setText("24 MAR 2024 · 20:30", font("FragmentMono-Regular", 15), at: CGPoint(x: -w / 2 + 20, y: perf - 80)), p3(0xF4F1EA, 0.8))
        ctx.fill(setText("Second viewing", font("Newsreader16pt-Italic", 18), at: CGPoint(x: w / 2 - 20, y: perf - 104), anchor: 1), p3(0xF2C14E))
    }
    _ = poster
}

// MARK: 10 Scallop — the edge of a kept stub up close: the half-holes it was torn along, the paper's fibres, a number.

func scallop(_ ctx: CGContext) {
    ctx.linear(gradient([(p3(0x221A14), 0), (p3(0x0F0C0A), 1)]), CGPoint(x: 0, y: S), CGPoint(x: 0, y: 0))
    ctx.radial(gradient([(p3(0xD4622B, 0.5), 0), (p3(0xD4622B, 0), 1)]), CGPoint(x: 512, y: 120), 620)
    var dice = Seeded(state: 0x5CA1)
    let edge: CGFloat = 400, r: CGFloat = 32, pitch: CGFloat = 104
    let paper = CGMutablePath()
    paper.move(to: CGPoint(x: -20, y: S + 20))
    paper.addLine(to: CGPoint(x: -20, y: edge))
    var x: CGFloat = -20
    var fibres: [CGPoint] = []
    let centres = stride(from: CGFloat(512) - pitch * 5, through: 512 + pitch * 5, by: pitch).map { $0 }
    for c in centres {
        while x < c - r - 1 { x += dice.between(1.4, 3.2); let p = CGPoint(x: min(x, c - r), y: edge + dice.between(-3, 3)); paper.addLine(to: p); fibres.append(p) }
        for k in 0...16 {
            let a = CGFloat.pi - .pi * CGFloat(k) / 16
            paper.addLine(to: CGPoint(x: c + r * cos(a), y: edge + r * sin(a)))
        }
        x = c + r
    }
    while x < S + 20 { x += dice.between(1.4, 3.2); let p = CGPoint(x: x, y: edge + dice.between(-3, 3)); paper.addLine(to: p); fibres.append(p) }
    paper.addLine(to: CGPoint(x: S + 20, y: S + 20))
    paper.closeSubpath()
    ctx.shadowOnly(paper, offset: CGSize(width: 0, height: -26), blur: 34, color: p3(0, 0.75))
    ctx.group {
        ctx.clipPath(paper)
        ctx.linear(gradient([(p3(0xFDF8EC), 0), (p3(0xF1E8D4), 0.6), (p3(0xE2D5BA), 1)]), CGPoint(x: 0, y: S), CGPoint(x: S, y: edge))
        ctx.stroke(rounded(CGRect(x: 96, y: edge + 56, width: S - 192, height: S), 10), p3(ink, 0.45), 2.4)
        ctx.stroke(rounded(CGRect(x: 108, y: edge + 68, width: S - 216, height: S), 8), p3(ink, 0.35), 1)
        let size = fitting("0001", "FragmentMono-Regular", width: 700, max: 260)
        press(ctx, setText("0001", font("FragmentMono-Regular", size), at: CGPoint(x: 512, y: edge + 170), anchor: 0.5), plate: CGSize(width: 9, height: -7))
        press(ctx, setText("ADMIT ONE", font("HostGrotesk-Bold", 60), at: CGPoint(x: 512, y: 820), anchor: 0.5, kern: -0.5))
        ctx.stroke(paper, p3(0xFFFFFF, 0.65), 6)
    }
    var hairs = Seeded(state: 0xF1BE)
    for p in fibres where hairs.next() < 0.35 {
        let a = hairs.between(-0.5, 0.5) - .pi / 2, len = hairs.between(2, 7)
        let f = CGMutablePath(); f.move(to: p); f.addLine(to: CGPoint(x: p.x + len * cos(a), y: p.y + len * sin(a)))
        ctx.stroke(f, p3(0xFFFBF0, 0.85), hairs.between(0.7, 1.3), cap: .round)
    }
}

// MARK: The studies, and the sheets to compare them on.

let studies: [(String, String, (CGContext) -> Void)] = [
    ("01-torn", "Torn", torn), ("02-roll", "Roll", roll), ("03-label", "Label", label), ("04-riso", "Riso", riso),
    ("05-punched", "Punched", punched), ("06-letterpress", "Letterpress", letterpress), ("07-edition", "Edition", edition),
    ("08-marquee", "Marquee", marquee), ("09-hand", "Hand", hand), ("10-scallop", "Scallop", scallop),
]

var images: [CGImage] = []
for (file, _, draw) in studies {
    let ctx = canvas()
    draw(ctx)
    let image = ctx.makeImage()!
    write(image, "\(file).png")
    images.append(image)
    print("wrote \(outDir)/\(file).png")
}

/// The home screen's mask: a superellipse, near enough to the system's continuous corner.
func squircle(_ r: CGRect) -> CGPath {
    let path = CGMutablePath()
    let n: CGFloat = 5
    for i in 0...360 {
        let t = CGFloat(i) * .pi / 180
        let c = cos(t), s = sin(t)
        let x = r.midX + r.width / 2 * (c < 0 ? -1 : 1) * pow(abs(c), 2 / n)
        let y = r.midY + r.height / 2 * (s < 0 ? -1 : 1) * pow(abs(s), 2 / n)
        i == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
    }
    path.closeSubpath()
    return path
}

func icon(_ ctx: CGContext, _ image: CGImage, in r: CGRect, shadow: Bool = true) {
    if shadow { ctx.shadowOnly(squircle(r), offset: CGSize(width: 0, height: -r.width * 0.03), blur: r.width * 0.08, color: p3(0, 0.28)) }
    ctx.group { ctx.clipPath(squircle(r)); ctx.draw(image, in: r) }
}

// The sheet: the ten at 340, named, on parchment.
do {
    let cell: CGFloat = 340, gap: CGFloat = 64, margin: CGFloat = 96
    let width = margin * 2 + cell * 5 + gap * 4, height: CGFloat = 1180
    let ctx = canvas(width, height)
    ctx.fill(CGPath(rect: CGRect(x: 0, y: 0, width: width, height: height), transform: nil), p3(0xF0EDE6))
    ctx.fill(setText("Stub — ten studies for the icon", font("HostGrotesk-Medium", 44), at: CGPoint(x: margin, y: height - 120)), p3(ink))
    for (i, image) in images.enumerated() {
        let col = CGFloat(i % 5), row = CGFloat(i / 5)
        let r = CGRect(x: margin + col * (cell + gap), y: height - 220 - cell - row * (cell + 150), width: cell, height: cell)
        icon(ctx, image, in: r)
        ctx.fill(setText(String(format: "%02d", i + 1), font("FragmentMono-Regular", 26), at: CGPoint(x: r.minX, y: r.minY - 56)), p3(0x8A8578))
        ctx.fill(setText(studies[i].1, font("HostGrotesk-Medium", 30), at: CGPoint(x: r.minX + 52, y: r.minY - 56)), p3(ink))
    }
    write(ctx.makeImage()!, "sheet.png")
}

// Home-screen size: 60 points at 3x, on a light wallpaper and a dark one, named as the springboard names it.
do {
    let cell: CGFloat = 180, gap: CGFloat = 84, margin: CGFloat = 80
    let width = margin * 2 + cell * 10 + gap * 9, band: CGFloat = 340
    let ctx = canvas(width, band * 2)
    ctx.linear(gradient([(p3(0xE9E2F0), 0), (p3(0xF6E6D8), 1)]), CGPoint(x: 0, y: band * 2), CGPoint(x: width, y: band))
    ctx.group {
        ctx.clip(to: CGRect(x: 0, y: 0, width: width, height: band))
        ctx.linear(gradient([(p3(0x1B2236), 0), (p3(0x0B0D14), 1)]), CGPoint(x: 0, y: band), CGPoint(x: width, y: 0))
    }
    for (b, dark) in [(band, false), (CGFloat(0), true)] {
        for (i, image) in images.enumerated() {
            let r = CGRect(x: margin + CGFloat(i) * (cell + gap), y: b + 110, width: cell, height: cell)
            icon(ctx, image, in: r)
            ctx.fill(setText(String(format: "%02d", i + 1), font("HostGrotesk-Medium", 30), at: CGPoint(x: r.midX, y: b + 56), anchor: 0.5),
                     dark ? p3(0xFFFFFF, 0.92) : p3(ink, 0.85))
        }
    }
    write(ctx.makeImage()!, "home.png")
}
print("wrote \(outDir)/sheet.png and home.png")

// Into the asset catalogue: each icon a 1024 app icon set, and a small copy for the chooser to show.
if installs {
    let catalogue = root.appending(path: "Stub/Resources/Assets.xcassets")
    let iconContents = #"{"images":[{"filename":"Icon.png","idiom":"universal","platform":"ios","size":"1024x1024"}],"info":{"author":"xcode","version":1}}"#
    let imageContents = #"{"images":[{"filename":"Icon.png","idiom":"universal","scale":"3x"}],"info":{"author":"xcode","version":1}}"#
    let previews = catalogue.appending(path: "Icons")
    try? FileManager.default.createDirectory(at: previews, withIntermediateDirectories: true)
    try! #"{"info":{"author":"xcode","version":1}}"#.write(to: previews.appending(path: "Contents.json"), atomically: true, encoding: .utf8)
    for (i, image) in images.enumerated() {
        let name = studies[i].1
        let set = catalogue.appending(path: i == 0 ? "AppIcon.appiconset" : "AppIcon-\(name).appiconset")
        try? FileManager.default.removeItem(at: set)
        try! FileManager.default.createDirectory(at: set, withIntermediateDirectories: true)
        try! iconContents.write(to: set.appending(path: "Contents.json"), atomically: true, encoding: .utf8)
        try! NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!.write(to: set.appending(path: "Icon.png"))
        let small = canvas(240, 240)
        small.draw(image, in: CGRect(x: 0, y: 0, width: 240, height: 240))
        let preview = previews.appending(path: "Icon-\(name).imageset")
        try? FileManager.default.removeItem(at: preview)
        try! FileManager.default.createDirectory(at: preview, withIntermediateDirectories: true)
        try! imageContents.write(to: preview.appending(path: "Contents.json"), atomically: true, encoding: .utf8)
        try! NSBitmapImageRep(cgImage: small.makeImage()!).representation(using: .png, properties: [:])!.write(to: preview.appending(path: "Icon.png"))
    }
    print("installed \(images.count) icons into \(catalogue.path)")
}
