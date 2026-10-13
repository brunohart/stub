#!/usr/bin/env swift
// Draws the app icon (ADR-022): one ticket stub, kept. Cream card torn along its perforation, ADMIT ONE pressed into it in
// ink with the orange plate a pass out of register, a crescent punched through it, lying on a dark table under a lamp.
// Usage: swift scripts/make-icon.swift [out.png]   (default Stub/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png)
// The icon is generated, like the fixtures (ADR-003) and the project (ADR-004): the source is this file. Every random
// thing in it (the fibres of the tear) comes from a fixed seed, so it draws the same icon every time.
import Foundation
import AppKit
import CoreText

let out = CommandLine.arguments.dropFirst().first ?? "Stub/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
let side: CGFloat = 1024
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()

// The app's own faces, registered for this process from the repo.
for name in ["HostGrotesk-Variable.ttf", "FragmentMono-Regular.ttf"] {
    CTFontManagerRegisterFontsForURL(root.appending(path: "Stub/Resources/Fonts/\(name)") as CFURL, .process, nil)
}

func p3(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: CGColorSpace(name: CGColorSpace.displayP3)!,
            components: [CGFloat((hex >> 16) & 0xFF) / 255, CGFloat((hex >> 8) & 0xFF) / 255, CGFloat(hex & 0xFF) / 255, alpha])!
}

/// A seeded generator, so the tear's fibres are the same on every run.
struct Seeded { var state: UInt64; mutating func next() -> CGFloat {
    state = state &* 6364136223846793005 &+ 1442695040888963407
    return CGFloat((state >> 33) & 0xFFFFFF) / CGFloat(0xFFFFFF)
} }
var dice = Seeded(state: 0x5717B)

// An app icon may not carry an alpha channel: an opaque P3 bitmap.
guard let ctx = CGContext(data: nil, width: Int(side), height: Int(side), bitsPerComponent: 8, bytesPerRow: 0,
                          space: CGColorSpace(name: CGColorSpace.displayP3)!,
                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { exit(1) }
ctx.interpolationQuality = .high
ctx.setShouldAntialias(true)

// MARK: The table, under a lamp: warm dark, lit from the upper left. Light, not texture.
let lamp = CGPoint(x: 300, y: 790)
let table = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.displayP3), colors: [p3(0x4A4038), p3(0x2A2420), p3(0x110F0D)] as CFArray,
                       locations: [0, 0.45, 1])!
ctx.drawRadialGradient(table, startCenter: lamp, startRadius: 0, endCenter: lamp, endRadius: 980, options: [.drawsAfterEndLocation])

// MARK: The stub's shape, in its own coordinates: centred on the origin, landscape.
let w: CGFloat = 752, h: CGFloat = 404, corner: CGFloat = 26
let holeRadius: CGFloat = 10.5, holePitch: CGFloat = 30

/// The outline: a clean cut on the right with rounded corners, straight top and bottom, and on the left the perforation it
/// was torn along: half of every hole, and between them the paper torn ragged, a fibre or two standing proud.
func outline() -> CGPath {
    let path = CGMutablePath()
    let left = -w / 2, right = w / 2, top = h / 2, bottom = -h / 2
    path.move(to: CGPoint(x: left + 4, y: bottom))
    path.addLine(to: CGPoint(x: right - corner, y: bottom))
    path.addQuadCurve(to: CGPoint(x: right, y: bottom + corner), control: CGPoint(x: right, y: bottom))
    path.addLine(to: CGPoint(x: right, y: top - corner))
    path.addQuadCurve(to: CGPoint(x: right - corner, y: top), control: CGPoint(x: right, y: top))
    path.addLine(to: CGPoint(x: left + 4, y: top))
    // Down the torn edge, top to bottom: a ragged run of paper, then half a hole, again and again.
    var y = top
    let holes = Int((h - holePitch) / holePitch)
    let start = top - (h - CGFloat(holes - 1) * holePitch) / 2
    for i in 0..<holes {
        let centre = start - CGFloat(i) * holePitch
        // Ragged paper from here to the top of the hole.
        var yy = y
        while yy > centre + holeRadius + 2 {
            yy -= 1.6 + dice.next() * 2.0
            let x = left + 0.5 + dice.next() * 2.8 - (dice.next() < 0.1 ? 2.2 : 0)
            path.addLine(to: CGPoint(x: x, y: max(yy, centre + holeRadius)))
        }
        // Half the hole: the paper's edge goes round it, bitten in.
        path.addArc(center: CGPoint(x: left, y: centre), radius: holeRadius, startAngle: .pi / 2, endAngle: -.pi / 2, clockwise: true)
        y = centre - holeRadius
    }
    var yy = y
    while yy > bottom + 3 {
        yy -= 1.6 + dice.next() * 2.0
        path.addLine(to: CGPoint(x: left + 0.5 + dice.next() * 2.8, y: max(yy, bottom)))
    }
    path.closeSubpath()
    return path
}

