import Foundation
import Observation
import OSLog

/// One visit to the press (ADR-016): the edition underneath, the proof on the press, the part in hand and where the
/// wheel is. Everything the person chooses goes into the proof; the proof is left on the press as they go, so leaving
/// the room keeps the work, and nothing reaches the rest of the app until it is pulled.
@MainActor @Observable
final class PressSession {
    static let log = Logger(subsystem: "com.designedbybruno.stub", category: "press")

    let title: String
    let copy: Copy
    @ObservationIgnored private let editions: Editions
    /// What the person has chosen so far.
    private(set) var proof: Proof
    /// The part in hand.
    private(set) var focus: Part?
    /// A part that rolls nothing, just touched: the italic line says why it will not turn.
    private(set) var explaining: Part?
    /// The wheel, in takes, for the part in hand. Fractional mid-turn; a whole number at rest.
    var position: Double = 0

    /// Compositions drawn lately, by edition: a scrub between two takes draws the same two over and over.
    @ObservationIgnored private var memo: [Edition: Composition] = [:]

    init(title: String, copy: Copy, editions: Editions = .shared) {
        self.title = title
        self.copy = copy
        self.editions = editions
        proof = editions.pressProof(for: title)
    }

    /// The edition as the hash or the model printed it.
    var underneath: Edition { editions.underneath(for: title) ?? Genome.floor(for: title) }
    /// The edition with the proof on the press laid over it.
    var edition: Edition { underneath.applying(proof) }
    var movement: Movement { edition.movement }
    var composition: Composition { composition(edition) }

    /// The parts the press can turn, in the order they are drawn.
    var turnable: [Part] { movement.parts.filter(\.turns) }

    func composition(_ edition: Edition) -> Composition {
        if let known = memo[edition] { return known }
        if memo.count > 24 { memo.removeAll() }
        let c = Composition(edition: edition, copy: copy)
        memo[edition] = c
        return c
    }

    /// The card at `position` on the wheel for the part in hand: a take, or the in-between of two. Under Reduce Motion
    /// the part cuts from take to take.
    func drawing(at position: Double, reduceMotion: Bool) -> Composition {
        guard let focus else { return composition }
        let p = min(max(position, Double(Proof.takeRange.lowerBound)), Double(Proof.takeRange.upperBound))
        if reduceMotion { return composition(taking: Int(p.rounded()), of: focus) }
        let low = p.rounded(.down)
        let t = p - low
        let a = composition(taking: Int(low), of: focus)
        guard t > 0.0005, Int(low) < Proof.takeRange.upperBound else { return a }
        let b = composition(taking: Int(low) + 1, of: focus)
        return Composition(a, poster: Composition.between(a, b, t: CGFloat(t)),
                           inBetween: Composition.InBetween(part: focus.id, position: p))
    }

    private func composition(taking take: Int, of part: Part) -> Composition {
        var trial = proof
        trial.takes[part.id] = take
        return composition(underneath.applying(trial))
    }

    /// The take of `part` on the press.
    func take(of part: Part) -> Int { proof.takes[part.id] ?? 0 }

    // MARK: The hand

    /// A finger on the card at `point` (card points): picks up the part there, puts down the part in hand if it is
    /// touched again or the finger lands on bare stock, and explains a part that rolls nothing.
    func touch(at point: CGPoint) {
        guard let id = composition.part(at: point), let part = movement.part(id) else {
            putDown()
            return
        }
        if part.id == focus?.id {
            putDown()
        } else if part.turns {
            pickUp(part)
        } else {
            focus = nil
            explaining = part
        }
    }

    func pickUp(_ part: Part) {
        guard part.turns else { return }
        explaining = nil
        focus = part
        position = Double(take(of: part))
    }

    func putDown() {
        focus = nil
        explaining = nil
    }

    /// The wheel has come to rest on `take`: it goes into the proof, and the proof is left on the press.
    func settle(on take: Int) {
        guard let focus else { return }
        let take = min(max(take, Proof.takeRange.lowerBound), Proof.takeRange.upperBound)
        position = Double(take)
        guard self.take(of: focus) != take else { return }
        proof.takes[focus.id] = take == 0 ? nil : take
        editions.putOnPress(proof)
        Self.log.info("Press '\(self.proof.release)': \(focus.id) take \(take)")
    }

    // MARK: Words

    /// The one italic sentence on the screen: what is in hand and which take, why a part will not turn, or what the
    /// card is.
    func sentence(at position: Double) -> String {
        if let explaining, let note = explaining.note { return note }
        if let focus {
            let name = Self.capitalised(focus.name)
            if focus.kind == .frame { return "\(name). Everything on it moves with it." }
            let take = Int(min(max(position, 0), 99).rounded())
            return take == 0 ? "\(name), as the title drew it." : "\(name). Take \(Self.spelled(take))."
        }
        if edition == underneath { return "Touch a part of the card to turn it." }
        return edition.described + "."
    }

    /// VoiceOver's name for a part in the rotor: "The disc, second ink, take three."
    func spoken(_ part: Part) -> String {
        let first = composition.poster.first { $0.part == part.id }
        var words = [Self.capitalised(part.name)]
        if let first { words.append(inkWords(first)) }
        let take = self.take(of: part)
        words.append(take == 0 ? "as the title drew it" : "take \(Self.spelled(take))")
        return words.joined(separator: ", ")
    }

    private func inkWords(_ mark: Mark) -> String {
        if mark.foil, composition.isMetallic { return edition.stock == .holographic ? "holographic film" : "foil" }
        return switch mark.role {
        case .primary: "first ink"
        case .secondary: "second ink"
        case .ink: "black"
        case .ground: "the paper's colour"
        case .light: "the light ink"
        case .dark: "the dark ink"
        }
    }

    static func capitalised(_ s: String) -> String { s.prefix(1).uppercased() + s.dropFirst() }

    /// A number in words, as the italic sentence prints them: "fourteen", "ninety-nine".
    static func spelled(_ n: Int) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "en")
        f.numberStyle = .spellOut
        return f.string(from: NSNumber(value: n)) ?? String(n)
    }
}
