import SwiftUI
import RealityKit
import Metal
import OSLog

/// The card as a thing in a room (ADR-018). Sixty-four by a hundred and two millimetres, four tenths of one thick, its
/// corners rounded and its perforation, notches and punches cut through: `TicketShape`, extruded. The edition is printed
/// on its face and the stub as scanned on its back, and the room's light falls on both. Nothing here is the phone's
/// light: RealityKit's physically based material reads maps drawn once from the same composition the detail draws.
///
/// - base colour: the card printed unlit (`editionLit` false), so the inks are the inks and nothing is lit twice;
/// - metallic: the foil's shape, where the stock carries foil;
/// - roughness: the stock's (cotton rough, coated card satin), and the foil smooth;
/// - normal: the inks as a height field, the same height `relief` presses them to (`edition_height`), computed once;
/// - opacity: the card's own alpha, cut at a half, so the perforation and the punches are holes.
///
/// Holographic film gets `holographic` in `Room.metal`, the thin film of `foil` looked at from the real view direction.
@MainActor
enum RoomCard {
    static let log = Logger(subsystem: "com.designedbybruno.stub", category: "room")

    /// Metres a card point: the card is 64 mm across.
    static let metres: Float = 0.064 / Float(Card.width)
    /// The card's thickness, in metres.
    static let thickness: Float = 0.0004
    /// Pixels a card point in the maps: about ten a millimetre, sharper than a phone held a foot from a table can see.
    nonisolated static let scale: CGFloat = 2.5

    /// The maps for the card's two faces, drawn by `ImageRenderer` from views and composition.
    struct Maps {
        var front: CGImage
        var back: CGImage
        /// White where the foil is stamped, on black; `nil` when the stock carries none.
        var foil: CGImage?
        /// The plates without the stock, for the height field.
        var inks: CGImage
    }

    /// The card, built: the edge, the face and the back, one entity lying flat with its face up and its top edge away.
    static func entity(for composition: Composition, back: some View) async throws -> ModelEntity {
        let started = ContinuousClock.now
        let maps = try draw(composition, back: back)
        let stock = composition.edition.stock
        let depth = stock.depth * (composition.edition.movement == .letterpress ? 1.6 : 1)
        let reach = stock.reach
        // The pixel work is arithmetic on bytes: off the main actor.
        let (normal, roughness, frontCut, backCut) = await Task.detached(priority: .userInitiated) {
            let inks = Pixels(maps.inks)
            let foil = maps.foil.map(Pixels.init)
            return (Self.normalMap(inks, depth: depth, reach: reach),
                    Self.roughnessMap(foil, stock: stock, width: inks.width, height: inks.height),
                    Self.alphaMask(Pixels(maps.front)), Self.alphaMask(Pixels(maps.back)))
        }.value
        guard let normal, let roughness, let frontCut, let backCut else { throw RoomError.maps }

        let card = ModelEntity()
        card.name = "card"
        let w = Float(Card.width) * metres, h = Float(Card.height) * metres

        // The edge: the ticket's outline, holes and all, extruded to the card's thickness, in the paper's own colour.
        let outline = TicketShape(punches: composition.punches)
            .path(in: CGRect(origin: .zero, size: Card.size))
            .applying(CGAffineTransform(scaleX: CGFloat(metres), y: -CGFloat(metres)))
        var options = MeshResource.ShapeExtrusionOptions()
        options.extrusionMethod = .linear(depth: thickness)
        let body = try await MeshResource(extruding: outline, extrusionOptions: options)
        let edge = ModelEntity(mesh: body, materials: [edgeMaterial(composition)])
        edge.name = "edge"
        // Centred on the entity, whatever the extrusion's own origin.
        let bounds = body.bounds
        edge.position = -bounds.center

        let face = ModelEntity(mesh: .generatePlane(width: w, height: h), materials: [
            try frontMaterial(composition, maps: maps, normal: normal, roughness: roughness, cut: frontCut),
        ])
        face.name = "face"
        face.position = [0, 0, thickness / 2 + 0.00002]

        let reverse = ModelEntity(mesh: .generatePlane(width: w, height: h), materials: [try backMaterial(stock, maps: maps, cut: backCut)])
        reverse.name = "back"
        reverse.position = [0, 0, -thickness / 2 - 0.00002]
        // Turned over about the long axis, as the card is: the back's holes are drawn mirrored, so they meet the face's.
        reverse.orientation = simd_quatf(angle: .pi, axis: [0, 1, 0])

        let flat = Entity()
        flat.addChild(edge)
        flat.addChild(face)
        flat.addChild(reverse)
        // Face up, lying on the table, the top of the poster away from whoever is looking down at it.
        flat.orientation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
        flat.position = [0, thickness / 2, 0]
        card.addChild(flat)
        card.collision = CollisionComponent(shapes: [.generateBox(width: w, height: thickness * 4, depth: h)])
        let ms = (ContinuousClock.now - started) / .milliseconds(1)
        log.info("Room: '\(composition.edition.release)' cut in \(Int(ms)) ms, \(maps.front.width)×\(maps.front.height) maps, \(composition.edition.stock.rawValue)")
        return card
    }

