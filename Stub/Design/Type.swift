import SwiftUI

/// Two faces and a mono, never a fourth. Shared with the widget, so nothing here may need Metal or UIKit;
/// the misregistered plate lives next door in `DisplayTitle.swift`.
/// Host Grotesk for words. Newsreader for reading, upright: the app's own chrome has no italic, only what an edition
/// prints does (ADR-033). Fragment Mono for numbers only.
/// Hierarchy comes from size and space, never from weight.
enum Type {
    static func display(_ size: CGFloat) -> Font { .custom("HostGrotesk-Medium", size: size) }
    static func words(_ size: CGFloat) -> Font { .custom("HostGrotesk-Regular", size: size) }
    static func stamp(_ size: CGFloat) -> Font { .custom("HostGrotesk-SemiBold", size: size) }
    static func reading(_ size: CGFloat) -> Font { .custom("Newsreader16pt-Regular", size: size) }
    static func numbers(_ size: CGFloat) -> Font { .custom("FragmentMono-Regular", size: size) }
    /// The mono at a size its caller has already scaled, on a curve of its own: a figure engraved large grows as a large
    /// title does, not as body text, which would make it a hundred points at the largest size.
    static func numbers(scaled size: CGFloat) -> Font { .custom("FragmentMono-Regular", fixedSize: size) }

    /// Display tracking: -0.03em.
    static func displayTracking(_ size: CGFloat) -> CGFloat { -0.03 * size }
}

extension View {
    /// Host Grotesk 500, tight, for the words that carry the screen.
    func displayText(_ size: CGFloat) -> some View {
        self.font(Type.display(size)).tracking(Type.displayTracking(size)).foregroundStyle(Ink.ink)
    }
    /// Fragment Mono for anything that is a number: a date, a seat, a price.
    func numberText(_ size: CGFloat) -> some View {
        self.font(Type.numbers(size)).foregroundStyle(Ink.soft(0.75))
    }
}
