import XCTest
import UIKit
import Vision

/// The accessibility audit (docs/decisions/005-accessibility.md): every screen a common task passes through, audited with
/// Apple's `performAccessibilityAudit` at the default text size and at the largest accessibility size; `scripts/a11y.sh`
/// runs the suite again with Increase Contrast on. An audit checks what is on screen, not whether a task can be done with
/// VoiceOver alone: that is the VoiceOver run in docs/proof/voiceover.md.
///
/// Every issue is collected, then judged, and each verdict is printed: `A11Y:` fails the run, `A11Y-OK:` says why it does
/// not. Six kinds are settled by evidence rather than by Apple's verdict alone, as Apple's session on audits shows
/// (WWDC23 10035), and narrowly, by the kind of issue and the element:
/// - **Printed artwork** (`artwork`): the type on an edition or a ticket's photograph is part of a picture. VoiceOver never
///   reaches it (the card's label says what it shows), and WCAG's contrast rule exempts text in a picture.
/// - **Contrast**, measured: Apple's check failed ink at 14:1 inside a sheet and passed a grey at 3.2:1 on its own (the
///   `-a11y-lab` runs, 2026-10-16), so every element it flags is measured on the screen, WCAG's way, and fails under 4.5:1.
/// - **Dynamic Type**, measured: a label flagged as not scaling must be at least 1.4 times as tall at the largest
///   accessibility size as at the default. A navigation bar's own buttons keep their size and show the Large Content
///   Viewer when held, by Apple's design.
/// - **Text found in the pixels** with no element named: the screen is read with Vision, and every word it finds must be
///   an element's words, on a picture (`artwork`: an edition, a ticket's photograph, the camera), or behind a half-height
///   sheet (`sheet`), where it is dimmed and nothing can be touched. One word that is none of these fails the run.
/// - **Text clipped**, read: Vision reads the flagged element where it is drawn, and every letter of its words must be
///   there. A word cut short or run off the screen fails; type whose ascenders rise past their line box does not.
/// - **Contrast with no element**: on a slower machine (GitHub's) the audit can lose the element it means. Then every
///   word on the screen is measured instead, a superset of whatever it meant, and every one must reach 4.5:1.
/// - **Hit area with no element**: every control on the screen is measured, and each must be 44 points or more.
/// - **Under the doors**: the drawer scrolls under its two doors (`bar`), fading as it goes; a caption caught there when
///   the audit looks is low in contrast by design, and is read at full ink a scroll later. The doors' own words are measured.
@MainActor
final class AccessibilityTests: XCTestCase {
    /// The text sizes every screen is audited at: the person's default, and the largest accessibility size.
    private static let largest = "UICTContentSizeCategoryAccessibilityXXXL"

    /// What a finger acts on: the elements a hit area is about.
    private static let controlTypes: Set<XCUIElement.ElementType> = [
        .button, .link, .switch, .toggle, .slider, .stepper, .textField, .secureTextField, .searchField, .menuButton,
    ]

    private struct Found {
        let size: String
        let type: XCUIAccessibilityAuditType
        let summary: String
        let detail: String
        let label: String?
        let identifier: String?
        let elementType: XCUIElement.ElementType?
        let frame: CGRect?
        let inBar: Bool
        /// Content passing under the drawer's doors, where the drawer fades on purpose as it scrolls.
        let underDoors: Bool
        let contrast: Double?
        /// For text the audit thinks is cut: what Vision reads in and just around its frame.
        let legible: String?
        /// For text found in the pixels: the words on screen that are no element's, a picture's or behind the sheet.
        let unread: [String]?
        /// For contrast with no element: every word on the screen under 4.5:1, measured. Empty when all pass.
        let dim: [String]?
        /// For a hit area with no element: every control on the screen smaller than 44 points. Empty when all are whole.
        let small: [String]?
    }

