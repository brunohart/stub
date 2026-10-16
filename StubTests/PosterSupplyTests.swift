import Testing
import Foundation
import ImageIO
import UniformTypeIdentifiers
@testable import Stub

/// The cinema's poster (ADR-050): what Stub agrees to download, and what it keeps of it.
@Suite(.serialized)
struct PosterSupplyTests {
    // MARK: What is kept

    /// A JPEG of `width` × `height`, with a place in its metadata.
    private func image(_ width: Int, _ height: Int, type: UTType = .jpeg, located: Bool = true) -> Data {
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        context.setFillColor(CGColor(red: 0.2, green: 0.3, blue: 0.5, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(CGColor(red: 0.9, green: 0.8, blue: 0.6, alpha: 1))
        context.fillEllipse(in: CGRect(x: width / 4, y: height / 3, width: width / 2, height: width / 2))
        let out = NSMutableData()
        let destination = CGImageDestinationCreateWithData(out, type.identifier as CFString, 1, nil)!
        let gps: [CFString: Any] = [kCGImagePropertyGPSLatitude: 36.85, kCGImagePropertyGPSLatitudeRef: "S",
                                    kCGImagePropertyGPSLongitude: 174.76, kCGImagePropertyGPSLongitudeRef: "E"]
        CGImageDestinationAddImage(destination, context.makeImage()!,
                                   (located ? [kCGImagePropertyGPSDictionary: gps] : [:]) as CFDictionary)
        CGImageDestinationFinalize(destination)
        return out as Data
    }

    @Test func aPosterIsKeptAsAPlainJPEG() throws {
        let kept = try #require(Posters.sanitised(image(1400, 2100)))
        let source = try #require(CGImageSourceCreateWithData(kept as CFData, nil))
        #expect(CGImageSourceGetType(source) as String? == UTType.jpeg.identifier)
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        #expect(properties[kCGImagePropertyGPSDictionary] == nil, "the place in the download's metadata is not kept")
        let w = try #require(properties[kCGImagePropertyPixelWidth] as? Int)
        let h = try #require(properties[kCGImagePropertyPixelHeight] as? Int)
        #expect(max(w, h) == 900, "kept at 900 pixels on its long side, not \(w) × \(h)")
        #expect(kept.count <= 400_000, "small enough to ride in the ledger: \(kept.count) bytes")
    }

    @Test func aPNGPosterIsKeptToo() {
        #expect(Posters.sanitised(image(600, 900, type: .png, located: false)) != nil)
    }

    /// A pixel (a beacon), a banner, a page: not posters.
    @Test func whatIsNotAPosterIsNotKept() {
        #expect(Posters.sanitised(image(1, 1)) == nil, "a tracking pixel")
        #expect(Posters.sanitised(image(200, 300)) == nil, "too small to print")
        #expect(Posters.sanitised(image(1600, 400)) == nil, "a banner")
        #expect(Posters.sanitised(Data("<html>not an image</html>".utf8)) == nil, "a page")
        #expect(Posters.sanitised(Data()) == nil)
    }

    /// The stand-in poster the screenshots use comes through whole.
    @Test func theStandInIsAPoster() throws {
        let url = try #require(Bundle.main.url(forResource: "poster-orchard", withExtension: "jpg"))
        #expect(Posters.sanitised(try Data(contentsOf: url)) != nil)
    }

    // MARK: What is downloaded

    private func session(status: Int, type: String, body: Data, length: Int? = nil) -> URLSession {
        Served.response = (status, type, body, length)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [Served.self]
        return URLSession(configuration: configuration)
    }

    private let address = URL(string: "https://cdn.kestrelpictures.co.nz/posters/glass-harbour.jpg")!

    @Test func anImageIsDownloaded() async throws {
        let body = image(600, 900)
        let data = try await Posters.download(address, session: session(status: 200, type: "image/jpeg", body: body))
        #expect(data == body)
        #expect(Served.lastRequest?.httpShouldHandleCookies == false)
    }

    @Test func aPageIsNotDownloaded() async throws {
        let data = try await Posters.download(address, session: session(status: 200, type: "text/html", body: Data("<html>".utf8)))
        #expect(data == nil)
    }

    @Test func aMissingPosterIsNotDownloaded() async throws {
        let data = try await Posters.download(address, session: session(status: 404, type: "image/jpeg", body: Data()))
        #expect(data == nil)
    }

    @Test func aHugeFileIsNotDownloaded() async throws {
        let body = Data(count: Posters.largest + 1)
        let said = try await Posters.download(address, session: session(status: 200, type: "image/jpeg", body: body,
                                                                          length: body.count))
        #expect(said == nil, "refused by its length")
        let unsaid = try await Posters.download(address, session: session(status: 200, type: "image/jpeg", body: body))
        #expect(unsaid == nil, "refused as it arrives")
    }

    @Test func onlyAPublicAddressIsAsked() async throws {
        Served.lastRequest = nil
        let local = URL(string: "https://printer.local/p.jpg")!
        let data = try await Posters.download(local, session: session(status: 200, type: "image/jpeg", body: image(600, 900)))
        #expect(data == nil)
        #expect(Served.lastRequest == nil, "nothing was asked")
    }
}

/// A server that answers every request with one response, so a download can be tested without the network.
final class Served: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var response: (status: Int, type: String, body: Data, length: Int?) = (200, "image/jpeg", Data(), nil)
    nonisolated(unsafe) static var lastRequest: URLRequest?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lastRequest = request
        var headers = ["Content-Type": Self.response.type]
        if let length = Self.response.length { headers["Content-Length"] = String(length) }
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.response.status, httpVersion: "HTTP/1.1",
                                       headerFields: headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.response.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
