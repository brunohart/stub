import SwiftUI
import Vision
import ImageIO
import OSLog

/// Each film's official poster (ADR-049, ADR-050). The edition prints its key art into the movement's own hero form, in the
/// edition's inks (`KeyArt`), so every card carries the film's own image under the app's design.
///
/// Where it comes from: the cinema. A ticket handed over in an Add to Stub link can carry the address of the cinema's
/// poster for the film (`AddLink.posterURL`); when the person keeps it, the poster is fetched once from that address,
/// made a plain JPEG with nothing in it but the picture, and kept in the press's ledger, so it reaches the person's other
/// phones through their own iCloud and outlives the cinema's copy. Nothing of the person's goes with the request: the
/// address is the cinema's, without a query, and the session keeps no cookies. A release keeps the first poster it is
/// handed.
///
/// TMDB (ADR-049) stays in the code, off: it asks only in a build with TMDB's token, which no build has (decision 009).
@MainActor @Observable
final class Posters {
    static let shared = Posters()
    nonisolated static let log = Logger(subsystem: Signposts.subsystem, category: "posters")

    /// A poster ready to print: the image, downsampled, and where its subject is (Vision's saliency), as a share of the
    /// image with the origin at the top left, so the key art is cropped to the subject, not the billing block.
    struct Poster: Sendable {
        let image: UIImage
        let focus: CGRect
    }

    /// The releases whose poster is on the phone. Only the last few are held decoded: a drawer of two hundred films
    /// would otherwise hold six hundred megabytes of posters.
    private(set) var ready: Set<String> = []
    @ObservationIgnored private var recent: [(key: String, poster: Poster)] = []
    @ObservationIgnored private var asked: Set<String> = []
    @ObservationIgnored private var fetching: Set<String> = []
    /// The press's ledger, where a cinema's poster is kept so it syncs with the stubs (ADR-024).
    @ObservationIgnored var ledger: PressLedger?
    #if DEBUG || PERF
    @ObservationIgnored private var staged: Poster?
    #endif

