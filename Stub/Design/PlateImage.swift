import UIKit
import ImageIO

/// Where a plate is drawn, and so how many of its pixels can ever be seen.
struct PlateFrame: Sendable {
    /// Names the frame in the cache key.
    let name: String
    /// The widest the plate is drawn, in pixels.
    let width: Double
    /// The aspect the frame is held to when the plate fills it; `nil` when the plate fits the width.
    let fill: ClosedRange<Double>?

    /// The card: one column at the accessibility sizes is the widest a card gets, about 400 pt at 3×. Its plate
    /// is no taller than it is wide and no flatter than 2.6:1, and the photograph fills it (StubCard.plate).
    static let card = PlateFrame(name: "card", width: 1200, fill: 1...2.6)
    /// The detail: the full width of the largest phone at 3×, the photograph fitted to it.
    static let detail = PlateFrame(name: "detail", width: 1320, fill: nil)

    /// The longest side, in pixels, to decode an upright `width`×`height` photograph at so that this frame never
    /// draws it larger than it was decoded. Fitted, the width binds; filling a clamped frame, a photograph
    /// flatter than the clamp is bound by the frame's height instead.
    func longestSide(width w: Double, height h: Double) -> Int {
        var scale = width / w
        if let fill {
            let aspect = min(max(w / h, fill.lowerBound), fill.upperBound)
            scale = max(scale, width / aspect / h)
        }
        return Int((scale * max(w, h)).rounded(.up))
    }
}

/// A stub's photograph, decoded at the size it is drawn, once.
///
/// `UIImage(data:)` in a view body decodes the whole JPEG again every time that body runs, and the card's and
/// the detail's bodies run on every touch-down and every hold, on the main thread, at full resolution. This
/// decodes through ImageIO's thumbnailer instead, which scales inside the JPEG decoder rather than after it,
/// to no more pixels than the frame can show, and keeps the result. App-only: the widget draws no photographs
/// and may not import UIKit (ADR-012).
@MainActor
enum PlateImage {
    /// A photograph coming in: 12 MP passes untouched, 24 and 48 MP come down to it. The fixtures are 2400 px.
    static let intake = 4032

    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        // Decoded bytes, not files. NSCache also lets go under memory pressure.
        cache.totalCostLimit = 96 * 1024 * 1024
        return cache
    }()

    /// The plate for a stub in `frame`, or `nil` when it has no photograph. A photograph is fixed when the stub
    /// is kept, so the id and the frame are the whole key. `data` is read only on a miss: `imageData` is external
    /// storage, and reading it pulls the file off disk.
    static func image(for id: UUID, in frame: PlateFrame, data: @autoclosure () -> Data?) -> UIImage? {
        let key = "\(id.uuidString)@\(frame.name)" as NSString
        if let hit = cache.object(forKey: key) { return hit }
        guard let bytes = data(), let src = source(bytes) else { return nil }
        let longest = uprightSize(of: src).map { frame.longestSide(width: $0.width, height: $0.height) }
        guard let cg = thumbnail(src, maxPixelSize: longest ?? Int(frame.width)) else { return nil }
        let image = UIImage(cgImage: cg)
        cache.setObject(image, forKey: key, cost: cg.bytesPerRow * cg.height)
        return image
    }

    /// `data` decoded upright, its EXIF orientation applied to the pixels, with the longest side at most
    /// `maxPixelSize`. Never upscales. `UIImage(data:).cgImage` hands back the sensor's buffer as it lay, so a
    /// photograph taken in portrait reached Vision on its side.
    nonisolated static func decode(_ data: Data, maxPixelSize: Int) -> CGImage? {
        guard let src = source(data) else { return nil }
        return thumbnail(src, maxPixelSize: maxPixelSize)
    }

    /// The photograph's pixel size the right way up, read from its header without decoding it.
    nonisolated static func uprightSize(of source: CGImageSource) -> (width: Double, height: Double)? {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
              let w = properties[kCGImagePropertyPixelWidth as String] as? Int,
              let h = properties[kCGImagePropertyPixelHeight as String] as? Int,
              w > 0, h > 0 else { return nil }
        // EXIF orientations 5 to 8 are the quarter turns: the photograph stands the other way up.
        let orientation = properties[kCGImagePropertyOrientation as String] as? Int ?? 1
        return orientation >= 5 ? (width: Double(h), height: Double(w)) : (width: Double(w), height: Double(h))
    }

    private nonisolated static func source(_ data: Data) -> CGImageSource? {
        let options: [CFString: Any] = [kCGImageSourceShouldCache: false]
        return CGImageSourceCreateWithData(data as CFData, options as CFDictionary)
    }

    private nonisolated static func thumbnail(_ source: CGImageSource, maxPixelSize: Int) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
