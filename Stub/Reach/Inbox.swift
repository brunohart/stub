import Foundation
import OSLog

/// What the share extension hands the app (ADR-023): a file in the App Group's `Inbox` folder and a note beside it saying
/// what it is. The extension writes here and nowhere else; it never opens the drawer, so the app stays the store's only
/// writer (ADR-012). The app takes the oldest item each time it comes to the front and opens the import sheet on it.
/// Foundation only: the extension compiles this file.
enum Inbox {
    static let log = Logger(subsystem: "com.designedbybruno.stub", category: "inbox")

    enum Kind: String, Codable, Sendable {
        case pass, pdf, image
    }

    struct Item: Codable, Equatable, Sendable {
        var id: UUID
        var kind: Kind
        /// The file's name in the inbox: `<id>.<extension>`.
        var file: String
        var receivedAt: Date
    }

    enum Failure: Error, Equatable { case noGroup, tooLarge }

    /// Nothing larger is taken: a ticket is a pass, a page or a picture, never a film.
    static let largest = 40 << 20

    /// The inbox folder, or `nil` where there is no App Group to put it in.
    static func folder(in container: URL? = AppGroup.container) -> URL? {
        container?.appending(path: "Inbox", directoryHint: .isDirectory)
    }

    /// Copies `file` into the inbox as a `kind`. The extension calls this when the person sends the ticket.
    @discardableResult
    static func put(_ file: URL, kind: Kind, in container: URL? = AppGroup.container, at date: Date = .now) throws -> Item {
        guard let folder = folder(in: container) else { throw Failure.noGroup }
        let size = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard size <= largest else { throw Failure.tooLarge }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let id = UUID()
        let ext = file.pathExtension.isEmpty ? kind.rawValue : file.pathExtension.lowercased()
        let item = Item(id: id, kind: kind, file: "\(id.uuidString).\(ext)", receivedAt: date)
        try FileManager.default.copyItem(at: file, to: folder.appending(path: item.file))
        // The note last, so the app never finds a note without its file.
        let note = try JSONEncoder().encode(item)
        try note.write(to: folder.appending(path: "\(id.uuidString).json"), options: .atomic)
        log.info("Inbox: put a \(kind.rawValue), \(size) bytes")
        return item
    }

    /// Everything waiting, oldest first.
    static func items(in container: URL? = AppGroup.container) -> [Item] {
        guard let folder = folder(in: container),
              let names = try? FileManager.default.contentsOfDirectory(atPath: folder.path) else { return [] }
        return names.filter { $0.hasSuffix(".json") }.compactMap { name in
            guard let data = try? Data(contentsOf: folder.appending(path: name)) else { return nil }
            return try? JSONDecoder().decode(Item.self, from: data)
        }
        .sorted { $0.receivedAt < $1.receivedAt }
    }

    /// The item's file and its note, taken out of the inbox: the bytes come back and nothing is left behind.
    static func take(_ item: Item, in container: URL? = AppGroup.container) -> Data? {
        guard let folder = folder(in: container) else { return nil }
        let file = folder.appending(path: item.file)
        let data = try? Data(contentsOf: file)
        try? FileManager.default.removeItem(at: file)
        try? FileManager.default.removeItem(at: folder.appending(path: "\(item.id.uuidString).json"))
        return data
    }
}
