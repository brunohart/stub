import OSLog
import MetricKit

/// The intervals the budgets are measured on (docs/decisions/004-budgets.md). A signpost costs next to nothing when
/// nobody is recording, so they ship: Instruments reads them on a phone, `XCTOSSignpostMetric` in the performance tests.
///
/// Capture: a ticket from the moment it reaches the reader (the shutter, a photograph, a share) to a draft that can be
/// kept (`Keepable`), to the model's last word (`Understood`); from the tap on Keep to the store (`Kept`) and to the press
/// in front of the person (`Pressed`).
/// Motion: the animations whose hitches are budgeted, a stub revealed (`Reveal`) and the light swept across it (`Tilt`).
enum Signposts {
    static let subsystem = "com.designedbybruno.stub"
    static let capture = OSSignposter(subsystem: subsystem, category: "Capture")
    static let motion = OSSignposter(subsystem: subsystem, category: "Motion")

    static let keepable: StaticString = "Keepable"
    static let understood: StaticString = "Understood"
    static let kept: StaticString = "Kept"
    /// Keep tapped to the press on screen: what the thumb feels.
    static let pressed: StaticString = "Pressed"
    static let reveal: StaticString = "Reveal"
    static let tilt: StaticString = "Tilt"
}

/// One ticket's trip through the reader, as the signposts see it: begun when the reader is handed the ticket, `Keepable`
/// ended when a draft with a title is in front of the person, `Understood` when the reader has said its last word.
@MainActor
final class CaptureClock {
    private let id = Signposts.capture.makeSignpostID()
    private var keepable: OSSignpostIntervalState?
    private var understood: OSSignpostIntervalState?

    /// The same interval for MetricKit, so the field reports carry it too (`FieldMetrics`).
    private let field: OSSignpostID
    private var fieldOpen = true

    init() {
        keepable = Signposts.capture.beginInterval(Signposts.keepable, id: id)
        understood = Signposts.capture.beginInterval(Signposts.understood, id: id)
        field = OSSignpostID(log: FieldMetrics.capture)
        mxSignpost(.begin, log: FieldMetrics.capture, name: "Keepable", signpostID: field)
    }

    /// A draft is on screen. The first with a title ends `Keepable`.
    func offered(_ draft: StubDraft) {
        guard draft.isUsable, let state = keepable else { return }
        Signposts.capture.endInterval(Signposts.keepable, state)
        keepable = nil
        endField()
    }

    private func endField() {
        guard fieldOpen else { return }
        mxSignpost(.end, log: FieldMetrics.capture, name: "Keepable", signpostID: field)
        fieldOpen = false
    }

    /// The reader is done, with a title or without one (then `Keepable` ends here too: the time until it gave up).
    func finished() {
        if let state = keepable { Signposts.capture.endInterval(Signposts.keepable, state); keepable = nil; endField() }
        if let state = understood { Signposts.capture.endInterval(Signposts.understood, state); understood = nil }
    }
}
