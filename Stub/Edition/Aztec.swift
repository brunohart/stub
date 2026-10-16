import CoreImage
import CoreImage.CIFilterBuiltins
import CoreGraphics

/// The code on the back of an edition. Real tickets carry one; this one encodes exactly what the strip prints,
/// one field a line (`Copy.message`), so a scanner reads the same stub a person does. Nothing it says is new.
///
/// Made off the main thread (`made(for:)`): the first CoreImage filter of a session loads CoreImage's whole filter registry,
/// and doing that as the press appeared cost the tap on Keep about 80 ms (docs/decisions/004-budgets.md).
enum Aztec {
    /// One context for every code: a context is expensive to make and safe to share.
    private static let context = CIContext(options: [.useSoftwareRenderer: false])

    /// The mask, made on a background thread and handed back.
    static func made(for message: String) async -> CGImage? {
        await Task.detached(priority: .userInitiated) { mask(for: message) }.value
    }

    /// CoreImage's filter registry loaded once, at launch, in the background, so no screen pays for it.
    static func prewarm() {
        Task.detached(priority: .utility) { _ = mask(for: "Stub") }
    }

    /// The code as a mask: opaque modules on clear, one pixel a module, to be tinted and drawn without smoothing.
    static func mask(for message: String) -> CGImage? {
        let code = CIFilter.aztecCodeGenerator()
        code.message = Data(message.utf8)
        code.correctionLevel = 23
        // Black on white out of the generator; white on black, then black made clear.
        guard let printed = code.outputImage else { return nil }
        let invert = CIFilter.colorInvert()
        invert.inputImage = printed
        let mask = CIFilter.maskToAlpha()
        mask.inputImage = invert.outputImage
        guard let out = mask.outputImage else { return nil }
        return context.createCGImage(out, from: out.extent)
    }
}
