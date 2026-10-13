#!/usr/bin/env swift
// Draws the tickets that never had paper (BEDIP-218): a PDF e-ticket, a screenshot of a ticket in an exhibitor's app, and
// three Wallet passes in three shapes. All synthetic and all invented in their details, so they can live in a public repo;
// the passes follow Apple's pass format (pass.json, its images, a manifest), unsigned, which is all Stub reads. Real passes,
// redacted, are for Bruno to add beside them (docs/device.md §3.12).
// Usage: swift scripts/make-digital.swift   (writes into fixtures/ and Stub/Resources/Fixtures/)
import Foundation
import AppKit
import CoreImage

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let fixtures = root.appending(path: "fixtures")
let bundled = root.appending(path: "Stub/Resources/Fixtures")
let passes = fixtures.appending(path: "passes")
try? FileManager.default.createDirectory(at: passes, withIntermediateDirectories: true)

func colour(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

func text(_ s: String, at p: CGPoint, size: CGFloat, weight: NSFont.Weight = .regular, mono: Bool = false, colour c: NSColor = colour(0x1A1A1A)) {
    let font = mono ? NSFont.monospacedSystemFont(ofSize: size, weight: weight) : NSFont.systemFont(ofSize: size, weight: weight)
    NSAttributedString(string: s, attributes: [.font: font, .foregroundColor: c]).draw(at: p)
}

/// A QR code for `message`, as a booking system would print one: it stands for the code a door scanner reads.
func qr(_ message: String, side: CGFloat) -> CGImage? {
    guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
    filter.setValue(Data(message.utf8), forKey: "inputMessage")
    filter.setValue("M", forKey: "inputCorrectionLevel")
    guard let output = filter.outputImage else { return nil }
    let scale = side / output.extent.width
    return CIContext().createCGImage(output.transformed(by: CGAffineTransform(scaleX: scale, y: scale)), from: CGRect(x: 0, y: 0, width: side, height: side))
}

/// A PNG exactly `width` by `height` pixels, whatever the Mac's screen: a screenshot and a pass's images have sizes of their own.
func bitmap(width: Int, height: Int, _ draw: (CGContext) -> Void) -> Data? {
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4,
                                     hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
          let context = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    draw(context.cgContext)
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

// MARK: 10. A PDF e-ticket: A4, the ticket in a box at the top, terms below, as a booking system emails one.

func eticket() throws {
    let url = fixtures.appending(path: "stub-10-eticket.pdf")
    var box = CGRect(x: 0, y: 0, width: 595, height: 842)
    guard let ctx = CGContext(url as CFURL, mediaBox: &box, nil) else { return }
    ctx.beginPDFPage(nil)
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    text("LIGHTHOUSE CINEMA PETONE", at: CGPoint(x: 48, y: 776), size: 13, weight: .semibold, colour: colour(0x444444))
    text("Your e-ticket", at: CGPoint(x: 48, y: 744), size: 22, weight: .regular)
    // The ticket.
    ctx.setStrokeColor(colour(0x222222).cgColor); ctx.setLineWidth(1.2)
    ctx.stroke(CGRect(x: 48, y: 470, width: 499, height: 250))
    text("ALL WE IMAGINE AS LIGHT", at: CGPoint(x: 68, y: 678), size: 24, weight: .bold)
    text("Friday 11 April 2025, 7:00 pm", at: CGPoint(x: 68, y: 640), size: 15)
    text("Cinema 1", at: CGPoint(x: 68, y: 612), size: 15)
    text("Seat D9", at: CGPoint(x: 220, y: 612), size: 15)
    text("Adult  $18.00", at: CGPoint(x: 68, y: 584), size: 15)
    text("Booking LH-20871", at: CGPoint(x: 68, y: 500), size: 12, mono: true, colour: colour(0x555555))
    if let code = qr("LH-20871-D9", side: 150) { ctx.draw(code, in: CGRect(x: 380, y: 520, width: 150, height: 150)) }
    // The small print.
    let terms = ["Please arrive 10 minutes before the session.", "This ticket admits one. Show it on your phone or printed.",
                 "Lighthouse Cinema, 52 Beach Street, Petone.", "Refunds up to two hours before the session."]
    for (i, line) in terms.enumerated() { text(line, at: CGPoint(x: 48, y: 420 - CGFloat(i) * 18), size: 10, colour: colour(0x666666)) }
    NSGraphicsContext.current = nil
    ctx.endPDFPage()
    ctx.closePDF()
    try? FileManager.default.removeItem(at: bundled.appending(path: url.lastPathComponent))
    try FileManager.default.copyItem(at: url, to: bundled.appending(path: url.lastPathComponent))
    print("wrote \(url.path)")
}

// MARK: 11. A screenshot: a phone's screen, an exhibitor's app showing the ticket, the status bar and all.

func screenshot() throws {
    let size = CGSize(width: 1179, height: 2556)
    let png = bitmap(width: Int(size.width), height: Int(size.height)) { ctx in
        colour(0xF4F4F6).setFill(); ctx.fill(CGRect(origin: .zero, size: size))
        // The status bar and the app's header, as a screenshot carries them.
        text("9:41", at: CGPoint(x: 120, y: size.height - 120), size: 50, weight: .semibold)
        text("My tickets", at: CGPoint(x: 70, y: size.height - 330), size: 92, weight: .bold)
        // The ticket card.
        let card = CGRect(x: 60, y: 760, width: size.width - 120, height: 1340)
        ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 40, color: colour(0x000000, 0.12).cgColor)
        colour(0xFFFFFF).setFill()
        NSBezierPath(roundedRect: card, xRadius: 44, yRadius: 44).fill()
        ctx.setShadow(offset: .zero, blur: 0, color: nil)
        text("ACADEMY CINEMAS", at: CGPoint(x: 120, y: 1990), size: 40, weight: .semibold, colour: colour(0x7A1F2B))
        text("The Room Next Door", at: CGPoint(x: 120, y: 1880), size: 76, weight: .bold)
        text("Sun 26 Jan 2025 · 5:30 pm", at: CGPoint(x: 120, y: 1790), size: 48)
        text("Cinema 1 · Seat G4", at: CGPoint(x: 120, y: 1715), size: 48)
        text("Adult $19.00", at: CGPoint(x: 120, y: 1640), size: 48, colour: colour(0x555555))
        if let code = qr("AC-11823-G4", side: 560) { ctx.draw(code, in: CGRect(x: (size.width - 560) / 2, y: 980, width: 560, height: 560)) }
        text("Booking AC-11823", at: CGPoint(x: 120, y: 860), size: 40, mono: true, colour: colour(0x666666))
        // The home indicator.
        colour(0x111111).setFill()
        NSBezierPath(roundedRect: CGRect(x: (size.width - 420) / 2, y: 26, width: 420, height: 16), xRadius: 8, yRadius: 8).fill()
    }
    guard let png else { return }
    for dir in [fixtures, bundled] { try png.write(to: dir.appending(path: "stub-11-screenshot.png")) }
    print("wrote stub-11-screenshot.png")
}

// MARK: Passes

/// A strip or a background: a field of the colour with a soft light across it and a few bars, as a cinema's pass might
/// carry a still or a pattern. Invented, and abstract on purpose.
func picture(width: Int, height: Int, base: UInt32, accent: UInt32) -> Data? {
    bitmap(width: width, height: height) { ctx in
        NSGradient(starting: colour(base), ending: colour(accent))?.draw(in: CGRect(x: 0, y: 0, width: width, height: height), angle: 20)
        colour(0xFFFFFF, 0.12).setFill()
        for i in 0..<6 { ctx.fill(CGRect(x: CGFloat(i) * CGFloat(width) / 6 + 8, y: 0, width: CGFloat(width) / 18, height: CGFloat(height))) }
    }
}

func pass(named name: String, json: [String: Any], images: [String: Data]) throws {
    let dir = FileManager.default.temporaryDirectory.appending(path: "stub-pass-\(name)")
    try? FileManager.default.removeItem(at: dir)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let body = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
    try body.write(to: dir.appending(path: "pass.json"))
    for (file, data) in images { try data.write(to: dir.appending(path: file)) }
    // The manifest a real pass carries (SHA-1 of every file). There is no signature: Stub does not check one.
    var manifest: [String: String] = [:]
    for file in try FileManager.default.contentsOfDirectory(atPath: dir.path) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/shasum")
        task.arguments = ["-a", "1", dir.appending(path: file).path]
        let pipe = Pipe(); task.standardOutput = pipe
        try task.run(); task.waitUntilExit()
        let out = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        manifest[file] = String(out.prefix(40))
    }
    try JSONSerialization.data(withJSONObject: manifest, options: [.sortedKeys]).write(to: dir.appending(path: "manifest.json"))
    let out = passes.appending(path: "\(name).pkpass")
    try? FileManager.default.removeItem(at: out)
    let zip = Process()
    zip.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
    zip.currentDirectoryURL = dir
    zip.arguments = ["-q", "-X", "-r", out.path, "."]
    try zip.run(); zip.waitUntilExit()
    print("wrote \(out.path)")
}

