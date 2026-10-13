import UIKit
import SwiftUI
import UniformTypeIdentifiers

/// Stub in the share sheet (BEDIP-218, ADR-023): a Wallet pass, a PDF e-ticket or a screenshot, from any app. It shows what
/// it was handed and puts it in the App Group's inbox when the person sends it; the app reads and files it the next time it
/// comes to the front. No store, no Vision, no model here: the extension stays small and the app stays the drawer's only
/// writer (ADR-012).
final class ShareViewController: UIViewController {
    private let model = ShareModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(Ink.paper)
        let host = UIHostingController(rootView: ShareView(model: model, finish: { [weak self] in self?.finish() },
                                                           cancel: { [weak self] in self?.cancel() }))
        host.view.backgroundColor = .clear
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        host.didMove(toParent: self)
        let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? []).flatMap { $0.attachments ?? [] }
        Task { await model.load(providers) }
    }

    private func finish() {
        extensionContext?.completeRequest(returningItems: nil)
    }

    private func cancel() {
        extensionContext?.cancelRequest(withError: NSError(domain: "com.designedbybruno.stub.share", code: NSUserCancelledError))
    }
}

/// What the extension was handed, and what it did with it.
@MainActor @Observable
final class ShareModel {
    enum State {
        case loading
        case pass(WalletPass, file: URL)
        case page(UIImage, kind: Inbox.Kind, file: URL)
        case failed(String)
        case sent(Inbox.Kind)
    }

    private(set) var state: State = .loading

    /// The kinds Stub takes, in the order it prefers them when an item offers more than one.
    static let kinds: [(UTType, Inbox.Kind)] = [
        (UTType("com.apple.pkpass") ?? .data, .pass),
        (.pdf, .pdf),
        (.image, .image),
    ]

    func load(_ providers: [NSItemProvider]) async {
        for (type, kind) in Self.kinds {
            guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(type.identifier) }) else { continue }
            guard let file = await Self.copy(provider, type: type) else { continue }
            switch kind {
            case .pass:
                if let data = try? Data(contentsOf: file), let pass = try? WalletPass(pkpass: data) {
                    state = .pass(pass, file: file)
                } else {
                    state = .failed("That pass could not be opened.")
                }
            case .pdf:
                if let data = try? Data(contentsOf: file), let page = PageImage.firstPage(of: data) {
                    state = .page(UIImage(cgImage: page), kind: .pdf, file: file)
                } else {
                    state = .failed("That PDF has no page to read.")
                }
            case .image:
                if let image = UIImage(contentsOfFile: file.path) {
                    state = .page(image, kind: .image, file: file)
                } else {
                    state = .failed("That picture could not be opened.")
                }
            }
            return
        }
        state = .failed("Stub takes Wallet passes, PDF tickets and screenshots.")
    }

    /// Puts the file in the inbox for the app.
    func send() {
        let (file, kind): (URL, Inbox.Kind)
        switch state {
        case .pass(_, let f): (file, kind) = (f, .pass)
        case .page(_, let k, let f): (file, kind) = (f, k)
        default: return
        }
        do {
            try Inbox.put(file, kind: kind)
            state = .sent(kind)
        } catch {
            state = .failed("Stub could not keep it here. Open Stub and try again.")
        }
    }

    /// A copy of the provider's file in this extension's own temporary folder: the system's copy lasts only as long as the
    /// call that hands it over.
    private static func copy(_ provider: NSItemProvider, type: UTType) async -> URL? {
        await withCheckedContinuation { continuation in
            _ = provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { url, _ in
                guard let url else {
                    // Some apps offer an image only as data.
                    provider.loadDataRepresentation(forTypeIdentifier: type.identifier) { data, _ in
                        guard let data else { continuation.resume(returning: nil); return }
                        let ext = type.preferredFilenameExtension ?? "dat"
                        let out = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).\(ext)")
                        continuation.resume(returning: (try? data.write(to: out)) != nil ? out : nil)
                    }
                    return
                }
                let out = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).\(url.pathExtension.isEmpty ? (type.preferredFilenameExtension ?? "dat") : url.pathExtension)")
                continuation.resume(returning: (try? FileManager.default.copyItem(at: url, to: out)) != nil ? out : nil)
            }
        }
    }
}
