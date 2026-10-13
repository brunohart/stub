import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
#if canImport(PDFKit)
import PDFKit
#endif

/// The first page of a PDF e-ticket, drawn as a picture for the reader and the plate (BEDIP-218). White under the page, as
/// paper is, at two pixels a point up to `longest` on the long side: enough for Vision to read 8-point type.
enum PageImage {
    static let longest: CGFloat = 2400

    static func firstPage(of pdf: Data) -> CGImage? {
        guard let provider = CGDataProvider(data: pdf as CFData), let document = CGPDFDocument(provider),
              document.numberOfPages >= 1, let page = document.page(at: 1) else { return nil }
        let box = page.getBoxRect(.cropBox)
        guard box.width > 0, box.height > 0 else { return nil }
        // A page turned in its own dictionary is drawn the way it reads.
        let turned = page.rotationAngle % 180 != 0
        let size = turned ? CGSize(width: box.height, height: box.width) : box.size
        let scale = min(2, longest / max(size.width, size.height))
        let width = Int(size.width * scale), height = Int(size.height * scale)
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .high
        let target = CGRect(x: 0, y: 0, width: width, height: height)
        context.concatenate(page.getDrawingTransform(.cropBox, rect: target, rotate: 0, preserveAspectRatio: true))
        context.drawPDFPage(page)
        return context.makeImage()
    }

    /// The first page's own text, a line at a time, when the PDF has any. An e-ticket from a booking system is set in real
    /// type, so it is read as written, like a pass's fields, and no OCR guesses at its small print. A scanned PDF has none,
    /// and is read from its picture instead.
    static func text(of pdf: Data) -> [String] {
        #if canImport(PDFKit)
        guard let document = PDFDocument(data: pdf), let page = document.page(at: 0), let string = page.string else { return [] }
        return string.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        #else
        return []
        #endif
    }

    /// The page as JPEG, for the inbox and the plate.
    static func jpeg(_ image: CGImage, quality: Double = 0.86) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}
