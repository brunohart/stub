import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

/// Parchment, flat. The substrate every stub is printed onto. No grain: noise laid over an app's surface reads as
/// fake, and the parchment is warm enough as a colour (ADR-017).
struct Paper: View {
    var body: some View {
        Ink.paper.ignoresSafeArea()
    }
}

/// The silkscreen pass as a modifier. Animatable on `strength`, so the print lifts and settles with a spring
/// on either engine.
struct Silkscreen: ViewModifier, @MainActor Animatable {
    var strength: Double

    var animatableData: Double {
        get { strength }
        set { strength = newValue }
    }

    func body(content: Content) -> some View {
        if LookEngine.current.isMetal {
            content
                .colorEffect(ShaderLibrary.silkscreen(.color(Ink.paper), .float(strength)))
        } else {
            content
                .saturation(1 - 0.18 * strength)
                .contrast(1 + 0.08 * strength)
                // The closure form: the iOS 27 SDK finds `.overlay(_:)`'s view and shape-style overloads equally good here.
                .overlay { Ink.paper.opacity(0.55 * strength).blendMode(.multiply) }
                .compositingGroup()
        }
    }
}

extension View {
    /// Print this view onto the parchment. `strength` 1 = fully printed, 0 = the original photograph.
    /// Desaturate a little, add a breath of contrast, and multiply against the paper so it shows through.
    func silkscreened(strength: Double) -> some View {
        modifier(Silkscreen(strength: strength))
    }
}
