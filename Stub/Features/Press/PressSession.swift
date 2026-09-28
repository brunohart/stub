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
    /// How far apart the card's layers are lifted: 0 the card, 1 the separations (brief §5.4).
    var separation: CGFloat = 0
    /// What is open on the bench when nothing is in hand.
    var bench: Bench = .rest
    /// How much of the card on the bed is printed: a new movement or stock is reprinted a pass at a time.
    private(set) var printed = Plate.foil
    /// Counts the passes of a reprint, for the haptic each one lands with.
    private(set) var pass = 0
    /// New inks spreading across the card, when a draw-down has been dropped on it.
    var flood: Flood?
    /// Where a finger is along the fan, if one is.
    var fanFinger: CGFloat?
    #if DEBUG
    /// `-drive` letting go on a card in the fan, as a finger would.
    var letGo: Movement?
    #endif

    /// The three choices the genome offers, each with its object on the bench (brief §5.5, §5.6).
    enum Bench: String, CaseIterable, Sendable {
        case rest, movement, inks, stock
    }

    /// A palette flooding the card from where it was dropped, `progress` of the way across.
    struct Flood: Equatable {
        var palette: Palette
        var origin: CGPoint
        var progress: CGFloat = 0
    }

    /// A pass of the press's print run: quicker than an edition's first printing, because a proof is pulled, not
    /// published.
    static let passTime: Duration = .milliseconds(180)

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
    /// touched again or the finger lands on bare stock, and explains a part that rolls nothing. With the layers apart,
    /// the finger is carried through each sheet from the top down: a part hidden under another on the flat card is
    /// reachable on its own sheet, and clear film lets the finger through to the sheet below.
    func touch(at point: CGPoint) {
        guard separation > 0 else {
            touch(composition.part(at: point))
            return
        }
        let layers = Separation.layers(metallic: composition.isMetallic)
        for (index, layer) in layers.enumerated().reversed() {
            guard let onSheet = Separation.unproject(point, index: index, separation: separation),
                  let id = composition.part(at: onSheet, on: layer) else { continue }
            touch(id)
            return
        }
        putDown()
    }

    /// A finger on one sheet of the separations laid flat (Reduce Motion), at `point` on that sheet.
    func touch(at point: CGPoint, on layer: Separation.Layer) {
        touch(composition.part(at: point, on: layer))
    }

    private func touch(_ id: Part.ID?) {
        guard let id, let part = movement.part(id) else {
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
        bench = .rest
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

    // MARK: The genome

    /// The movement the title's hash chose, and the one the model chose if it did: the fan says which is which.
    var titlesMovement: Movement { Genome.floor(for: title).movement }
    var modelsMovement: Movement? { underneath.directedBy == .model ? underneath.movement : nil }

    /// The edition as it would be in `movement`, with everything else on the press as it is: a card in the fan.
    func edition(in movement: Movement) -> Edition {
        var trial = proof
        trial.movement = movement
        return underneath.applying(trial)
    }

    /// The edition as it would be in `palette`: the card a flood reveals.
    func edition(in palette: Palette) -> Edition {
        var trial = proof
        trial.palette = palette
        return underneath.applying(trial)
    }

    func choose(_ movement: Movement) {
        guard movement != edition.movement else { return }
        putDown()
        proof.movement = movement == underneath.movement ? nil : movement
        keep("movement \(movement.rawValue)")
    }

    func choose(_ palette: Palette) {
        guard palette != edition.palette else { return }
        proof.palette = palette == underneath.palette ? nil : palette
        keep("inks \(palette.rawValue)")
    }

    func choose(_ stock: Stock) {
        guard stock != edition.stock else { return }
        proof.stock = stock == underneath.stock ? nil : stock
        keep("stock \(stock.rawValue)")
    }

    private func keep(_ what: String) {
        editions.putOnPress(proof)
        Self.log.info("Press '\(self.proof.release)': \(what)")
    }

    /// The card on the bed printed again, a pass at a time and quickly: after a new movement or a new stock, because
    /// what it is printed on or in has changed. Under Reduce Motion it is simply whole.
    func reprint(reduceMotion: Bool) async {
        guard !reduceMotion else { printed = Plate.foil; return }
        printed = 0
        let metallic = composition.isMetallic
        do {
            try await Task.sleep(for: .milliseconds(120))
            for p in 1...Plate.foil {
                if p == Plate.foil, !metallic { break }
                printed = p
                pass += 1
                try await Task.sleep(for: Self.passTime)
            }
        } catch {
            // Left mid-run: the card is printed whole.
        }
        printed = Plate.foil
    }

    // MARK: Words

    /// The one italic sentence on the screen: what is in hand and which take, why a part will not turn, or what the
    /// card is.
    func sentence(at position: Double) -> String {
        if let explaining, let note = explaining.note { return note }
        if focus == nil {
            switch bench {
            case .movement: return "One film in eight movements. Let go on the one you want."
            case .inks: return "Twelve inks. Drag one onto the card, or tap it."
            case .stock: return "Hold a swatch and rub it to feel it. Tap it to print on it."
            case .rest: break
            }
        }
        if let focus {
            let name = Self.capitalised(focus.name)
            if focus.kind == .frame { return "\(name). Everything on it moves with it." }
            let take = Int(min(max(position, 0), 99).rounded())
            return take == 0 ? "\(name), as the title drew it." : "\(name). Take \(Self.spelled(take))."
        }
        if separation > 0.5 {
            return composition.isMetallic ? "Five sheets: the stock, two plates, the foil and the type."
                : "Four sheets: the stock, two plates and the type."
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