    enum RoomError: Error { case render, maps }

    /// The maps, drawn on the main actor where `ImageRenderer` lives.
    static func draw(_ c: Composition, back: some View) throws -> Maps {
        func render(_ view: some View, opaque: Bool = false) throws -> CGImage {
            let renderer = ImageRenderer(content: view.frame(width: Card.width, height: Card.height))
            renderer.scale = scale
            renderer.isOpaque = opaque
            guard let image = renderer.cgImage else { throw RoomError.render }
            return image
        }
        let printer = Printer(composition: c)
        return Maps(
            front: try render(EditionFace(composition: c).environment(\.editionLit, false)),
            back: try render(back.environment(\.editionLit, false)),
            foil: c.isMetallic
                ? try render(Canvas { context, _ in printer.foil(into: context) }.background(Color.black), opaque: true)
                : nil,
            inks: try render(Canvas { context, _ in printer.inks(into: context, plates: .first ... .type) })
        )
    }

    // MARK: - Materials

    private static func frontMaterial(_ c: Composition, maps: Maps, normal: CGImage, roughness: CGImage, cut: CGImage) throws -> any RealityKit.Material {
        var pbr = PhysicallyBasedMaterial()
        pbr.baseColor = .init(texture: .init(try TextureResource(image: maps.front, options: .init(semantic: .color))))
        pbr.normal = .init(texture: .init(try TextureResource(image: normal, options: .init(semantic: .normal))))
        pbr.roughness = .init(texture: .init(try TextureResource(image: roughness, options: .init(semantic: .scalar))))
        if let foil = maps.foil {
            pbr.metallic = .init(texture: .init(try TextureResource(image: foil, options: .init(semantic: .scalar))))
        } else {
            pbr.metallic = .init(floatLiteral: 0)
        }
        pbr.blending = .transparent(opacity: .init(texture: .init(try TextureResource(image: cut, options: .init(semantic: .scalar)))))
        pbr.opacityThreshold = 0.5
        if c.edition.stock != .cotton { pbr.clearcoat = 0.25; pbr.clearcoatRoughness = 0.35 }
        guard c.edition.stock == .holographic else { return pbr }
        // The thin film, looked at from where the viewer really is. If the renderer cannot take a custom surface (the
        // simulator's cannot), the film is printed as its metal and the card is still whole.
        do {
            guard let library = MTLCreateSystemDefaultDevice()?.makeDefaultLibrary() else { throw RoomError.maps }
            return try CustomMaterial(from: pbr, surfaceShader: .init(named: "holographic", in: library))
        } catch {
            log.notice("Room: holographic film printed as its metal; \(error.localizedDescription)")
            return pbr
        }
    }

    private static func backMaterial(_ stock: Stock, maps: Maps, cut: CGImage) throws -> PhysicallyBasedMaterial {
        var pbr = PhysicallyBasedMaterial()
        pbr.baseColor = .init(texture: .init(try TextureResource(image: maps.back, options: .init(semantic: .color))))
        pbr.roughness = .init(floatLiteral: stock == .cotton ? 0.92 : 0.55)
        pbr.metallic = .init(floatLiteral: 0)
        pbr.blending = .transparent(opacity: .init(texture: .init(try TextureResource(image: cut, options: .init(semantic: .scalar)))))
        pbr.opacityThreshold = 0.5
        return pbr
    }

    /// The cut edge is the paper's core: the ground, a little darker, never an ink.
    private static func edgeMaterial(_ c: Composition) -> PhysicallyBasedMaterial {
        var pbr = PhysicallyBasedMaterial()
        let ground = c.inks.groundIsLight ? c.inks.ground : c.inks.hex(.light)
        pbr.baseColor = .init(tint: UIColor(Color(hex: EditionInks.mix(ground, 0x000000, 0.18))))
        pbr.roughness = 0.9
        pbr.metallic = .init(floatLiteral: 0)
        return pbr
    }

    // MARK: - Maps from pixels

