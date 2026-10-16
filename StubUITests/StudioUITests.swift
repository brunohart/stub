import XCTest

/// The press's studio by touch (ADR-046): Overprint opens on one tap, a tap on the card pulls a pass, a drag pulls
/// another, and Stamp presses a stamp. Each act is seen by the line over the card saying the proof is not kept yet,
/// and by "Take it off" coming alive.
@MainActor
final class StudioUITests: XCTestCase {
    func testOverprintAndStampByTouch() {
        let app = XCUIApplication()
        app.launchArguments = ["-stage-drawer", "12", "-stage-rules", "-edition", "-press"]
        app.launch()

        let overprint = app.buttons["Overprint"]
        XCTAssertTrue(overprint.waitForExistence(timeout: 30))
        // The card on the bed, found by the label every edition's front carries in the press.
        let card = app.otherElements.matching(NSPredicate(format: "label BEGINSWITH 'The card on the press'")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10))

        overprint.tap()
        let takeItOff = app.buttons["Take it off"]
        XCTAssertTrue(takeItOff.waitForExistence(timeout: 5), "one tap on Overprint opens the screens")
        XCTAssertFalse(takeItOff.isEnabled, "nothing on the card yet")

        // A tap on the card pulls a pass straight across it.
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4)).tap()
        XCTAssertTrue(app.staticTexts["Not kept yet"].waitForExistence(timeout: 5), "a tap overprints")
        XCTAssertTrue(takeItOff.isEnabled)

        // A drag pulls another, down and across, the way a thumb pulls.
        let from = card.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.2))
        let to = card.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.55))
        from.press(forDuration: 0.05, thenDragTo: to)
        // Put down, the line counts what is on the card.
        app.buttons["Done"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["2 on it now. Keep going, or keep it."].waitForExistence(timeout: 5),
                      "a tap and a drag: two passes")

        // The stamps: one tap opens them, a tap on the card presses one.
        let stamp = app.buttons["Stamp"]
        XCTAssertTrue(stamp.waitForExistence(timeout: 5))
        stamp.tap()
        XCTAssertTrue(app.descendants(matching: .any)["Tap the card where it goes."].waitForExistence(timeout: 5),
                      "one tap on Stamp opens the stamps")
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.2)).tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["3 on it now. Keep going, or keep it."].waitForExistence(timeout: 5), "a tap stamps")

        // The stocks: the swatch book on a rail, every finish a tap away (ADR-047).
        let stock = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Stock,'")).firstMatch
        XCTAssertTrue(stock.waitForExistence(timeout: 5))
        stock.tap()
        let pearl = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Pearl card.'")).firstMatch
        XCTAssertTrue(pearl.waitForExistence(timeout: 5), "the pearl finish is on the rail")
        for _ in 0..<3 where !pearl.isHittable { app.swipeLeft(velocity: .slow) }
        pearl.tap()
        XCTAssertTrue(app.buttons["Stock, Pearl card"].waitForExistence(timeout: 8), "one tap prints on pearl card")
    }
}