    /// The person's choice, in Your card: posters on (the default) or off, in which case no title is ever sent and the
    /// editions print without them.
    static let enabledKey = "posters.enabled"
    var on: Bool = UserDefaults.standard.object(forKey: Posters.enabledKey) as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(on, forKey: Self.enabledKey)
            // Turned back on: the films asked about while it was off are asked about again.
            if on { asked.removeAll() }
        }
    }


    /// TMDB's read token, from the build (Config/Secrets.xcconfig). Empty in a build without one.
    nonisolated static var token: String? {
        guard let token = Bundle.main.object(forInfoDictionaryKey: "TMDBToken") as? String,
              !token.trimmingCharacters(in: .whitespaces).isEmpty, !token.hasPrefix("$(") else { return nil }
        return token
    }

    /// Whether `release`'s poster is here to print.
    func isReady(_ release: String) -> Bool { on && ready.contains(release) }

    /// `release`'s poster, decoded: from the last few, or from the phone.
    func poster(for release: String) async -> Poster? {
        guard isReady(release) else { return nil }
        #if DEBUG || PERF
        if let staged { return staged }
        #endif
        if let hit = recent.first(where: { $0.key == release }) { return hit.poster }
        guard let kept = await Self.kept(release) else {
            ready.remove(release)
            return nil
        }
        hold(kept, for: release)
        return kept
    }

    private func hold(_ poster: Poster, for key: String) {
        recent.removeAll { $0.key == key }
        recent.insert((key, poster), at: 0)
        if recent.count > 4 { recent.removeLast() }
    }

    /// Make sure `title`'s poster is here or on its way: from the phone if it was fetched before, otherwise from TMDB.
    func want(title: String, year: Int?) {
        let key = Release.key(for: title)
        guard on, !key.isEmpty, !asked.contains(key) else { return }
        asked.insert(key)
        #if DEBUG || PERF
        if let file = DebugDrive.posterFile {
            Task { await self.stage(file, for: key) }
            return
        }
        #endif
        // Kept on the phone: ready, and decoded only when a card prints it.
        if FileManager.default.fileExists(atPath: Self.file(key, "jpg").path) {
            ready.insert(key)
            return
        }
        Task {
            guard on, let token = Self.token, !Self.recentlyMissing(key) else { return }
            do {
                guard let data = try await Self.fetch(title: Release.stripFormats(title), year: year, token: token) else {
                    Self.markMissing(key)
                    Self.log.info("Poster '\(key, privacy: .public)': none found")
                    return
                }
                guard let poster = await Self.prepare(data) else { return }
                Self.keep(data, focus: poster.focus, for: key)
                hold(poster, for: key)
                ready.insert(key)
                Self.log.info("Poster '\(key, privacy: .public)': kept")
            } catch {
                // Offline, or TMDB unreachable: asked again on the next launch.
                asked.remove(key)
                Self.log.error("Poster '\(key, privacy: .public)': \(String(describing: error), privacy: .public)")
            }
        }
    }

    // MARK: The cinema's

    /// The poster the cinema handed over with the ticket, fetched once, now that the stub is kept. Not when posters are
    /// off, and not for a release that already has one.
    func supplied(_ url: URL, title: String) {
        let key = Release.key(for: title)
        guard on, !key.isEmpty, !ready.contains(key), !fetching.contains(key),
              !FileManager.default.fileExists(atPath: Self.file(key, "jpg").path) else { return }
        fetching.insert(key)
        Task {
            defer { fetching.remove(key) }
            do {
                guard let data = try await Self.download(url) else {
                    Self.log.notice("Poster '\(key, privacy: .public)': the cinema's address gave no image")
                    return
                }
                let jpeg = await Task.detached(priority: .utility) { Self.sanitised(data) }.value
                guard let jpeg, let poster = await Self.prepare(jpeg) else {
                    Self.log.notice("Poster '\(key, privacy: .public)': not a poster (\(data.count) bytes)")
                    return
                }
                Self.keep(jpeg, focus: poster.focus, for: key)
                ledger?.put(.poster, key, jpeg)
                hold(poster, for: key)
                ready.insert(key)
                Self.log.info("Poster '\(key, privacy: .public)': kept from the cinema")
            } catch {
                Self.log.error("Poster '\(key, privacy: .public)': \(String(describing: error), privacy: .public)")
            }
        }
    }

    /// The posters the ledger holds, from this phone or another: any not yet on this phone is written to it.
    func adopt(_ keys: Set<String>, data: (String) -> Data?) {
        for key in keys {
            if !FileManager.default.fileExists(atPath: Self.file(key, "jpg").path) {
                guard let jpeg = data(key) else { continue }
                try? FileManager.default.createDirectory(at: Self.folder, withIntermediateDirectories: true)
                try? jpeg.write(to: Self.file(key, "jpg"))
            }
            ready.insert(key)
        }
    }

    /// No bigger than this, as downloaded.
    nonisolated static let largest = 8 * 1024 * 1024

    /// The image at a cinema's address: https to a public name, redirects held to the same rule, an image and nothing
    /// else, no more than 8 MB. No cookies, no cache, nothing of the person's.
    nonisolated static func download(_ url: URL, session: URLSession = URLSession(configuration: .ephemeral)) async throws -> Data? {
        guard AddLink.isPublicHTTPS(url) else { return nil }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.httpShouldHandleCookies = false
        request.setValue("image/*", forHTTPHeaderField: "Accept")
        let (bytes, response) = try await session.bytes(for: request, delegate: SameRules())
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              http.mimeType?.lowercased().hasPrefix("image/") == true, http.expectedContentLength <= largest else { return nil }
        var data = Data()
        data.reserveCapacity(max(0, min(Int(http.expectedContentLength), largest)))
        for try await byte in bytes {
            data.append(byte)
            if data.count > largest { return nil }
        }
        return data
    }

    /// Redirects go only where the poster itself could have pointed.
    private final class SameRules: NSObject, URLSessionTaskDelegate, Sendable {
        func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                        newRequest request: URLRequest) async -> URLRequest? {
            guard let url = request.url, AddLink.isPublicHTTPS(url) else { return nil }
            return request
        }
    }

    /// The download as Stub keeps it: decoded (so it is an image), no more than 60 megapixels, the shape of a poster
    /// (portrait, or near square), at least 400 pixels on its long side, and written again as a JPEG of 900 pixels at most
    /// with nothing in it but the picture. `nil` for anything else: a pixel, a banner, a page that is not an image.
    nonisolated static func sanitised(_ data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              CGImageSourceGetCount(source) >= 1,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let w = properties[kCGImagePropertyPixelWidth] as? Int, let h = properties[kCGImagePropertyPixelHeight] as? Int,
              w > 0, h > 0, w * h <= 60_000_000,
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 900,
                  kCGImageSourceCreateThumbnailWithTransform: true] as CFDictionary) else { return nil }
        let aspect = Double(image.width) / Double(image.height)
        guard max(image.width, image.height) >= 400, (0.45...1.1).contains(aspect) else { return nil }
        for quality in [0.82, 0.7, 0.55] {
            let out = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(out, "public.jpeg" as CFString, 1, nil) else { return nil }
            CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
            guard CGImageDestinationFinalize(destination) else { return nil }
            // Small enough to ride in the ledger's record to iCloud.
            if out.length <= 400_000 || quality == 0.55 { return out as Data }
        }
        return nil
    }

    #if DEBUG || PERF
    /// `-poster poster-orchard.jpg`: a stand-in poster from the bundle for every release, so the key art is built and
    /// screenshotted without TMDB (scripts/make-posters.py draws them).
    private func stage(_ file: String, for key: String) async {
        if staged == nil {
            guard let url = Bundle.main.url(forResource: file, withExtension: nil), let data = try? Data(contentsOf: url),
                  let poster = await Self.prepare(data) else { return }
            staged = poster
        }
        ready.insert(key)
    }
    #endif

    // MARK: TMDB

    /// One search result, as much of it as the choice needs.
    struct Candidate: Decodable, Equatable, Sendable {
        var title: String?
        var original_title: String?
        var release_date: String?
        var poster_path: String?
        var popularity: Double?
    }

    private struct Page: Decodable { var results: [Candidate] }

    /// The poster TMDB holds for `title`: searched with the year it was seen, and again without if that finds nothing.
    nonisolated static func fetch(title: String, year: Int?, token: String) async throws -> Data? {
        let session = URLSession(configuration: .ephemeral)
        var found = try await search(title, year: year, token: token, session: session)
        if found.isEmpty, year != nil { found = try await search(title, year: nil, token: token, session: session) }
        guard let best = choose(found, title: title, seen: year), let path = best.poster_path else { return nil }
        let (data, response) = try await session.data(from: URL(string: "https://image.tmdb.org/t/p/w780\(path)")!)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return data
    }

    nonisolated private static func search(_ title: String, year: Int?, token: String, session: URLSession) async throws -> [Candidate] {
        var url = URLComponents(string: "https://api.themoviedb.org/3/search/movie")!
        url.queryItems = [URLQueryItem(name: "query", value: title), URLQueryItem(name: "include_adult", value: "false"),
                          URLQueryItem(name: "language", value: "en-US"), URLQueryItem(name: "page", value: "1")]
            + (year.map { [URLQueryItem(name: "year", value: String($0))] } ?? [])
        var request = URLRequest(url: url.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return [] }
        return (try? JSONDecoder().decode(Page.self, from: data))?.results ?? []
    }

    /// Which result is the film on the ticket: one with a poster; its title the ticket's, word for word once folded; and
    /// released in the year it was seen or the year before (a cinema shows a film for months, sometimes into the next year).
    /// Ties go to the better known. `nil` when nothing has a poster.
    nonisolated static func choose(_ results: [Candidate], title: String, seen year: Int?) -> Candidate? {
        let wanted = Release.key(for: title)
        func score(_ c: Candidate) -> Double {
            var s = 0.0
            if [c.title, c.original_title].compactMap({ $0 }).contains(where: { Release.key(for: $0) == wanted }) { s += 4 }
            if let year, let released = c.release_date.flatMap({ Int($0.prefix(4)) }) {
                let gap = year - released
                if gap == 0 || gap == 1 { s += 2 } else if gap == -1 || gap == 2 { s += 1 } else if abs(gap) > 4 { s -= 2 }
            }
            return s + min(c.popularity ?? 0, 100) / 1000
        }
        return results.filter { $0.poster_path != nil }.max { score($0) < score($1) }
    }

    // MARK: Preparing

    /// Decoded at a size fit for the card, and its subject found by Vision's attention saliency, off the main thread.
    nonisolated static func prepare(_ data: Data) async -> Poster? {
        await Task.detached(priority: .utility) { () -> Poster? in
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                      kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 1100,
                      kCGImageSourceCreateThumbnailWithTransform: true] as CFDictionary) else { return nil }
            return Poster(image: UIImage(cgImage: image), focus: focus(of: image))
        }.value
    }

    /// Where the poster's subject is: the union of Vision's salient regions, top-left origin, widened a little so a face
    /// keeps its forehead. The whole poster above its billing block when Vision finds nothing.
    nonisolated static func focus(of image: CGImage) -> CGRect {
        let fallback = CGRect(x: 0.08, y: 0.08, width: 0.84, height: 0.62)
        let request = VNGenerateAttentionBasedSaliencyImageRequest()
        try? VNImageRequestHandler(cgImage: image).perform([request])
        guard let regions = request.results?.first?.salientObjects, !regions.isEmpty else { return fallback }
        let box = regions.map(\.boundingBox).reduce(regions[0].boundingBox) { $0.union($1) }
        let flipped = CGRect(x: box.minX, y: 1 - box.maxY, width: box.width, height: box.height)
        return flipped.insetBy(dx: -box.width * 0.08, dy: -box.height * 0.08)
            .intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
    }

    // MARK: Kept on the phone

    nonisolated static var folder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appending(path: "Posters")
    }

    nonisolated static func file(_ key: String, _ ext: String) -> URL {
        folder.appending(path: key.replacingOccurrences(of: " ", with: "-") + "." + ext)
    }

    nonisolated static func keep(_ data: Data, focus: CGRect, for key: String) {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? data.write(to: file(key, "jpg"))
        let numbers = [focus.minX, focus.minY, focus.width, focus.height].map { String(format: "%.4f", $0) }
        try? numbers.joined(separator: ",").write(to: file(key, "focus"), atomically: true, encoding: .utf8)
    }

    nonisolated private static func kept(_ key: String) async -> Poster? {
        guard let data = try? Data(contentsOf: file(key, "jpg")) else { return nil }
        let saved = (try? String(contentsOf: file(key, "focus"), encoding: .utf8))?.split(separator: ",").compactMap { Double($0) }
        guard let decoded = await prepareImage(data) else { return nil }
        if let saved, saved.count == 4 {
            return Poster(image: decoded, focus: CGRect(x: saved[0], y: saved[1], width: saved[2], height: saved[3]))
        }
        return Poster(image: decoded, focus: focus(of: decoded.cgImage!))
    }

    nonisolated private static func prepareImage(_ data: Data) async -> UIImage? {
        await Task.detached(priority: .utility) { () -> UIImage? in
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                      kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 1100,
                      kCGImageSourceCreateThumbnailWithTransform: true] as CFDictionary) else { return nil }
            return UIImage(cgImage: image)
        }.value
    }

    /// A release TMDB had no poster for is not asked about again for a month.
    nonisolated private static func markMissing(_ key: String) {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? Date.now.ISO8601Format().write(to: file(key, "missing"), atomically: true, encoding: .utf8)
    }

    nonisolated private static func recentlyMissing(_ key: String) -> Bool {
        guard let text = try? String(contentsOf: file(key, "missing"), encoding: .utf8),
              let when = try? Date(text, strategy: .iso8601) else { return false }
        return Date.now.timeIntervalSince(when) < 30 * 24 * 3600
    }
}
