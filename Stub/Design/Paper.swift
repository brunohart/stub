import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

/// Parchment with grain. The substrate every stub is printed onto.
///
/// Day 0 implementation: SwiftUI blend modes and a Core Image noise plate.
/// The Metal versions live in `Shaders/Silkscreen.metal` and take over once the toolchain is installed
/// (see DECISIONS.md, ADR-002). The look is specified here, not in the implementation.
struct Paper: View {
    var grain: Double = 0.06
    var body: some View {
        ZStack {
            Ink.paper
            Grain(opacity: grain)
        }
        .ignoresSafeArea()
    }
}

/// A tiled monochrome noise plate. Generated once per process, on device, from CIRandomGenerator.
struct Grain: View {
    var opacity: Double
    var body: some View {
        if let image = GrainPlate.shared {
            Image(uiImage: image)
                .resizable(resizingMode: .tile)
                .opacity(opacity)
                .blendMode(.multiply)
                .allowsHitTesting(false)
        }
    }
}

enum GrainPlate {
    static let shared: UIImage? = {
        let context = CIContext(options: [.useSoftwareRenderer: false])
        let noise = CIFilter.randomGenerator().outputImage!
        let mono = CIFilter.colorControls()
        mono.inputImage = noise
        mono.saturation = 0
        mono.contrast = 1.4
        mono.brightness = 0.35
        guard let out = mono.outputImage?.cropped(to: CGRect(x: 0, y: 0, width: 256, height: 256)),
              let cg = context.createCGImage(out, from: out.extent) else { return nil }
        return UIImage(cgImage: cg)
    }()
}

extension View {
    /// Print this view onto the parchment. `strength` 1 = fully printed, 0 = the original photograph.
    /// Desaturate a little, add a breath of contrast, multiply against the paper so it shows through, then grain.
    func silkscreened(strength: Double, grain: Double = 0.08, seed: Double = 1) -> some View {
        self
            .saturation(1 - 0.18 * strength)
            .contrast(1 + 0.08 * strength)
            .overlay(Ink.paper.opacity(0.55 * strength).blendMode(.multiply))
            .overlay(Grain(opacity: grain * strength))
            .compositingGroup()
    }
}