let icon = picture(width: 29, height: 29, base: 0x222222, accent: 0x444444)!

/// 1. A modern pass, every fact in PassKit's semantic tags as well as in the fields a person sees.
func semantic() throws {
    let start = "2025-01-30T18:40:00+13:00"
    try pass(named: "semantic-event", json: [
        "formatVersion": 1, "passTypeIdentifier": "pass.example.cinema", "serialNumber": "EV-55031274", "teamIdentifier": "EXAMPLE000",
        "organizationName": "Event Cinemas", "description": "Movie ticket for Conclave",
        "relevantDate": start,
        "semantics": [
            "eventType": "PKEventTypeMovie", "eventName": "Conclave", "venueName": "Event Cinemas Queen St", "venueRoom": "Cinema 5",
            "eventStartDate": start, "seats": [["seatRow": "H", "seatNumber": "12"]],
            "totalPrice": ["amount": "21.50", "currencyCode": "NZD"],
        ],
        "eventTicket": [
            "primaryFields": [["key": "event", "label": "MOVIE", "value": "Conclave"]],
            "secondaryFields": [["key": "session", "label": "SESSION", "value": start, "dateStyle": "PKDateStyleMedium", "timeStyle": "PKDateStyleShort"]],
            "auxiliaryFields": [["key": "seat", "label": "SEAT", "value": "H12"], ["key": "cinema", "label": "CINEMA", "value": "5"]],
            "backFields": [["key": "terms", "label": "Terms", "value": "Admits one. Not transferable."]],
        ],
        "barcodes": [["format": "PKBarcodeFormatQR", "message": "EV-55031274", "messageEncoding": "iso-8859-1"]],
    ], images: ["icon.png": icon, "strip.png": picture(width: 375, height: 123, base: 0x5A1414, accent: 0xC4391D)!,
                "strip@2x.png": picture(width: 750, height: 246, base: 0x5A1414, accent: 0xC4391D)!])
}

