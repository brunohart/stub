import XCTest

/// The budgets (docs/decisions/004-budgets.md), measured the way Apple's tools measure them, against the Performance
/// configuration (Release's optimiser, the staging hooks compiled in). Every test stages its own drawer, so a run is the
/// same run on any machine. The numbers are read out of the result bundle and judged against `perf/budgets.json` by
/// `scripts/perf.sh`, which fails the build when one is over; Xcode's own baselines live in a project file this repo
/// generates, so they are not where the budgets are kept.
final class PerformanceTests: XCTestCase {
    static let subsystem = "com.designedbybruno.stub"

    override func setUp() {
        continueAfterFailure = false
    }

    private func app(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        return app
    }

    private func options(iterations: Int = 5, manual: Bool = false) -> XCTMeasureOptions {
        let options = XCTMeasureOptions()
        options.iterationCount = iterations
        if manual { options.invocationOptions = [.manuallyStart, .manuallyStop] }
        return options
    }

    /// Wait a fixed time inside a measurement, for work the app does on its own clock.
    private func pause(_ seconds: TimeInterval) {
        _ = XCTWaiter().wait(for: [XCTestExpectation(description: "pause")], timeout: seconds)
    }

    // MARK: Launch

    /// Cold launch to the first frame, Apple's 400 ms (WWDC19 "Optimizing App Launch"), with sixty stubs on the phone.
    func testLaunchFirstFrame() {
        let staging = app(["-stage-drawer", "60", "-stage-rules"])
        staging.launch()
        XCTAssertTrue(staging.scrollViews["drawer.scroll"].waitForExistence(timeout: 30))
        staging.terminate()
        measure(metrics: [XCTApplicationLaunchMetric()], options: options()) {
            app(["-stage-rules"]).launch()
        }
    }

    /// Cold launch to responsive: the first frame and the app ready for a thumb, with sixty stubs on the phone.
    func testLaunch() {
        let staging = app(["-stage-drawer", "60", "-stage-rules"])
        staging.launch()
        XCTAssertTrue(staging.scrollViews["drawer.scroll"].waitForExistence(timeout: 30))
        staging.terminate()
        measure(metrics: [XCTApplicationLaunchMetric(waitUntilResponsive: true)], options: options()) {
            app(["-stage-rules"]).launch()
        }
    }

    // MARK: The drawer scroll

    /// A fast fling down a drawer of sixty tickets, and its deceleration: the hitch time ratio of the archive.
    func testDrawerScrollTickets() { scroll(face: "ticket") }

    /// The same fling with the drawer showing editions, the heavier face: shaders on every card.
    func testDrawerScrollEditions() { scroll(face: "edition") }

    private func scroll(face: String) {
        let app = app(["-stage-drawer", "60", "-stage-rules", "-face", face])
        app.launch()
        let drawer = app.scrollViews["drawer.scroll"]
        XCTAssertTrue(drawer.waitForExistence(timeout: 30))
        pause(3) // the cards dealt onto the table first
        let metrics: [XCTMetric] = [XCTOSSignpostMetric.scrollingAndDecelerationMetric, XCTHitchMetric(application: app),
                                    XCTCPUMetric(application: app)]
        // The fling lands on the app, whose middle is the drawer: the scroll view's identifier does not survive every
        // redraw of a drawer full of editions, and a fling at the window is what a thumb does anyway.
        measure(metrics: metrics, options: options(manual: true)) {
            startMeasuring()
            app.swipeUp(velocity: .fast)
            stopMeasuring()
            app.swipeDown(velocity: .fast)
            app.swipeDown(velocity: .fast)
        }
    }

    // MARK: The reveal