/// A crescent: a disc with a smaller disc taken out of it, offset. Noir's punch (Remarque), at the size of a real one.
func crescent(at c: CGPoint, radius r: CGFloat) -> CGPath {
    let disc = CGPath(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r), transform: nil)
    let bite = r * 0.84
    let biteDisc = CGPath(ellipseIn: CGRect(x: c.x - bite + r * 0.46, y: c.y - bite + r * 0.22, width: 2 * bite, height: 2 * bite),
                          transform: nil)
    return disc.subtracting(biteDisc)
}

let shape = outline()
let punchCentre = CGPoint(x: w / 2 - 92, y: -h / 2 + 96)
let punch = crescent(at: punchCentre, radius: 44)

// Where the stub lies: a little up and left of centre, turned as a stub on a table is.
let tilt: CGFloat = -8 * .pi / 180
let centre = CGPoint(x: side / 2 + 6, y: side / 2 + 10)
func onTheTable(_ body: () -> Void) {
    ctx.saveGState(); ctx.translateBy(x: centre.x, y: centre.y); ctx.rotate(by: tilt); body(); ctx.restoreGState()
}

/// The card with its punch cut out: even-odd, so the crescent is a hole.
func card() -> CGPath {
    let path = CGMutablePath()
    path.addPath(shape)
    path.addPath(punch)
    return path
}

// MARK: Shadows: one wide and soft from the lamp, one tight where the card touches the table.
onTheTable {
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 26, height: -34), blur: 56, color: p3(0x000000, 0.62))
    ctx.addPath(card()); ctx.setFillColor(p3(0x2A2420)); ctx.fillPath(using: .evenOdd)
    ctx.restoreGState()
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 4, height: -6), blur: 7, color: p3(0x000000, 0.55))
    ctx.addPath(card()); ctx.setFillColor(p3(0x2A2420)); ctx.fillPath(using: .evenOdd)
    ctx.restoreGState()
}

// MARK: The card: cream stock, lit from the lamp, a breath of curl at the clean end lifting into the light.
onTheTable {
    ctx.saveGState()
    ctx.addPath(card()); ctx.clip(using: .evenOdd)
    let stock = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.displayP3),
                           colors: [p3(0xFBF6EA), p3(0xF2EAD7), p3(0xE3D7BE)] as CFArray, locations: [0, 0.55, 1])!
    ctx.drawLinearGradient(stock, start: CGPoint(x: -w / 2, y: h / 2), end: CGPoint(x: w / 2, y: -h / 2), options: [])
    // The curl: the last fifth of the card lifts a little, so the lamp catches it.
    let curl = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.displayP3),
                          colors: [p3(0xFFFFFF, 0), p3(0xFFFFFF, 0.22), p3(0x000000, 0.05)] as CFArray, locations: [0, 0.7, 1])!
    ctx.drawLinearGradient(curl, start: CGPoint(x: w / 2 - 170, y: 0), end: CGPoint(x: w / 2, y: 0), options: [])
    // The card's own fibre where the edge was torn: the stock is lighter where its fibres stand up.
    ctx.setFillColor(p3(0xFFFFFF, 0.45))
    ctx.fill(CGRect(x: -w / 2, y: -h / 2, width: 7, height: h))
    ctx.restoreGState()
}

