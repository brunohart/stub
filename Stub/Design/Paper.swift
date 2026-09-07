import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

/// Parchment with grain. The substrate every stub is printed onto.
///
/// The look is specified here, not in the implementation (ADR-002). `LookEngine` picks who draws it:
/// the Metal shaders in `Shaders/Silkscreen.metal` (default from Day 1) or SwiftUI blend modes plus a
/// Core Image noise plate (Day 0, kept as the fallback and for side-by-side screenshots).
struct Paper: View {
    var grain: Double = 0.06
    var body: some View {
        Group {
            if LookEngine.current.isMetal {
                Rectangle()
                    .fill(Ink.paper)
                    .colorEffect(ShaderLibrary.paper(.float(grain), .float(1)))
            } else {
                ZStack {
                    Ink.paper
                    Grain(opacity: grain)
                }
            }
        }
        .ignoresSafeArea()
    }
}

/// A tiled monochrome noise plate. Generated once per process, on device, from CIRandomGenerator.
/// The SwiftUI engine's grain; the Metal engine hashes its own per pixel.
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

/// The silkscreen pass as a modifier. Animatable on `strength`, so the print lifts and settles with a spring
/// on either engine.
struct Silkscreen: ViewModifier, @MainActor Animatable {
    var strength: Double
    var grain: Double
    var seed: Double

    var animatableData: Double {
        get { strength }
        set { strength = newValue }
    }

    func body(content: Content) -> some View {
        if LookEngine.current.isMetal {
            content
                .colorEffect(ShaderLibrary.silkscreen(
                    .color(Ink.paper), .float(strength), .float(grain), .float(seed)
                ))
        } else {
            content
                .saturation(1 - 0.18 * strength)
                .contrast(1 + 0.08 * strength)
                .overlay(Ink.paper.opacity(0.55 * strength).blendMode(.multiply))
                .overlay(Grain(opacity: grain * strength))
                .compositingGroup()
        }
    }
}

extension View {
    /// Print this view onto the parchment. `strength` 1 = fully printed, 0 = the original photograph.
    /// Desaturate a little, add a breath of contrast, multiply against the paper so it shows through, then grain.
    func silkscreened(strength: Double, grain: Double = 0.08, seed: Double = 1) -> some View {
        modifier(Silkscreen(strength: strength, grain: grain, seed: seed))
    }
}
