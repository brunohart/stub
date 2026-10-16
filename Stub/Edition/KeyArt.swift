import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

/// The film's own key art, printed into the edition (ADR-049). The official poster, cropped to its subject by Vision's
/// saliency so the billing block never prints, set into the movement's hero (its disc or block) and printed the way the
/// movement prints: a Swiss poster's enlarged halftone, a constructivist line screen running up its diagonal, deco's
/// concentric screen, the risograph's coarse dot, Saul Bass's cut paper, an engraver's hatching, noir's venetian blind.
/// Then in the edition's own inks: the darks in the darker ink, the lights left to the hero's colour, and the screen
/// pulled a second time in the second ink, a point and a half off. The movement keeps its grammar and its inks; the film
/// gives the card its picture, so every edition is that film's and no other's. A movement with no hero to carry it (the
/// letterpress, under a long title) presses it blind into the stock instead.
struct KeyArt: View {
    let composition: Composition
    private let posters = Posters.shared
    private let prints = KeyArtPrints.shared

    var body: some View {
        if posters.isReady(composition.edition.release) {
            let window = composition.keyArt
            let screen = KeyArtScreen.of(composition)
            let key = KeyArtPrints.key(composition, screen: screen)
            Group {
                if let image = prints.image(for: key) {
                    Group {
                        if window.blind { blind(image, in: window.bounds) } else { screened(image, in: window) }
                    }
                    .transition(.opacity.animation(Motion.settle))
                } else {
                    // Something to hang the making on: a view with nothing in it never runs its task.
                    Color.clear
                }
            }
            .frame(width: Card.width, height: Card.height, alignment: .topLeading)
            .clipShape(WindowShape(path: window.path))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .task(id: key) {
                await prints.make(key, release: composition.edition.release, window: window.bounds, screen: screen,
                                  centre: window.centre)
            }
        }
    }

    /// Printed into the hero, in the edition's inks.
    @ViewBuilder
    private func screened(_ image: UIImage, in window: KeyArtWindow) -> some View {
        if window.kind == .letter {
            // In the letter's own ink, under the letter: the letter is a picture of the film, and the title, set over it
            // in the darker ink, still reads.
            let light = EditionInks.luminance(composition.inks.hex(composition.posterField)) > 0.35
            pass(image, in: window.bounds, colour: composition.inks.color(window.role), darks: light)
                .opacity(light ? 0.62 : 0.5)
                .blendMode(light ? .multiply : .screen)
        } else {
            inked(image, in: window)
        }
    }

    private func inked(_ image: UIImage, in window: KeyArtWindow) -> some View {
        let inks = composition.inks
        // On a light hero the darks print in the darker ink, multiplied in; on a dark one the lights print in the lighter
        // ink, screened on.
        let lightHero = EditionInks.luminance(inks.hex(window.role)) > 0.35
        // A field carries it quieter than a hero, so the type stays the strongest thing on the card: on a light ground in
        // the movement's own colour rather than the type's ink.
        let field = window.kind == .field
        let quiet = field ? 0.6 : 1
        let ink: Role = lightHero ? (field ? .primary : .dark) : .light
        return ZStack(alignment: .topLeading) {
            pass(image, in: window.bounds, colour: inks.color(ink), darks: lightHero)
                .opacity((lightHero ? 0.9 : 0.85) * quiet)
            // The second pull, in the second ink, off register: the depth a two-colour print has.
            pass(image, in: window.bounds, colour: inks.color(.secondary), darks: lightHero)
                .opacity(0.28 * quiet)
                .offset(x: 1.4, y: -1.1)
        }
        .blendMode(lightHero ? .multiply : .screen)
    }

    /// Pressed blind: no ink. The picture's darks are where the plate bit into the cotton, so each shape has a shadow on
    /// the side away from the lamp, a catch of light on the side toward it, and a floor a shade deeper than the sheet.
    private func blind(_ image: UIImage, in window: CGRect) -> some View {
        let shadow = Color(hex: EditionInks.mix(composition.inks.hex(composition.posterField), 0x000000, 0.5))
        return ZStack(alignment: .topLeading) {
            pass(image, in: window, colour: shadow, darks: true)
                .opacity(0.1)
            pass(image, in: window, colour: shadow, darks: true)
                .opacity(0.28)
                .offset(x: 0.9, y: 1.1)
                .blendMode(.multiply)
            pass(image, in: window, colour: .white, darks: true)
                .opacity(0.6)
                .offset(x: -0.8, y: -1)
                .blendMode(.screen)
        }
        .compositingGroup()
    }

