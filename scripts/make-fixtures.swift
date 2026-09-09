#!/usr/bin/env swift
// Draws synthetic ticket stubs as PNGs so the simulator has something honest to read.
// Usage: swift scripts/make-fixtures.swift fixtures/ [index ...]
// Day 0: four clean stubs. Day 3: four harder ones (rotated, low contrast, thermal receipt, European).
import Foundation
import AppKit

enum Layout { case classic, receipt }

struct Ticket {
    let venue: String; let film: String; let when: String; let screen: String; let seat: String; let price: String; let ref: String
    let paper: NSColor; let rotation: CGFloat
    var ink = NSColor(calibratedRed: 0.12, green: 0.12, blue: 0.13, alpha: 1)
    var layout = Layout.classic
    /// Extra lines, receipt style only: printed between the venue and the film.
    var extra: [String] = []
    var slug: String? = nil
}

let tickets: [Ticket] = [
    Ticket(venue: "EMBASSY THEATRE", film: "THE BRUTALIST", when: "Sat 6 Sep 2026 7:30PM", screen: "SCREEN 1", seat: "SEAT H12", price: "ADULT $18.50", ref: "Booking ref 8X2K9", paper: NSColor(calibratedRed: 0.96, green: 0.93, blue: 0.86, alpha: 1), rotation: -2),
    Ticket(venue: "LIGHTHOUSE CINEMA CUBA", film: "PERFECT DAYS", when: "12/03/2024 18:15", screen: "CINEMA 3", seat: "F7", price: "$15.00", ref: "Trans 0091823", paper: NSColor(calibratedRed: 0.92, green: 0.90, blue: 0.84, alpha: 1), rotation: 1.5),
    Ticket(venue: "THE ROXY CINEMA", film: "DUNE PART TWO IMAX", when: "Thu 14 Mar 2024 20:45", screen: "SCR 2", seat: "SEAT D 4", price: "TOTAL $21.00", ref: "ADMIT ONE", paper: NSColor(calibratedRed: 0.97, green: 0.95, blue: 0.90, alpha: 1), rotation: 0.8),
    Ticket(venue: "PENTHOUSE CINEMA", film: "PAST LIVES", when: "Fri 9 Feb 2024 6:00PM", screen: "SCREEN 4", seat: "SEAT K9", price: "STUDENT $14.00", ref: "No refunds", paper: NSColor(calibratedRed: 0.94, green: 0.91, blue: 0.85, alpha: 1), rotation: -1),
    // Day 3. Harder on purpose.
    // 5: rotated well past anything a hand would do by accident.
    Ticket(venue: "EVENT CINEMAS QUEEN ST", film: "NO OTHER LAND", when: "Tue 4 Mar 2025 6:45PM", screen: "SCREEN 7", seat: "SEAT J14", price: "ADULT $22.00", ref: "Order 7781-AB", paper: NSColor(calibratedRed: 0.95, green: 0.92, blue: 0.86, alpha: 1), rotation: 12, slug: "rotated"),
    // 6: low contrast. Pale ink on greyed paper, the paper not far from the table.
    Ticket(venue: "RIALTO CINEMAS NEWMARKET", film: "AFTERSUN", when: "Sun 2 Jun 2024 4:15PM", screen: "SCREEN 3", seat: "SEAT E11", price: "ADULT $19.50", ref: "Booking 55ZQ1", paper: NSColor(calibratedRed: 0.62, green: 0.60, blue: 0.56, alpha: 1), rotation: -1.2, ink: NSColor(calibratedWhite: 0.42, alpha: 1), slug: "low-contrast"),
    // 7: thermal receipt. Narrow, portrait, everything in the same mono, an address line to trip the title.
    Ticket(venue: "ACADEMY CINEMAS", film: "ANORA", when: "Wed 19 Feb 2025 8:15PM", screen: "CINEMA 2", seat: "SEAT C8", price: "ADULT        $19.00", ref: "TRANS 004512", paper: NSColor(calibratedWhite: 0.97, alpha: 1), rotation: 0.6, ink: NSColor(calibratedWhite: 0.22, alpha: 1), layout: .receipt, extra: ["44 LORNE ST AUCKLAND", "--------------------"], slug: "thermal"),
    // 8: European. Accents in the venue, dotted date, French seat words, trailing euro with a comma.
    Ticket(venue: "CINÉMA DU PANTHÉON", film: "LA CHIMERA", when: "24.03.2024 20:30", screen: "SALLE 2", seat: "RANG F PLACE 12", price: "TARIF PLEIN 12,50 €", ref: "Billet n° 4471", paper: NSColor(calibratedRed: 0.93, green: 0.88, blue: 0.78, alpha: 1), rotation: -2.5, slug: "european"),
]

