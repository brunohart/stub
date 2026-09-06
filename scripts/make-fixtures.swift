#!/usr/bin/env swift
// Draws synthetic ticket stubs as PNGs so the simulator has something honest to read.
// Usage: swift scripts/make-fixtures.swift fixtures/
import Foundation
import AppKit

struct Ticket {
    let venue: String; let film: String; let when: String; let screen: String; let seat: String; let price: String; let ref: String
    let paper: NSColor; let rotation: CGFloat
}

let tickets: [Ticket] = [
    Ticket(venue: "EMBASSY THEATRE", film: "THE BRUTALIST", when: "Sat 6 Sep 2026 7:30PM", screen: "SCREEN 1", seat: "SEAT H12", price: "ADULT $18.50", ref: "Booking ref 8X2K9", paper: NSColor(calibratedRed: 0.96, green: 0.93, blue: 0.86, alpha: 1), rotation: -2),
    Ticket(venue: "LIGHTHOUSE CINEMA CUBA", film: "PERFECT DAYS", when: "12/03/2024 18:15", screen: "CINEMA 3", seat: "F7", price: "$15.00", ref: "Trans 0091823", paper: NSColor(calibratedRed: 0.92, green: 0.90, blue: 0.84, alpha: 1), rotation: 1.5),
    Ticket(venue: "THE ROXY CINEMA", film: "DUNE PART TWO IMAX", when: "Thu 14 Mar 2024 20:45", screen: "SCR 2", seat: "SEAT D 4", price: "TOTAL $21.00", ref: "ADMIT ONE", paper: NSColor(calibratedRed: 0.97, green: 0.95, blue: 0.90, alpha: 1), rotation: 0.8),
    Ticket(venue: "PENTHOUSE CINEMA", film: "PAST LIVES", when: "Fri 9 Feb 2024 6:00PM", screen: "SCREEN 4", seat: "SEAT K9", price: "STUDENT $14.00", ref: "No refunds", paper: NSColor(calibratedRed: 0.94, green: 0.91, blue: 0.85, alpha: 1), rotation: -1),
]

let outDir = CommandLine.arguments.dropFirst().first ?? "fixtures"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func draw(_ t: Ticket, index: Int) {
    let size = NSSize(width: 1200, height: 700)
    let image = NSImage(size: size)
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else { return }
    // Table
    NSColor(calibratedRed: 0.22, green: 0.20, blue: 0.18, alpha: 1).setFill()
    ctx.fill(CGRect(origin: .zero, size: size))
    // Stub
    ctx.saveGState()
    ctx.translateBy(x: size.width/2, y: size.height/2)
    ctx.rotate(by: t.rotation * .pi / 180)
    let w: CGFloat = 980, h: CGFloat = 420
    let rect = CGRect(x: -w/2, y: -h/2, width: w, height: h)
    ctx.setShadow(offset: CGSize(width: 6, height: -8), blur: 18, color: NSColor.black.withAlphaComponent(0.5).cgColor)
    t.paper.setFill()
    NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8).fill()
    ctx.setShadow(offset: .zero, blur: 0, color: nil)
    // Perforation
    NSColor(calibratedWhite: 0.25, alpha: 1).setFill()
    let px = rect.maxX - 180
    var y = rect.minY + 14
    while y < rect.maxY { ctx.fillEllipse(in: CGRect(x: px - 4, y: y, width: 8, height: 8)); y += 22 }
    // Text
    let ink = NSColor(calibratedRed: 0.12, green: 0.12, blue: 0.13, alpha: 1)
    func text(_ s: String, _ pt: CGFloat, _ x: CGFloat, _ yy: CGFloat, bold: Bool = false, mono: Bool = false) {
        let font = mono ? NSFont.monospacedSystemFont(ofSize: pt, weight: .regular) : (bold ? NSFont.boldSystemFont(ofSize: pt) : NSFont.systemFont(ofSize: pt))
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: ink]
        NSAttributedString(string: s, attributes: attrs).draw(at: NSPoint(x: rect.minX + x, y: rect.maxY - yy))
    }
    text(t.venue, 26, 40, 60, mono: true)
    text(t.film, 54, 40, 140, bold: true)
    text(t.when, 28, 40, 200, mono: true)
    text(t.screen, 28, 40, 250, mono: true)
    text(t.seat, 28, 340, 250, mono: true)
    text(t.price, 28, 40, 300, mono: true)
    text(t.ref, 20, 40, 350, mono: true)
    text("ADMIT", 22, w - 150, 120, mono: true)
    text("ONE", 22, w - 150, 150, mono: true)
    text(t.seat.replacingOccurrences(of: "SEAT ", with: ""), 30, w - 150, 260, mono: true)
    ctx.restoreGState()
    image.unlockFocus()
    guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) else { return }
    let name = "\(outDir)/stub-\(index + 1)-\(t.film.lowercased().replacingOccurrences(of: " ", with: "-")).png"
    try? png.write(to: URL(fileURLWithPath: name))
    print("wrote \(name)")
}

for (i, t) in tickets.enumerated() { draw(t, index: i) }