    private func audit(_ screen: String, _ arguments: [String], open: (XCUIApplication) -> Void = { _ in }) throws {
        continueAfterFailure = true
        var found: [Found] = []
        var heights: [String: [String: CGFloat]] = [:]
        for size in ["", Self.largest] {
            let app = XCUIApplication()
            app.launchArguments = arguments + (size.isEmpty ? [] : ["-UIPreferredContentSizeCategoryName", size])
            app.launch()
            open(app)
            var issues: [XCUIAccessibilityAuditIssue] = []
            try app.performAccessibilityAudit { issue in
                issues.append(issue)
                return true
            }
            // The screen as the audit left it: what each flagged element looks like, and how tall every label is.
            let shot = XCUIScreen.main.screenshot().image
            // One snapshot of the tree, not a query per element: the bars' buttons, and every label's height.
            var bars: [CGRect] = []
            var tall: [String: CGFloat] = [:]
            var named: [(frame: CGRect, words: String)] = []
            var pictures: [CGRect] = []
            var sheet: CGRect?
            var doors: CGRect?
            var words: [(frame: CGRect, label: String, picture: Bool)] = []
            var controls: [(frame: CGRect, label: String)] = []
            func walk(_ node: any XCUIElementSnapshot, inBar: Bool) {
                let bar = inBar || node.elementType == .navigationBar
                if bar, node.elementType == .button { bars.append(node.frame) }
                if node.elementType == .staticText, !node.label.isEmpty {
                    tall[node.label] = max(tall[node.label] ?? 0, node.frame.height)
                    words.append((node.frame, node.label, node.identifier == "artwork"))
                }
                // An element's words are its label and its value: a text field's words are what is typed in it.
                for words in [node.label, node.value as? String ?? "", node.placeholderValue ?? ""] where !words.isEmpty {
                    named.append((node.frame, Self.plain(words)))
                }
                if Self.controlTypes.contains(node.elementType) {
                    controls.append((node.frame, node.label))
                }
                if node.identifier == "artwork" { pictures.append(node.frame) }
                if node.identifier == "sheet" { sheet = sheet.map { $0.union(node.frame) } ?? node.frame }
                if node.identifier == "bar" { doors = doors.map { $0.union(node.frame) } ?? node.frame }
                for child in node.children { walk(child, inBar: bar) }
            }
            if let tree = try? app.snapshot() { walk(tree, inBar: false) }
            // The doors' fade begins 44 points above their buttons (`Dock`): the region where the drawer fades on purpose.
            doors = doors.map { CGRect(x: 0, y: $0.minY - 52, width: max($0.maxX, shot.size.width), height: $0.height + 52) }
            // The system's status bar is the phone's, not the app's.
            let statusBar = XCUIApplication(bundleIdentifier: "com.apple.springboard").statusBars.firstMatch
            let system = statusBar.exists ? statusBar.frame : CGRect(x: 0, y: 0, width: shot.size.width, height: 24)
            // The words Vision reads on the screen that nothing accounts for, read once, only if the audit found any.
            let unread: [String]? = issues.contains { $0.auditType == .elementDetection && $0.element == nil }
                ? Self.read(shot).filter { found in
                    let middle = CGPoint(x: found.frame.midX, y: found.frame.midY)
                    if pictures.contains(where: { $0.contains(middle) }) || system.contains(middle) { return false }
                    if let sheet, !sheet.contains(middle) { return false }
                    let words = Self.plain(found.words)
                    // An element's words within a few points, or a field's own label just above it: the visible word a
                    // field is named by. Or a fragment Vision read of an element's words where they are, clipped by an
                    // edge or softened by the scroll edge: it begins as they begin ("Wed.a" over "Wednesdays, three
                    // films", CI 2026-10-17).
                    return !named.contains { element in
                        let near = element.frame.insetBy(dx: -4, dy: -4).union(element.frame.offsetBy(dx: 0, dy: -24))
                        guard near.intersects(found.frame), !element.words.isEmpty else { return false }
                        if element.words.contains(words) || words.contains(element.words) { return true }
                        return words.count >= 3 && words.count < element.words.count
                            && element.words.hasPrefix(String(words.prefix(3)))
                    }
                }.map(\.words)
                : nil
            // Every word on the screen that is interface, measured: the evidence when the audit raises contrast without
            // saying where, and a note of the lowest on every screen either way.
            let screenRect = CGRect(origin: .zero, size: shot.size)
            let measuredWords: [(label: String, ratio: Double, frame: CGRect)] = words.compactMap { word in
                guard !word.picture, word.frame.width >= 4, word.frame.height >= 4, screenRect.contains(word.frame),
                      !system.intersects(word.frame), !(doors?.intersects(word.frame) ?? false),
                      sheet.map({ $0.contains(word.frame) }) ?? true,
                      let ratio = Self.measured(word.frame, in: shot) else { return nil }
                return (word.label, ratio, word.frame)
            }
            if let lowest = measuredWords.min(by: { $0.ratio < $1.ratio }) {
                let at = size.isEmpty ? screen : "\(screen) at AX5"
                print(String(format: "A11Y-WORDS: %@ · %d words measured on screen, the lowest '%@' at %.1f:1", at,
                             measuredWords.count, lowest.label, lowest.ratio))
            }
            let dim: [String]? = issues.contains { $0.auditType == .contrast && $0.element == nil }
                ? measuredWords.filter { $0.ratio < 4.5 }.map {
                    String(format: "'%@' %.1f:1 at %.0f,%.0f %.0f×%.0f", $0.label, $0.ratio, $0.frame.minX, $0.frame.minY, $0.frame.width, $0.frame.height)
                }
                : nil
            // Every control on the screen smaller than Apple's 44 points: the evidence when the audit names none.
            var small: [String]?
            if issues.contains(where: { $0.auditType == .hitRegion && $0.element == nil }) {
                small = []
                for control in controls where screenRect.intersects(control.frame) && !system.intersects(control.frame) {
                    let f = control.frame
                    if f.width < 43.5 || f.height < 43.5 { small?.append("'\(control.label)' \(Int(f.width))×\(Int(f.height))") }
                }
            }
            for issue in issues {
                let element = issue.element
                let frame = element?.frame
                found.append(Found(
                    size: size, type: issue.auditType, summary: issue.compactDescription, detail: issue.detailedDescription,
                    label: element?.label, identifier: element?.identifier, elementType: element?.elementType, frame: frame,
                    inBar: frame.map { f in bars.contains { $0.intersects(f) } } ?? false,
                    underDoors: element?.identifier != "bar" && frame.map { f in doors?.intersects(f) ?? false } ?? false,
                    contrast: issue.auditType == .contrast ? frame.flatMap { Self.measured($0, in: shot) } : nil,
                    legible: issue.auditType == .textClipped ? frame.map { Self.read($0.insetBy(dx: -6, dy: -6), in: shot) } : nil,
                    unread: issue.auditType == .elementDetection && element == nil ? unread : nil,
                    dim: issue.auditType == .contrast && element == nil ? dim : nil,
                    small: issue.auditType == .hitRegion && element == nil ? small : nil))
            }
            // After every issue's evidence is taken from the screen as the audit saw it.
            // At the largest size less of a drawer fits: scroll on and measure what comes into view, so a label seen at the
            // default size can be found here too.
            if size == Self.largest, app.scrollViews.firstMatch.exists {
                for _ in 0..<4 {
                    app.scrollViews.firstMatch.swipeUp(velocity: .slow)
                    guard let more = try? app.snapshot() else { break }
                    func heights(_ node: any XCUIElementSnapshot) {
                        if node.elementType == .staticText, !node.label.isEmpty {
                            tall[node.label] = max(tall[node.label] ?? 0, node.frame.height)
                        }
                        node.children.forEach(heights)
                    }
                    heights(more)
                }
            }
            heights[size] = tall
            app.terminate()
        }
        for issue in found {
            let at = issue.size.isEmpty ? screen : "\(screen) at AX5"
            let what = issue.label.map { "'\($0)'" + (issue.frame.map { f in " at \(Int(f.minX)),\(Int(f.minY)) \(Int(f.width))×\(Int(f.height))" } ?? "") }
                ?? "no element: \(issue.detail)"
            if let reason = settled(issue, heights: heights) {
                print("A11Y-OK: \(at) · \(issue.summary) · \(what) · \(reason)")
            } else {
                let evidence = Self.evidence(issue)
                print("A11Y: \(at) · \(issue.summary) · \(what)\(evidence)")
                XCTFail("\(at): \(issue.summary) · \(what)\(evidence)")
            }
        }
    }

