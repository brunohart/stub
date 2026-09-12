#!/usr/bin/env swift
// Draws the app icon: parchment, one orange stub silhouette printed a little out of register, nothing else.
// Usage: swift scripts/make-icon.swift [out.png]   (default Stub/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png)
// The icon is generated, like the fixtures (ADR-003) and the project (ADR-004): the source is this file.
import Foundation
import AppKit

let out = CommandLine.arguments.dropFirst().first ?? "Stub/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
let side: CGFloat = 1024

// The inks, from DESIGN.md. The icon is drawn in Display P3 so the orange is the app's orange.
func ink(_ hex: UInt32) -> NSColor {
    NSColor(displayP3Red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}
let paper = ink(0xF0EDE6)
let orange = ink(0xD4622B)
let inkBlack = ink(0x1A1A1A)

// An app icon may not carry an alpha channel, so draw straight into an opaque RGB bitmap.
guard let ctx = CGContext(data: nil, width: Int(side), height: Int(side), bitsPerComponent: 8, bytesPerRow: 0,
                          space: CGColorSpace(name: CGColorSpace.displayP3)!,
                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { exit(1) }

// Parchment, with grain. The grain is the only grit; the silhouette is a flat plate.
ctx.setFillColor(paper.cgColor)
ctx.fill(CGRect(x: 0, y: 0, width: side, height: side))
srand48(6)
ctx.setBlendMode(.multiply)
for _ in 0..<26000 {
    let x = CGFloat(drand48()) * side, y = CGFloat(drand48()) * side
    let a = 0.02 + CGFloat(drand48()) * 0.05
    ctx.setFillColor(NSColor(calibratedWhite: 0.2, alpha: a).cgColor)
    ctx.fill(CGRect(x: x, y: y, width: 2.5, height: 2.5))
}
ctx.setBlendMode(.normal)

/// A ticket stub: a landscape rectangle with a semicircular notch bitten out of each short side, and a
/// perforation line a third of the way in. Drawn about the origin, so it can be tilted.
func stub(in ctx: CGContext, width w: CGFloat, height h: CGFloat, notch r: CGFloat) -> CGPath {
    let path = CGMutablePath()
    let rect = CGRect(x: -w / 2, y: -h / 2, width: w, height: h)
    path.addRoundedRect(in: rect, cornerWidth: 22, cornerHeight: 22)
    // Filled with even-odd inside a clip to the card, so the notches are bitten out and nothing spills past the edge.
    // The notches are cut with even-odd fill: two circles centred on the short edges.
    path.addEllipse(in: CGRect(x: rect.minX - r, y: -r, width: 2 * r, height: 2 * r))
    path.addEllipse(in: CGRect(x: rect.maxX - r, y: -r, width: 2 * r, height: 2 * r))
    return path
}

let w: CGFloat = 640, h: CGFloat = 340, notch: CGFloat = 46
let tilt: CGFloat = -4 * .pi / 180
let plate = stub(in: ctx, width: w, height: h, notch: notch)
let card = CGPath(roundedRect: CGRect(x: -w / 2, y: -h / 2, width: w, height: h), cornerWidth: 22, cornerHeight: 22, transform: nil)

// The misregistered pass: the same plate, offset a few points, in the ink, faint. One colour pass that did
// not line up (DisplayTitle does the same to the wordmark).
ctx.saveGState()
ctx.translateBy(x: side / 2 + 14, y: side / 2 - 12)
ctx.rotate(by: tilt)
ctx.addPath(card); ctx.clip()
ctx.addPath(plate)
ctx.setFillColor(inkBlack.withAlphaComponent(0.16).cgColor)
ctx.setBlendMode(.multiply)
ctx.fillPath(using: .evenOdd)
ctx.restoreGState()

// The orange plate, in register with itself, tilted like every stub on the table.
ctx.saveGState()
ctx.translateBy(x: side / 2, y: side / 2)
ctx.rotate(by: tilt)
ctx.addPath(card); ctx.clip()
ctx.addPath(plate)
ctx.setFillColor(orange.cgColor)
ctx.setBlendMode(.multiply)
ctx.fillPath(using: .evenOdd)
// The perforation: a dotted line a third of the way in, punched through to the paper.
ctx.setBlendMode(.normal)
ctx.setFillColor(paper.cgColor)
let px = -w / 2 + w / 3
var y = -h / 2 + 34
while y < h / 2 - 20 {
    ctx.fillEllipse(in: CGRect(x: px - 7, y: y, width: 14, height: 14))
    y += 30
}
ctx.restoreGState()

guard let cg = ctx.makeImage(),
      let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else { exit(1) }
try! png.write(to: URL(fileURLWithPath: out))
print("wrote \(out) \(Int(side))×\(Int(side))")
