import CoreImage
import CoreImage.CIFilterBuiltins
import CoreGraphics

/// The code on the back of an edition. Real tickets carry one; this one encodes exactly what the strip prints,
/// one field a line (`Copy.message`), so a scanner reads the same stub a person does. Nothing it says is new.
enum Aztec {
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
        return CIContext(options: [.useSoftwareRenderer: false]).createCGImage(out, from: out.extent)
    }
}