    /// What was measured for an issue that fails, to print beside it.
    private static func evidence(_ issue: Found) -> String {
        if let ratio = issue.contrast { return String(format: " · measured %.1f:1", ratio) }
        if let unread = issue.unread { return " · unaccounted: " + unread.joined(separator: " | ") }
        if let dim = issue.dim { return " · under 4.5:1 on screen: " + dim.joined(separator: ", ") }
        if let small = issue.small { return " · under 44 points: " + small.joined(separator: ", ") }
        return ""
    }

    /// Why an issue does not fail the run, or `nil` if it does.
    private func settled(_ issue: Found, heights: [String: [String: CGFloat]]) -> String? {
        if issue.identifier == "artwork" { return "printed artwork, spoken by its card" }
        if issue.type == .contrast, let ratio = issue.contrast, ratio >= 4.5 {
            return String(format: "measured %.1f:1 on screen", ratio)
        }
        if issue.type == .textClipped, let label = issue.label, let seen = issue.legible,
           !Self.plain(label).isEmpty, Self.plain(seen).contains(Self.plain(label)) {
            return "every word of it is on screen: Vision reads \"\(seen.replacingOccurrences(of: "\n", with: " "))\""
        }
        if issue.type == .hitRegion, let small = issue.small, small.isEmpty {
            return "no element named: every control on the screen is 44 points or more"
        }
        if issue.type == .contrast, let dim = issue.dim, dim.isEmpty {
            return "no element named: every word on the screen measures 4.5:1 or more"
        }
        if issue.type == .contrast, issue.underDoors { return "scrolling under the doors' fade, where it is meant to fade" }
        if issue.type == .elementDetection, let unread = issue.unread, unread.isEmpty {
            return "every word Vision reads is an element's, on a picture, or behind the sheet"
        }
        if issue.type == .dynamicType {
            if issue.inBar, issue.elementType == .button { return "a navigation bar button: the Large Content Viewer" }
            if let label = issue.label, let small = heights[""]?[label], let large = heights[Self.largest]?[label],
               small > 0, large / small >= 1.4 {
                return String(format: "scales: %.0f pt tall at the default, %.0f at AX5", small, large)
            }
        }
        return nil
    }

