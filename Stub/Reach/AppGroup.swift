import Foundation

/// The App Group the app, the widget and the share extension share (ADR-012, ADR-023): the drawer's store and the inbox
/// live in its container. Foundation only, so every target can compile it.
enum AppGroup {
    static let id = "group.com.designedbybruno.stub"

    /// The group's container, or `nil` on a host whose build or profile does not carry the group.
    static var container: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id)
    }
}
