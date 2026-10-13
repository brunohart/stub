import Foundation
import Compression

/// Just enough of ZIP to open a Wallet pass (a `.pkpass` is a zip of `pass.json`, its images and a signature): the
/// central directory, stored and deflated entries, nothing else. No ZIP64, no encryption, no spanning; a pass is a few
/// hundred kilobytes. Every size is checked before anything is allocated, so a hostile file is refused rather than
/// believed (ADR-023).
struct Zip {
    struct Entry: Equatable {
        var name: String
        var method: UInt16
        var compressedSize: Int
        var size: Int
        var localHeader: Int
    }

    enum Failure: Error, Equatable { case notAZip, truncated, unsupported(String), tooLarge, corrupt(String) }

    /// No entry may claim to be larger than this, and no archive may hold more entries.
    static let largestEntry = 16 << 20
    static let mostEntries = 512

    let data: Data
    let entries: [Entry]

    init(_ data: Data) throws {
        // A copy that starts at zero: a slice's indices would put every offset below in the wrong place.
        let bytes = Data(data)
        self.data = bytes
        entries = try Self.directory(bytes)
    }

    /// The names in the archive, as stored.
    var names: [String] { entries.map(\.name) }

    /// An entry's bytes, inflated. `nil` when there is no such entry.
    func read(_ name: String) throws -> Data? {
        guard let entry = entries.first(where: { $0.name == name }) else { return nil }
        return try read(entry)
    }

    func read(_ entry: Entry) throws -> Data {
        let local = entry.localHeader
        guard local + 30 <= data.count, Self.u32(data, local) == 0x04034b50 else { throw Failure.corrupt("local header of \(entry.name)") }
        let nameLength = Int(Self.u16(data, local + 26)), extraLength = Int(Self.u16(data, local + 28))
        let start = local + 30 + nameLength + extraLength
        guard start >= 0, start + entry.compressedSize <= data.count else { throw Failure.truncated }
        let raw = data.subdata(in: start..<(start + entry.compressedSize))
        switch entry.method {
        case 0:
            guard raw.count == entry.size else { throw Failure.corrupt("stored size of \(entry.name)") }
            return raw
        case 8:
            return try Self.inflate(raw, size: entry.size)
        default:
            throw Failure.unsupported("method \(entry.method) for \(entry.name)")
        }
    }

    // MARK: Reading the directory

    private static func directory(_ data: Data) throws -> [Entry] {
        // The end-of-central-directory record is the last 22 bytes, or before a comment of up to 64 KB.
        guard data.count >= 22 else { throw Failure.notAZip }
        var end = -1
        let earliest = max(0, data.count - 22 - 0xFFFF)
        var i = data.count - 22
        while i >= earliest {
            if u32(data, i) == 0x06054b50 { end = i; break }
            i -= 1
        }
        guard end >= 0 else { throw Failure.notAZip }
        let count = Int(u16(data, end + 10))
        let size = Int(u32(data, end + 12)), offset = Int(u32(data, end + 16))
        guard count <= mostEntries else { throw Failure.tooLarge }
        guard offset + size <= end else { throw Failure.truncated }
        var entries: [Entry] = []
        var at = offset
        for _ in 0..<count {
            guard at + 46 <= end, u32(data, at) == 0x02014b50 else { throw Failure.corrupt("central directory") }
            let flags = u16(data, at + 8)
            if flags & 0x1 != 0 { throw Failure.unsupported("encryption") }
            let method = u16(data, at + 10)
            let compressed = Int(u32(data, at + 20)), uncompressed = Int(u32(data, at + 24))
            let nameLength = Int(u16(data, at + 28)), extraLength = Int(u16(data, at + 30)), commentLength = Int(u16(data, at + 32))
            let local = Int(u32(data, at + 42))
            guard compressed != 0xFFFFFFFF, uncompressed != 0xFFFFFFFF else { throw Failure.unsupported("ZIP64") }
            guard uncompressed <= largestEntry, compressed <= largestEntry else { throw Failure.tooLarge }
            guard at + 46 + nameLength <= end else { throw Failure.truncated }
            let nameBytes = data.subdata(in: (at + 46)..<(at + 46 + nameLength))
            let name = String(decoding: nameBytes, as: UTF8.self)
            entries.append(Entry(name: name, method: method, compressedSize: compressed, size: uncompressed, localHeader: local))
            at += 46 + nameLength + extraLength + commentLength
        }
        return entries
    }

    /// Raw DEFLATE (RFC 1951), which is what `COMPRESSION_ZLIB` decodes. The output must be exactly the size the
    /// directory promised.
    private static func inflate(_ raw: Data, size: Int) throws -> Data {
        if size == 0 { return Data() }
        var out = Data(count: size)
        let written = out.withUnsafeMutableBytes { (dst: UnsafeMutableRawBufferPointer) -> Int in
            raw.withUnsafeBytes { (src: UnsafeRawBufferPointer) -> Int in
                guard let d = dst.bindMemory(to: UInt8.self).baseAddress, let s = src.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                return compression_decode_buffer(d, size, s, raw.count, nil, COMPRESSION_ZLIB)
            }
        }
        guard written == size else { throw Failure.corrupt("inflated to \(written) bytes, not \(size)") }
        return out
    }

    private static func u16(_ d: Data, _ at: Int) -> UInt16 {
        guard at >= 0, at + 2 <= d.count else { return 0 }
        return UInt16(d[d.startIndex + at]) | UInt16(d[d.startIndex + at + 1]) << 8
    }

    private static func u32(_ d: Data, _ at: Int) -> UInt32 {
        guard at >= 0, at + 4 <= d.count else { return 0 }
        return (0..<4).reduce(UInt32(0)) { $0 | UInt32(d[d.startIndex + at + $1]) << (8 * $1) }
    }
}