/// 2. An older pass: no semantic tags, the facts only in labelled fields, the row and the seat apart, the cinema on the back.
func fields() throws {
    let session = "2025-03-08T20:15:00+13:00"
    try pass(named: "fields-only", json: [
        "formatVersion": 1, "passTypeIdentifier": "pass.example.tickets", "serialNumber": "HY-7781203", "teamIdentifier": "EXAMPLE000",
        "organizationName": "HOYTS", "description": "Cinema ticket",
        "eventTicket": [
            "headerFields": [["key": "admit", "label": "ADMIT", "value": "1"]],
            "primaryFields": [["key": "movie", "label": "FILM", "value": "Mickey 17"]],
            "secondaryFields": [["key": "session", "label": "SESSION", "value": session, "dateStyle": "PKDateStyleMedium", "timeStyle": "PKDateStyleShort"]],
            "auxiliaryFields": [["key": "screen", "label": "CINEMA", "value": "Cinema 4"], ["key": "row", "label": "ROW", "value": "F"],
                                ["key": "seat", "label": "SEAT", "value": "7"]],
            "backFields": [["key": "location", "label": "Location", "value": "Hoyts Sylvia Park"],
                           ["key": "booking", "label": "Booking number", "value": "HY-7781203"]],
        ],
        "barcodes": [["format": "PKBarcodeFormatQR", "message": "HY-7781203", "messageEncoding": "iso-8859-1"]],
    ], images: ["icon.png": icon, "background.png": picture(width: 180, height: 220, base: 0x1B2D4F, accent: 0x3A5A8C)!])
}

/// 3. A pass in French, its session a string a person reads rather than a date a phone can, the time only in relevantDate.
func french() throws {
    try pass(named: "french-strings", json: [
        "formatVersion": 1, "passTypeIdentifier": "pass.example.billets", "serialNumber": "CH-30915", "teamIdentifier": "EXAMPLE000",
        "organizationName": "Cinéma Le Champo", "description": "Billet de cinéma",
        "relevantDate": "2024-11-09T20:30:00+01:00",
        "eventTicket": [
            "primaryFields": [["key": "film", "label": "FILM", "value": "Anatomie d'une chute"]],
            "secondaryFields": [["key": "seance", "label": "SÉANCE", "value": "sam. 9 nov. 20:30"]],
            "auxiliaryFields": [["key": "salle", "label": "SALLE", "value": "Salle 2"], ["key": "place", "label": "PLACE", "value": "K14"],
                                ["key": "tarif", "label": "TARIF", "value": 9.5, "currencyCode": "EUR"]],
        ],
    ], images: ["icon.png": icon, "thumbnail.png": picture(width: 90, height: 90, base: 0x2F2A24, accent: 0xD4622B)!])
}

try eticket()
try screenshot()
try semantic()
try fields()
try french()
