import WidgetKit
import SwiftUI
import AppIntents

/// Keep a stub, from anywhere: the Lock Screen, Control Centre, the Action button (docs/decisions/002-surfaces.md). The
/// shortest path in iOS from a phone coming out of a pocket at the cinema door to Stub's viewfinder: one press. It opens
/// the app at `stub://keep`, the same viewfinder as the dock's Keep a stub.
struct KeepControl: ControlWidget {
    static let kind = "com.designedbybruno.stub.keep"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: KeepControlIntent()) {
                Label("Keep a stub", systemImage: "ticket")
            }
        }
        .displayName("Keep a stub")
        .description("Opens Stub's camera, ready to keep tonight's ticket.")
    }
}

/// The control's act: open Stub on the viewfinder.
struct KeepControlIntent: AppIntent {
    static let title: LocalizedStringResource = "Keep a stub"
    static let description = IntentDescription("Opens Stub's camera, ready to keep tonight's ticket.")
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(URL(string: "stub://keep")!))
    }
}
