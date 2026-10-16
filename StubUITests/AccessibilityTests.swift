import XCTest

/// The accessibility audit (docs/decisions/005-accessibility.md): every screen a common task passes through, audited with
/// Apple's `performAccessibilityAudit` at the default text size and at the largest accessibility size. Every issue is
/// printed as an `A11Y:` line, so a run is a list rather than a first failure; `scripts/a11y.sh` also runs the suite
/// with Increase Contrast on. An audit checks what is on screen, not whether a task can be done with VoiceOver alone:
/// that is the VoiceOver run in docs/proof/voiceover.md.
final class AccessibilityTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = true
    }

    /// The text sizes every screen is audited at: the person's default, and the largest accessibility size.
    private let sizes = ["", "UICTContentSizeCategoryAccessibilityXXXL"]

    private func audit(_ screen: String, _ arguments: [String], open: (XCUIApplication) -> Void = { _ in }) throws {
        for size in sizes {
            let app = XCUIApplication()
            app.launchArguments = arguments + (size.isEmpty ? [] : ["-UIPreferredContentSizeCategoryName", size])
            app.launch()
            open(app)
            let label = size.isEmpty ? screen : "\(screen) at AX5"
            try app.performAccessibilityAudit { issue in
                let element = issue.element.map { "\($0.elementType) '\($0.label)'" } ?? "no element"
                print("A11Y: \(label) · \(issue.auditType) · \(issue.compactDescription) · \(element)")
                return false
            }
            app.terminate()
        }
    }

    private func settle(_ app: XCUIApplication, _ seconds: TimeInterval = 3) {
        _ = XCTWaiter().wait(for: [XCTestExpectation(description: "settle")], timeout: seconds)
    }

    private let drawer = ["-stage-drawer", "12", "-stage-rules"]

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