    /// A stub opened from the drawer: the zoom, the card sitting up and its first print, as one animation interval.
    func testReveal() {
        let app = app(["-stage-drawer", "24", "-stage-rules", "-face", "edition"])
        app.launch()
        let card = app.buttons["drawer.stub"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 30))
        pause(3)
        let reveal = XCTOSSignpostMetric(subsystem: Self.subsystem, category: "Motion", name: "Reveal")
        measure(metrics: [reveal, XCTHitchMetric(application: app), XCTCPUMetric(application: app)], options: options()) {
            card.tap()
            pause(2)
            app.navigationBars.buttons.firstMatch.tap()
            pause(1.5)
        }
    }

    // MARK: Capture

    /// The rule path, which is the only path the oldest phones have: a thermal receipt photographed, read, and kept.
    /// `Keepable` is the shutter to a draft with a title on screen; `Understood` to the reader's last word; `Kept` the
    /// tap on Keep to the store.
    func testCaptureRules() { capture(["-stage-rules"]) }

    /// The model path, where the host has an on-device model (the simulator's runs on the CPU, not the Neural Engine).
    /// `Keepable` must not wait for it; `Understood` is bounded by the reader's patience.
    func testCaptureModel() { capture([]) }

    private func capture(_ reader: [String]) {
        let metrics: [XCTMetric] = ["Keepable", "Understood", "Kept", "Pressed"].map {
            XCTOSSignpostMetric(subsystem: Self.subsystem, category: "Capture", name: $0)
        }
        measure(metrics: metrics, options: options(iterations: 3)) {
            let app = app(["-stage-drawer", "10", "-keep", "-camera", "stub-7-thermal.png", "-shutter"] + reader)
            app.launch()
            let keep = app.buttons["import.keep"]
            XCTAssertTrue(keep.waitForExistence(timeout: 30))
            let enabled = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: keep)
            wait(for: [enabled], timeout: 30)
            pause(9) // past the reader's patience, so Understood has ended whichever path ran
            keep.tap()
            XCTAssertTrue(app.buttons["Into the drawer"].waitForExistence(timeout: 10))
        }
    }

    /// Keep tapped to the press in front of the person: what the thumb feels, by the clock.
    func testKeepToPress() {
        measure(metrics: [XCTClockMetric()], options: options(iterations: 3, manual: true)) {
            let app = app(["-stage-drawer", "10", "-stage-rules", "-keep", "-camera", "stub-1-the-brutalist.png", "-shutter"])
            app.launch()
            let keep = app.buttons["import.keep"]
            XCTAssertTrue(keep.waitForExistence(timeout: 30))
            let enabled = expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: keep)
            wait(for: [enabled], timeout: 30)
            startMeasuring()
            keep.tap()
            XCTAssertTrue(app.buttons["Into the drawer"].waitForExistence(timeout: 10))
            stopMeasuring()
        }
    }

    // MARK: The tilt-light view

    /// A stub open, and the light swept across it at 60 Hz for four seconds: peak memory, CPU (the energy proxy XCTest
    /// has; the Energy instrument on a phone is the real one), and the sweep's hitches. The app is running before the
    /// measurement starts, as the memory and CPU metrics need; each iteration opens a stub and lets the light run.
    func testTiltLight() {
        let app = app(["-stage-drawer", "12", "-stage-rules", "-face", "edition", "-stage-tilt"])
        app.launch()
        let card = app.buttons["drawer.stub"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 30))
        pause(3)
        let tilt = XCTOSSignpostMetric(subsystem: Self.subsystem, category: "Motion", name: "Tilt")
        let metrics: [XCTMetric] = [XCTMemoryMetric(application: app), XCTCPUMetric(application: app), XCTHitchMetric(application: app), tilt]
        // Measured over the sweep alone: it starts a second and a half after the card appears and runs four seconds.
        measure(metrics: metrics, options: options(iterations: 3, manual: true)) {
            card.tap()
            pause(1.6)
            startMeasuring()
            pause(4.3)
            stopMeasuring()
            pause(0.6)
            app.navigationBars.buttons.firstMatch.tap()
            pause(1.5)
        }
    }
}