    /// The inks as a height field, lit by nobody: a tangent-space normal map, +y up. The height of a pixel is the one
    /// `edition_height` gives it (ink pressed in, darker ink a little further), and the walls are `reach` points wide.
    nonisolated static func normalMap(_ inks: Pixels, depth: Double, reach: Double) -> CGImage? {
        let r = max(1, Int((reach * Double(scale)).rounded()))
        let w = inks.width, h = inks.height
        // Every height once, then the walls from them: a million pixels, twice, not four reads a pixel.
        var heights = [Float](repeating: 0, count: w * h)
        inks.bytes.withUnsafeBufferPointer { px in
            heights.withUnsafeMutableBufferPointer { out in
                for i in 0..<(w * h) {
                    let luma = 0.299 * Float(px[i * 4]) + 0.587 * Float(px[i * 4 + 1]) + 0.114 * Float(px[i * 4 + 2])
                    out[i] = (Float(px[i * 4 + 3]) - 0.6 * luma) / 255
                }
            }
        }
        var bytes = [UInt8](repeating: 255, count: w * h * 4)
        let d = Float(depth), z = Float(2 * reach)
        heights.withUnsafeBufferPointer { hs in
            bytes.withUnsafeMutableBufferPointer { out in
                for y in 0..<h {
                    let up = max(y - r, 0) * w, down = min(y + r, h - 1) * w, row = y * w
                    for x in 0..<w {
                        let dx = (hs[row + min(x + r, w - 1)] - hs[row + max(x - r, 0)]) * d
                        let dy = (hs[down + x] - hs[up + x]) * d
                        // Pressed in: (depth · dh/dx, depth · dh/dy, 2 · reach) with y down, as `relief` has it; the map's y is up.
                        let length = (dx * dx + dy * dy + z * z).squareRoot()
                        let i = (row + x) * 4
                        out[i] = UInt8((dx / length * 0.5 + 0.5) * 255)
                        out[i + 1] = UInt8((-dy / length * 0.5 + 0.5) * 255)
                        out[i + 2] = UInt8((z / length * 0.5 + 0.5) * 255)
                    }
                }
            }
        }
        return Pixels.image(bytes, width: w, height: h)
    }

    /// How rough each pixel is: the stock's, and the foil's where it is stamped.
    nonisolated static func roughnessMap(_ foil: Pixels?, stock: Stock, width: Int, height: Int) -> CGImage? {
        let paper: Float = switch stock {
        case .cotton: 0.92
        case .coated: 0.5
        case .foil, .holographic: 0.46
        }
        let metal: Float = stock == .holographic ? 0.12 : 0.24
        guard let foil, foil.width == width, foil.height == height else {
            return Pixels.image([UInt8](repeating: UInt8(paper * 255), count: width * height * 4), width: width, height: height)
        }
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        foil.bytes.withUnsafeBufferPointer { px in
            bytes.withUnsafeMutableBufferPointer { out in
                for i in 0..<(width * height) {
                    let v = UInt8((paper + (metal - paper) * Float(px[i * 4]) / 255) * 255)
                    out[i * 4] = v; out[i * 4 + 1] = v; out[i * 4 + 2] = v
                }
            }
        }
        return Pixels.image(bytes, width: width, height: height)
    }

    /// The card's own alpha as a grey map: white where there is card, black in the holes and past the corners.
    nonisolated static func alphaMask(_ face: Pixels) -> CGImage? {
        var bytes = [UInt8](repeating: 255, count: face.width * face.height * 4)
        face.bytes.withUnsafeBufferPointer { px in
            bytes.withUnsafeMutableBufferPointer { out in
                for i in 0..<(face.width * face.height) {
                    let a = px[i * 4 + 3]
                    out[i * 4] = a; out[i * 4 + 1] = a; out[i * 4 + 2] = a
                }
            }
        }
        return Pixels.image(bytes, width: face.width, height: face.height)
    }
}

/// An image's bytes, RGBA, eight bits a channel, premultiplied, as SwiftUI's shaders see a layer.
struct Pixels: Sendable {
    let width: Int
    let height: Int
    let bytes: [UInt8]

    init(_ image: CGImage) {
        let w = image.width, h = image.height
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        bytes.withUnsafeMutableBytes { buffer in
            let context = CGContext(data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8,
                                    bytesPerRow: w * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            context?.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        width = w
        height = h
        self.bytes = bytes
    }

    /// Red, green, blue and alpha at a pixel, 0 to 1, with (0, 0) the top left.
    func rgba(_ x: Int, _ y: Int) -> (Double, Double, Double, Double) {
        let i = (y * width + x) * 4
        return (Double(bytes[i]) / 255, Double(bytes[i + 1]) / 255, Double(bytes[i + 2]) / 255, Double(bytes[i + 3]) / 255)
    }

    static func image(_ bytes: [UInt8], width: Int, height: Int) -> CGImage? {
        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                       space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }
}
