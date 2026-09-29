import SwiftUI

/// The back of an edition: the stub as it was scanned, mounted in four photo corners at the tilt it lay at on the
/// table, and under it what the edition is and who chose it. The strip carries the Aztec code and the edition's
/// serial, which is its release's hash. Held, the silkscreen lifts off the photograph, as it does in the drawer.
struct EditionBack: View {
    let composition: Composition
    /// The stub's photograph, the archive. `nil` for a stub typed in by hand: the mount holds a blank stub.
    let photo: UIImage?
    let tilt: Double
    var code: CGImage?
    var light: Light = .rest
    /// 1 printed on the card, 0 the photograph as taken.
    var silkscreen: Double = 1
    /// The owner's pencil in the margin: A/P, the takes, the signature. Only a proof has it (ADR-016).
    var pencil: Pencil? = nil
    /// The signature as it was drawn, in card points; `nil` leaves the margin bare.
    var signature: UIImage? = nil

    /// The margin the signature is drawn in, in card points: below the colophon, clear of the strip.
    static let signatureMargin = CGRect(x: 172, y: 338, width: 136, height: 58)

    var body: some View {
        let c = composition
        let ground = c.inks.groundIsLight ? c.inks.ground : c.inks.hex(.light)
        let words = Color(hex: EditionInks.contrast(c.inks.ink, ground) >= 4.5 ? c.inks.ink : c.inks.hex(.dark))
        let corner = Color(hex: EditionInks.contrast(c.inks.primary, ground) >= 3 ? c.inks.primary : c.inks.ink)
        ZStack(alignment: .topLeading) {
            // The back of the card is bare stock: the palette's lighter paper, whichever way round the front was.
            Rectangle().fill(Color(hex: ground))
                .modifier(StockEffect(light: light, stock: c.edition.stock == .cotton ? .cotton : .coated, seed: Double(c.edition.seed % 991),
                                      patina: c.patina.mirrored))

            VStack(alignment: .leading, spacing: 0) {
                mount(corner: corner)
                    .frame(width: Card.width - 2 * Card.pad, height: 190)
                    .padding(.top, 28)
                colophon(words: words)
                    .padding(.top, 22)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Card.pad)
            .frame(width: Card.width, height: Card.poster, alignment: .top)

            if let pencil { margin(pencil) }

            strip(words: words)
                .frame(width: Card.width, height: Card.height - Card.poster)
                .offset(y: Card.poster)
        }
        .frame(width: Card.width, height: Card.height)
        // The punches go through both faces: from the back, each is where it is on the front, mirrored.
        .clipShape(TicketShape(punches: c.punches, mirrored: true))
    }

    /// The photograph in four corners, or a blank stub if there is none.
    private func mount(corner: Color) -> some View {
        Group {
            if let photo {
                let aspect = min(max(photo.size.width / max(photo.size.height, 1), 1), 2.6)
                Image(uiImage: photo)
                    .resizable()
                    .aspectRatio(aspect, contentMode: .fit)
                    .silkscreened(strength: silkscreen)
                    .overlay { PhotoCorners().fill(corner.opacity(0.92)) }
                    .shadow(color: .black.opacity(0.18), radius: 1.5, x: 1, y: 2)
            } else {
                BlankStub(tilt: 0, title: composition.copy.title).frame(height: 118)
            }
        }
        .rotationEffect(.degrees(tilt))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func colophon(words: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("An edition of \(composition.copy.title)")
                .font(Face.serif.font(19))
                .foregroundStyle(words)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            Text(composition.edition.described)
                .font(Face.groteskMedium.font(12))
                .foregroundStyle(words.opacity(0.7))
            Text(composition.edition.directedBy.sentence)
                .font(Face.serifItalic.font(14))
                .foregroundStyle(words.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The owner's pencil, in graphite, multiplied into the stock so it sits in the paper rather than on it: the
    /// printmaker's notation on the left, the signature on the right.
    private func margin(_ pencil: Pencil) -> some View {
        let graphite = Color(uiColor: Signatures.graphite)
        return ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 3) {
                Text("A/P").font(Face.mono.font(12))
                if let takes = pencil.takes {
                    Text(takes).font(Face.mono.font(9.5)).lineLimit(2).minimumScaleFactor(0.7)
                }
            }
            .foregroundStyle(graphite.opacity(0.85))
            .frame(width: 140, alignment: .leading)
            .offset(x: Card.pad, y: Self.signatureMargin.minY + 18)

            if let signature {
                Image(uiImage: signature)
                    .resizable()
                    .frame(width: Self.signatureMargin.width, height: Self.signatureMargin.height)
                    .opacity(0.9)
                    .offset(x: Self.signatureMargin.minX, y: Self.signatureMargin.minY)
            } else {
                // Where to sign: a faint pencil line, as a printer leaves for the artist.
                Rectangle()
                    .fill(graphite.opacity(0.28))
                    .frame(width: Self.signatureMargin.width - 12, height: 0.75)
                    .offset(x: Self.signatureMargin.minX + 6, y: Self.signatureMargin.maxY - 12)
            }
        }
        .blendMode(.multiply)
        .frame(width: Card.width, height: Card.poster, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    private func strip(words: Color) -> some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(composition.copy.viewingWords)
                    .font(Face.serifItalic.font(14))
                    .foregroundStyle(words)
                // The serial is the release's hash: every copy of this edition carries the same one.
                Text(Self.serial(composition.edition))
                    .font(Face.mono.font(11))
                    .foregroundStyle(words.opacity(0.7))
            }
            Spacer(minLength: 0)
            if let code {
                Image(decorative: code, scale: 1)
                    .renderingMode(.template)
                    .interpolation(.none)
                    .resizable()
                    .foregroundStyle(words)
                    .frame(width: Self.codeSide, height: Self.codeSide)
            }
        }
        // `clearZones` measures the same numbers, so a punch never lands on the code or these words.
        .padding(.horizontal, Self.stripInset.width)
        .padding(.vertical, Self.stripInset.height)
        .frame(maxHeight: .infinity, alignment: .bottom)
    }
}

/// Four photo corners: little triangles of paper that hold a photograph by its corners.
struct PhotoCorners: Shape {
    var size: CGFloat = 16

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let s = min(size, rect.width / 4, rect.height / 4)
        path.addLines([CGPoint(x: rect.minX - 3, y: rect.minY - 3), CGPoint(x: rect.minX + s, y: rect.minY - 3), CGPoint(x: rect.minX - 3, y: rect.minY + s)])
        path.closeSubpath()
        path.addLines([CGPoint(x: rect.maxX + 3, y: rect.minY - 3), CGPoint(x: rect.maxX + 3, y: rect.minY + s), CGPoint(x: rect.maxX - s, y: rect.minY - 3)])
        path.closeSubpath()
        path.addLines([CGPoint(x: rect.maxX + 3, y: rect.maxY + 3), CGPoint(x: rect.maxX - s, y: rect.maxY + 3), CGPoint(x: rect.maxX + 3, y: rect.maxY - s)])
        path.closeSubpath()
        path.addLines([CGPoint(x: rect.minX - 3, y: rect.maxY + 3), CGPoint(x: rect.minX - 3, y: rect.maxY - s), CGPoint(x: rect.minX + s, y: rect.maxY + 3)])
        path.closeSubpath()
        return path
    }
}