    /// Letters and digits only, lowercased: how a label and what Vision reads are compared.
    static func plain(_ words: String) -> String {
        String(words.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.map(Character.init))
    }

    /// What Vision reads inside `frame` (in points) on the screen, the lines joined.
    static func read(_ frame: CGRect, in shot: UIImage) -> String {
        guard let cg = shot.cgImage else { return "" }
        let scale = CGFloat(cg.width) / shot.size.width
        let box = CGRect(x: frame.minX * scale, y: frame.minY * scale, width: frame.width * scale, height: frame.height * scale)
            .integral.intersection(CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        guard box.width >= 4, box.height >= 4, let crop = cg.cropping(to: box) else { return "" }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        try? VNImageRequestHandler(cgImage: crop).perform([request])
        return (request.results ?? []).sorted { $0.boundingBox.maxY > $1.boundingBox.maxY }
            .compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
    }

    /// The words on the screen, as Vision reads them, each with where it is in points.
    static func read(_ shot: UIImage) -> [(words: String, frame: CGRect)] {
        guard let cg = shot.cgImage else { return [] }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        try? VNImageRequestHandler(cgImage: cg).perform([request])
        let size = shot.size
        return (request.results ?? []).compactMap { observation in
            guard let best = observation.topCandidates(1).first, best.confidence >= 0.5,
                  !plain(best.string).isEmpty else { return nil }
            let box = observation.boundingBox
            let frame = CGRect(x: box.minX * size.width, y: (1 - box.maxY) * size.height,
                               width: box.width * size.width, height: box.height * size.height)
            return (best.string, frame)
        }
    }

    /// WCAG's contrast ratio of what is drawn in `frame`: the background is the commonest light, the text the darkest
    /// few percent of pixels (or the lightest, for light words on a dark ground), each as relative luminance.
    static func measured(_ frame: CGRect, in shot: UIImage) -> Double? {
        guard let cg = shot.cgImage else { return nil }
        let scale = CGFloat(cg.width) / shot.size.width
        let box = CGRect(x: frame.minX * scale, y: frame.minY * scale, width: frame.width * scale, height: frame.height * scale)
            .integral.intersection(CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        guard box.width >= 2, box.height >= 2, let crop = cg.cropping(to: box) else { return nil }
        let w = crop.width, h = crop.height
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        guard let context = CGContext(data: &pixels, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.draw(crop, in: CGRect(x: 0, y: 0, width: w, height: h))
        func linear(_ v: UInt8) -> Double {
            let c = Double(v) / 255
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        var lums: [Double] = []
        lums.reserveCapacity(w * h)
        for i in stride(from: 0, to: pixels.count, by: 4) {
            lums.append(0.2126 * linear(pixels[i]) + 0.7152 * linear(pixels[i + 1]) + 0.0722 * linear(pixels[i + 2]))
        }
        lums.sort()
        let ground = lums[lums.count * 6 / 10]
        let dark = lums[lums.count * 3 / 100], light = lums[lums.count * 97 / 100]
        let ink = abs(ground - dark) >= abs(light - ground) ? dark : light
        return (max(ground, ink) + 0.05) / (min(ground, ink) + 0.05)
    }

    private func settle(_ app: XCUIApplication, _ seconds: TimeInterval = 3) {
        _ = XCTWaiter().wait(for: [XCTestExpectation(description: "settle")], timeout: seconds)
    }

    /// A staged drawer, its editions printing the fictional stand-in poster (ADR-049) so the key art is audited too.
    private let drawer = ["-stage-drawer", "12", "-stage-rules", "-poster", "poster-orchard.jpg"]

    func testDrawerTickets() throws {
        try audit("the drawer, tickets", drawer + ["-face", "ticket"]) { app in
            XCTAssertTrue(app.scrollViews["drawer.scroll"].waitForExistence(timeout: 30)); settle(app)
        }
    }

    func testDrawerEditions() throws {
        try audit("the drawer, editions", drawer + ["-face", "edition"]) { app in
            XCTAssertTrue(app.scrollViews["drawer.scroll"].waitForExistence(timeout: 30)); settle(app, 4)
        }
    }

    func testEmptyDrawer() throws {
        try audit("the empty drawer", ["-stage-drawer", "0", "-stage-rules"]) { app in settle(app) }
    }

    func testDetail() throws {
        try audit("a stub", drawer + ["-edition"]) { app in settle(app, 6) }
    }

    func testDetailTurned() throws {
        try audit("a stub, turned over", drawer + ["-edition", "-turned"]) { app in settle(app, 6) }
    }

    func testSeason() throws {
        try audit("the season", drawer + ["-season"]) { app in settle(app, 5) }
    }

    func testViewfinder() throws {
        try audit("the viewfinder", drawer + ["-keep", "-camera", "stub-4-past-lives.png"]) { app in settle(app, 6) }
    }

    func testReadForm() throws {
        try audit("the read form", drawer + ["-keep", "-camera", "stub-7-thermal.png", "-shutter"]) { app in
            let keep = app.buttons["import.keep"]
            XCTAssertTrue(keep.waitForExistence(timeout: 30))
            settle(app, 4)
        }
    }

    func testPressRoom() throws {
        try audit("the press", drawer + ["-edition", "-press"]) { app in settle(app, 9) }
    }

    func testYourCard() throws {
        try audit("your card", drawer + ["-card"]) { app in settle(app, 5) }
    }
}