let args = Array(CommandLine.arguments.dropFirst())
let outDir = args.first ?? "fixtures"
let only = Set(args.dropFirst().compactMap { Int($0) })
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
    let w: CGFloat = t.layout == .receipt ? 380 : 980
    let h: CGFloat = t.layout == .receipt ? 620 : 420
    let rect = CGRect(x: -w/2, y: -h/2, width: w, height: h)
    ctx.setShadow(offset: CGSize(width: 6, height: -8), blur: 18, color: NSColor.black.withAlphaComponent(0.5).cgColor)
    t.paper.setFill()
    NSBezierPath(roundedRect: rect, xRadius: t.layout == .receipt ? 2 : 8, yRadius: t.layout == .receipt ? 2 : 8).fill()
    ctx.setShadow(offset: .zero, blur: 0, color: nil)
    func text(_ s: String, _ pt: CGFloat, _ x: CGFloat, _ yy: CGFloat, bold: Bool = false, mono: Bool = false) {
        let font = mono ? NSFont.monospacedSystemFont(ofSize: pt, weight: .regular) : (bold ? NSFont.boldSystemFont(ofSize: pt) : NSFont.systemFont(ofSize: pt))
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: t.ink]
        NSAttributedString(string: s, attributes: attrs).draw(at: NSPoint(x: rect.minX + x, y: rect.maxY - yy))
    }
    switch t.layout {
    case .classic:
        // Perforation
        NSColor(calibratedWhite: 0.25, alpha: 1).setFill()
        let px = rect.maxX - 180
        var y = rect.minY + 14
        while y < rect.maxY { ctx.fillEllipse(in: CGRect(x: px - 4, y: y, width: 8, height: 8)); y += 22 }
        text(t.venue, 26, 40, 60, mono: true)
        text(t.film, 54, 40, 140, bold: true)
        text(t.when, 28, 40, 200, mono: true)
        text(t.screen, 28, 40, 250, mono: true)
        text(t.seat, 28, 340, 250, mono: true)
        text(t.price, 28, 40, 300, mono: true)
        text(t.ref, 20, 40, 350, mono: true)
        text("ADMIT", 22, w - 150, 120, mono: true)
        text("ONE", 22, w - 150, 150, mono: true)
        text(t.seat.replacingOccurrences(of: "SEAT ", with: "").replacingOccurrences(of: "RANG ", with: "").replacingOccurrences(of: " PLACE ", with: ""), 30, w - 150, 260, mono: true)
    case .receipt:
        // One mono, one size, left margin, the way a thermal printer does it. A torn bottom edge.
        var y: CGFloat = 50
        let lines = [t.venue] + t.extra + [t.film, t.when, "\(t.screen)   \(t.seat)", t.price, "GST INCL      $2.48", "TOTAL        $19.00", t.ref, "ADMIT ONE"]
        for line in lines { text(line, 22, 24, y, mono: true); y += 44 }
        NSColor(calibratedRed: 0.22, green: 0.20, blue: 0.18, alpha: 1).setFill()
        var x = rect.minX
        while x < rect.maxX {
            let tooth = NSBezierPath()
            tooth.move(to: NSPoint(x: x, y: rect.minY - 1)); tooth.line(to: NSPoint(x: x + 12, y: rect.minY + 10)); tooth.line(to: NSPoint(x: x + 24, y: rect.minY - 1)); tooth.close(); tooth.fill()
            x += 24
        }
    }
    ctx.restoreGState()
    image.unlockFocus()
    guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) else { return }
    let slug = t.slug ?? t.film.lowercased().replacingOccurrences(of: " ", with: "-")
    let name = "\(outDir)/stub-\(index + 1)-\(slug).png"
    try? png.write(to: URL(fileURLWithPath: name))
    print("wrote \(name)")
}

for (i, t) in tickets.enumerated() where only.isEmpty || only.contains(i + 1) { draw(t, index: i) }