    /// One pass: the printed screen as the ink's coverage.
    private func pass(_ image: UIImage, in window: CGRect, colour: Color, darks: Bool) -> some View {
        Rectangle()
            .fill(colour)
            .frame(width: Card.width, height: Card.height)
            .mask(alignment: .topLeading) {
                Group {
                    if darks {
                        Image(uiImage: image).resizable().colorInvert().luminanceToAlpha()
                    } else {
                        Image(uiImage: image).resizable().luminanceToAlpha()
                    }
                }
                .frame(width: window.width, height: window.height)
                .offset(x: window.minX, y: window.minY)
                .frame(width: Card.width, height: Card.height, alignment: .topLeading)
            }
    }

    /// Where the poster lies on the card: scaled so its subject fills the window, never leaving the window uncovered, and
    /// never zoomed past three times what covering it needs; its subject's centre on the window's.
    static func frame(for poster: Posters.Poster, in window: CGRect) -> CGRect {
        let size = poster.image.size
        guard size.width > 0, size.height > 0 else { return window }
        let focus = poster.focus.width > 0.05 && poster.focus.height > 0.05 ? poster.focus : CGRect(x: 0, y: 0, width: 1, height: 1)
        let cover = max(window.width / size.width, window.height / size.height)
        let fill = max(window.width / (focus.width * size.width), window.height / (focus.height * size.height))
        let scale = min(max(fill, cover), cover * 3)
        let width = size.width * scale, height = size.height * scale
        var x = window.midX - focus.midX * width
        var y = window.midY - focus.midY * height
        x = min(window.minX, max(window.maxX - width, x))
        y = min(window.minY, max(window.maxY - height, y))
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

/// How a movement turns a photograph into something its press can print. Sizes are in card points.
enum KeyArtScreen: Equatable, Sendable {
    /// A round-dot halftone at an angle.
    case dots(degrees: Double, size: CGFloat)
    /// A line screen: parallel rules whose width carries the tone.
    case lines(degrees: Double, size: CGFloat)
    /// Concentric rings about the window's centre.
    case rings(size: CGFloat)
    /// Crossed hatching, as an engraver or a draughtsman shades.
    case hatch(degrees: Double, size: CGFloat)
    /// Cut paper: light or dark, nothing between.
    case cut
    /// The tones as they are, for a blind pressing.
    case smooth

    static func of(_ c: Composition) -> KeyArtScreen {
        if c.keyArt.blind { return .smooth }
        return switch c.edition.movement {
        // The enlarged halftone of a Swiss photographic poster, at the printer's 45°.
        case .swiss: .dots(degrees: 45, size: 2.6)
        // The rules run up the movement's own diagonal.
        case .constructivist: .lines(degrees: c.diagonal ?? -20, size: 2.2)
        // Rings about the hero's centre, as the sunburst radiates from it.
        case .deco: .rings(size: 2.2)
        case .cutout: .cut
        // The risograph's coarse dot, at its drum's 15°.
        case .riso: .dots(degrees: 15, size: 3)
        // A cut in a playbill was engraved.
        case .letterpress: .hatch(degrees: 45, size: 2.2)
        case .blueprint: .hatch(degrees: 30, size: 1.8)
        // Light through a venetian blind.
        case .noir: .lines(degrees: 0, size: 3.4)
        }
    }
}

extension Composition {
    /// The angle of the movement's first turned block, in degrees as SwiftUI turns them: the constructivist diagonal.
    var diagonal: Double? {
        poster.first { $0.plate != .type && $0.turn.map { abs($0.degrees) > 3 } == true }?.turn?.degrees
    }
}

/// The key art as printed, one image a card: the poster cropped to the window, at the window's size and three pixels to
/// the point, and put through its movement's screen. Made off the main thread, and kept up to 48 MB, the prints seen
/// longest ago let go first; a card that comes back makes its print again.
@MainActor @Observable
final class KeyArtPrints {
    static let shared = KeyArtPrints()
    nonisolated static let budget = 48 * 1024 * 1024

    private var made: [String: UIImage] = [:]
    @ObservationIgnored private var seen: [String] = []
    @ObservationIgnored private var bytes = 0
    @ObservationIgnored private var making: Set<String> = []
    /// Core Image's context, shared: it is thread-safe and costly to make.
    nonisolated private static let context = CIContext()

    static func key(_ c: Composition, screen: KeyArtScreen) -> String {
        let b = c.keyArt.bounds
        return "\(c.edition.release)|\(screen)|\(c.keyArt.kind)|\(Int(b.minX)),\(Int(b.minY)),\(Int(b.width)),\(Int(b.height))"
    }

    func image(for key: String) -> UIImage? {
        guard let image = made[key] else { return nil }
        // Seen now: the last to be let go.
        if seen.last != key { seen.removeAll { $0 == key }; seen.append(key) }
        return image
    }

    func make(_ key: String, release: String, window: CGRect, screen: KeyArtScreen, centre: CGPoint?) async {
        guard made[key] == nil, !making.contains(key) else { return }
        making.insert(key)
        defer { making.remove(key) }
        guard let poster = await Posters.shared.poster(for: release), let source = poster.image.cgImage else { return }
        let frame = KeyArt.frame(for: poster, in: window)
        let image = await Task.detached(priority: .utility) {
            Self.printed(source, frame: frame, window: window, screen: screen, centre: centre)
        }.value
        guard let image else { return }
        made[key] = image
        seen.append(key)
        bytes += Self.cost(image)
        while bytes > Self.budget, let oldest = seen.first, oldest != key {
            seen.removeFirst()
            if let gone = made.removeValue(forKey: oldest) { bytes -= Self.cost(gone) }
        }
    }

    /// A print's weight: one byte a pixel.
    private static func cost(_ image: UIImage) -> Int { image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0 }

    /// Everything made, for when the posters are forgotten.
    func forgetAll() {
        made.removeAll()
        seen.removeAll()
        bytes = 0
    }

    /// The window's part of the poster, at the window's size, through the screen. Dark where ink goes.
    nonisolated static func printed(_ source: CGImage, frame: CGRect, window: CGRect, screen: KeyArtScreen,
                                    centre: CGPoint? = nil) -> UIImage? {
        guard frame.width > 0, frame.height > 0, window.width > 0, window.height > 0 else { return nil }
        // Three pixels to the point, held under 1400 on the long side.
        let density = min(3, 1400 / max(window.width, window.height))
        let out = CGSize(width: (window.width * density).rounded(), height: (window.height * density).rounded())
        let w = CGFloat(source.width), h = CGFloat(source.height)
        // The poster's pixels per card point, and where the window falls in them; Core Image counts from the foot.
        let k = w / frame.width
        let crop = CGRect(x: (window.minX - frame.minX) * k, y: h - (window.maxY - frame.minY) * k,
                          width: window.width * k, height: window.height * k)
        var image = CIImage(cgImage: source).clampedToExtent().cropped(to: crop)
            .transformed(by: CGAffineTransform(translationX: -crop.minX, y: -crop.minY))
            .transformed(by: CGAffineTransform(scaleX: out.width / crop.width, y: out.height / crop.height))
        let tone = CIFilter.colorControls()
        tone.inputImage = image
        tone.saturation = 0
        tone.contrast = screen == .smooth ? 1.6 : 1.25
        image = tone.outputImage ?? image
        // The screen's centre in the print's pixels, from the foot: the window's middle, or where the window says.
        let centre = centre.map { CGPoint(x: ($0.x - window.minX) * density, y: (window.maxY - $0.y) * density) }
            ?? CGPoint(x: out.width / 2, y: out.height / 2)
        // Core Image turns counter-clockwise from the foot; SwiftUI turns clockwise from the top.
        func radians(_ degrees: Double) -> Float { Float(-degrees * .pi / 180) }
        switch screen {
        case .dots(let degrees, let size):
            let f = CIFilter.dotScreen()
            f.inputImage = image; f.center = centre; f.angle = radians(degrees); f.width = Float(size * density); f.sharpness = 0.7
            image = f.outputImage ?? image
        case .lines(let degrees, let size):
            let f = CIFilter.lineScreen()
            f.inputImage = image; f.center = centre; f.angle = radians(degrees); f.width = Float(size * density); f.sharpness = 0.7
            image = f.outputImage ?? image
        case .rings(let size):
            let f = CIFilter.circularScreen()
            f.inputImage = image; f.center = centre; f.width = Float(size * density); f.sharpness = 0.7
            image = f.outputImage ?? image
        case .hatch(let degrees, let size):
            let f = CIFilter.hatchedScreen()
            f.inputImage = image; f.center = centre; f.angle = radians(degrees); f.width = Float(size * density); f.sharpness = 0.7
            image = f.outputImage ?? image
        case .cut:
            // Softened first, so the edges are the scissors' and not the pixels'.
            let soft = image.clampedToExtent().applyingGaussianBlur(sigma: Double(density) * 1.2).cropped(to: image.extent)
            let f = CIFilter.colorThreshold()
            f.inputImage = soft; f.threshold = 0.42
            image = f.outputImage ?? image
        case .smooth:
            image = image.clampedToExtent().applyingGaussianBlur(sigma: Double(density) * 0.6).cropped(to: image.extent)
        }
        let extent = CGRect(origin: .zero, size: out)
        guard let cg = context.createCGImage(image.cropped(to: extent), from: extent, format: .L8,
                                             colorSpace: CGColorSpaceCreateDeviceGray()) else { return nil }
        return UIImage(cgImage: cg)
    }
}

/// A path in card points as a shape the size of the card.
private struct WindowShape: Shape {
    let path: Path
    func path(in rect: CGRect) -> Path { path }
}