// MARK: The print. Everything printed is inside the clip of the card, so nothing prints over the tear or the punch.
/// Draws `text` at `origin`: first the bite of the type into the stock (a highlight below and to the right, where the lamp
/// lights the far wall of the impression), then the orange plate a pass out of register, then the ink.
func press(_ text: String, font: String, size: CGFloat, at origin: CGPoint, tracking: CGFloat = 0, plate: CGSize? = nil,
           color: CGColor = p3(0x1A1A1A, 0.93)) {
    func draw(_ color: CGColor, _ offset: CGSize, blend: CGBlendMode = .normal) {
        ctx.saveGState()
        ctx.setBlendMode(blend)
        let attrs: [NSAttributedString.Key: Any] = [.font: CTFontCreateWithName(font as CFString, size, nil), .kern: tracking,
                                                    .foregroundColor: color]
        ctx.textPosition = CGPoint(x: origin.x + offset.width, y: origin.y + offset.height)
        CTLineDraw(CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attrs)), ctx)
        ctx.restoreGState()
    }
    draw(p3(0xFFFFFF, 0.55), CGSize(width: 1.6, height: -1.8))
    if let plate { draw(p3(0xD4622B, 0.85), plate, blend: .multiply) }
    draw(color, .zero)
}

onTheTable {
    ctx.saveGState()
    ctx.addPath(card()); ctx.clip(using: .evenOdd)
    // A double rule inside the clean edges, as a roll ticket has; the torn side has lost its.
    ctx.setStrokeColor(p3(0x1A1A1A, 0.55))
    ctx.setLineWidth(2.2)
    ctx.stroke(CGRect(x: -w / 2 + 34, y: -h / 2 + 26, width: w - 34 - 26, height: h - 52))
    ctx.setLineWidth(1.0)
    ctx.stroke(CGRect(x: -w / 2 + 42, y: -h / 2 + 34, width: w - 42 - 34, height: h - 68))
    // ADMIT ONE, the ticket's whole text, in the app's face, heavy: a ticket is a poster, not the app's chrome.
    let face = "HostGrotesk-Bold"
    press("ADMIT", font: face, size: 144, at: CGPoint(x: -w / 2 + 76, y: 10), tracking: -3, plate: CGSize(width: 7, height: -5))
    press("ONE", font: face, size: 144, at: CGPoint(x: -w / 2 + 76, y: -128), tracking: -3, plate: CGSize(width: 7, height: -5))
    // Its number, in the mono, small, in the orange: the only number on it.
    press("Nº 0001", font: "FragmentMono-Regular", size: 30, at: CGPoint(x: w / 2 - 210, y: h / 2 - 82), color: p3(0xC4391D, 0.9))
    ctx.restoreGState()
}

// MARK: The punch's wall: where the crescent was cut, the stock's thickness shows on the side the lamp can see.
onTheTable {
    ctx.saveGState()
    ctx.addPath(punch); ctx.clip(using: .evenOdd)
    ctx.setShadow(offset: CGSize(width: -3, height: 4), blur: 5, color: p3(0x000000, 0.7))
    ctx.setStrokeColor(p3(0xE3D7BE, 0.9)); ctx.setLineWidth(5)
    ctx.addPath(punch); ctx.strokePath()
    ctx.restoreGState()
}

// MARK: The card's edge in the lamp: lit along the top, darker along the bottom.
onTheTable {
    ctx.saveGState()
    ctx.addPath(shape); ctx.clip()
    ctx.setStrokeColor(p3(0xFFFFFF, 0.6)); ctx.setLineWidth(3)
    ctx.move(to: CGPoint(x: -w / 2 + 10, y: h / 2 - 1)); ctx.addLine(to: CGPoint(x: w / 2 - corner, y: h / 2 - 1)); ctx.strokePath()
    ctx.setStrokeColor(p3(0x6B5A44, 0.35)); ctx.setLineWidth(3)
    ctx.move(to: CGPoint(x: -w / 2 + 10, y: -h / 2 + 1)); ctx.addLine(to: CGPoint(x: w / 2 - corner, y: -h / 2 + 1)); ctx.strokePath()
    ctx.restoreGState()
}

guard let image = ctx.makeImage() else { exit(1) }
let rep = NSBitmapImageRep(cgImage: image)
guard let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
