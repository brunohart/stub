import Testing
import Foundation
@testable import Stub

/// Twelve palettes, all of them legible. Checked here, not by eye: a palette that fails is a palette that
/// prints a title nobody can read on somebody's favourite film.
struct PaletteTests {
    @Test func wordsReadOnEveryGround() {
        for palette in Palette.allCases {
            let inks = palette.inks
            let words = EditionInks.contrast(inks.ink, inks.ground)
            #expect(words >= 11, "\(palette): words at \(words):1")
            // A noir field is the dark of the two and its words are the light; the same pair, the same contrast.
            #expect(EditionInks.contrast(inks.hex(.light), inks.hex(.dark)) == words)
            // The first plate has to be visible as a shape even when it is not trusted with words.
            #expect(EditionInks.contrast(inks.primary, inks.ground) >= 1.7, "\(palette): the first plate disappears")
        }
    }

    @Test func wordsOnABandPickTheBetterInk() {
        let citrus = Palette.citrus.inks   // marigold on cream: 1.76:1, so words on the band are the ink
        #expect(citrus.on(.primary) == .ink)
        let sand = Palette.sand.inks       // rust on sand: the sand reads better on the rust
        #expect(sand.on(.primary) == .ground)
        #expect(citrus.strong(.primary) == .ink)
        #expect(Palette.chalk.inks.strong(.primary) == .primary)
    }

    @Test func contrastIsWCAG() {
        #expect(abs(EditionInks.contrast(0x000000, 0xFFFFFF) - 21) < 0.001)
        #expect(EditionInks.contrast(0x777777, 0x777777) == 1)
        #expect(EditionInks.mix(0x000000, 0xFFFFFF, 0.5) == 0x808080)
    }
}
