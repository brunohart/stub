import Foundation

/// A named group of marks on a poster, rolled from a die of its own (ADR-016). The press turns a part to another
/// take without moving any other part: `Dice.fork` made visible.
///
/// Each movement declares its parts in the order it draws them (`Movement.parts`, and the doc comment on each
/// movement's function). At most one is a frame, the geometry the others hang from. A frame reads only its own
/// die; a piece reads only its own die and, when it hangs, the frame's outputs. So turning a piece moves that piece
/// and nothing else, and turning the frame may move whatever hangs from it. `PressTests` holds every movement to it.
struct Part: Sendable, Equatable, Identifiable {
    /// Namespaced by movement ("constructivist/disc"), so a proof keeps its takes when the movement changes and
    /// changes back.
    typealias ID = String

    enum Kind: Sendable, Equatable {
        /// The geometry the others hang from. At most one a movement.
        case frame
        /// Hangs from the frame or stands on its own; turning it moves only it.
        case piece
        /// Rolls nothing: set from the copy, the frame or the movement's rules. It has a name so it can be touched and
        /// explained ("the title is set by the band"), but there is no other take of it to choose.
        case set
    }

    let id: ID
    /// What it is called aloud and in the italic line: "the disc".
    let name: String
    let kind: Kind
    /// Reads the frame's outputs, so turning the frame may move it.
    let hangs: Bool
    /// For a set part, the press's one sentence on why it has no other take, and what to turn instead: "The title is
    /// set by the band. Turn the diagonal."
    var note: String? = nil

    /// Whether the press can turn it.
    var turns: Bool { kind != .set }

    static func frame(_ id: ID, _ name: String) -> Part { Part(id: id, name: name, kind: .frame, hangs: false) }
    static func piece(_ id: ID, _ name: String, hangs: Bool = false) -> Part { Part(id: id, name: name, kind: .piece, hangs: hangs) }
    static func set(_ id: ID, _ name: String, hangs: Bool = false, note: String) -> Part {
        Part(id: id, name: name, kind: .set, hangs: hangs, note: note)
    }
}

/// Every movement's parts, one namespace a movement. The lists are in the order the marks are drawn.
enum Parts {}

extension Movement {
    /// The parts this movement draws, in order.
    var parts: [Part] {
        switch self {
        case .swiss: Parts.Swiss.all
        case .constructivist: Parts.Constructivist.all
        case .deco: Parts.Deco.all
        case .cutout: Parts.Cutout.all
        case .riso: Parts.Riso.all
        case .letterpress: Parts.Letterpress.all
        case .blueprint: Parts.Blueprint.all
        case .noir: Parts.Noir.all
        }
    }

    /// The frame, if this movement has one.
    var frame: Part? { parts.first { $0.kind == .frame } }

    func part(_ id: Part.ID) -> Part? { parts.first { $0.id == id } }
}

/// A poster's marks, collected part by part: every mark added while `part` is set belongs to it.
struct Sheet {
    private(set) var marks: [Mark] = []
    var part: Part?

    mutating func append(_ mark: Mark) {
        var mark = mark
        mark.part = part?.id
        marks.append(mark)
    }

    static func += (sheet: inout Sheet, marks: [Mark]) {
        for mark in marks { sheet.append(mark) }
    }
}
