import Foundation
import SwiftData

/// The drawers and the order the stubs stand in them (ADR-026). The cabinet has the drawer of every stub, which the app
/// opens on, and the drawers the person makes. Every drawer is filed by year, newest first, the way a dated archive is:
/// that order is the drawer's, and nobody moves a night into another year. Within a year the person puts the stubs where
/// they like: hold one and move it. Until they do, a year stands newest night first, and a stub kept later stands at the
/// front of its year.
///
/// Pure where it can be, so the order can be tested without a screen.
enum Cabinet {
    /// The year a stub belongs to: the night it was seen, or the day it was kept when the ticket printed no date.
    static func year(of stub: Stub, calendar: Calendar = .current) -> Int {
        calendar.component(.year, from: stub.screenedAt ?? stub.createdAt)
    }

    /// The stubs in a drawer: every one for the drawer of every stub (`nil`), the ones filed for a drawer the person made.
    static func members(of drawer: StubDrawer?, among stubs: [Stub]) -> [Stub] {
        guard let drawer else { return stubs }
        let filed = Set(drawer.stubIDs)
        return stubs.filter { filed.contains($0.id) }
    }

    /// The drawer's stubs in the order they stand: the years newest first, each year front to back.
    static func order(_ stubs: [Stub], in drawer: StubDrawer?, calendar: Calendar = .current) -> [Stub] {
        let years = Dictionary(grouping: stubs) { year(of: $0, calendar: calendar) }
        return years.keys.sorted(by: >).flatMap { front(years[$0]!, in: drawer) }
    }

    /// One year's stubs front to back. In a drawer the person made, the order they are filed in; in the drawer of every stub,
    /// the stubs never moved first, newest night first, then the ones the person placed.
    static func front(_ stubs: [Stub], in drawer: StubDrawer?) -> [Stub] {
        if let drawer {
            var at: [UUID: Int] = [:]
            for (i, id) in drawer.stubIDs.enumerated() where at[id] == nil { at[id] = i }
            return stubs.sorted { (at[$0.id] ?? .max, $1.createdAt) < (at[$1.id] ?? .max, $0.createdAt) }
        }
        let loose = stubs.filter { $0.handOrder == nil }.sorted(by: newestFirst)
        let placed = stubs.filter { $0.handOrder != nil }.sorted { ($0.handOrder!, $1.createdAt) < ($1.handOrder!, $0.createdAt) }
        return loose + placed
    }

    static func newestFirst(_ a: Stub, _ b: Stub) -> Bool {
        (a.screenedAt ?? a.createdAt, a.createdAt) > (b.screenedAt ?? b.createdAt, b.createdAt)
    }

    /// The years of an ordered drawer, each with its stubs, as the dividers file them.
    static func sections(_ ordered: [Stub], calendar: Calendar = .current) -> [Year] {
        var sections: [Year] = []
        for stub in ordered {
            let y = year(of: stub, calendar: calendar)
            if sections.last?.year == y { sections[sections.count - 1].stubs.append(stub) } else { sections.append(Year(year: y, stubs: [stub])) }
        }
        return sections
    }

    struct Year: Identifiable {
        let year: Int
        var stubs: [Stub]
        var id: Int { year }
    }

    /// `order` with `moving` put where `target` stands, when the two are of one year; the same order when they are not, or
    /// when either is not in it. Moving down puts it after the target, moving up before, as a hand would.
    static func move(_ moving: UUID, to target: UUID, in order: [UUID], sameYear: (UUID, UUID) -> Bool) -> [UUID] {
        guard moving != target, sameYear(moving, target), let from = order.firstIndex(of: moving), let to = order.firstIndex(of: target) else {
            return order
        }
        var moved = order
        moved.remove(at: from)
        moved.insert(moving, at: to)
        return moved
    }

    /// Writes an order back where it is kept: for a drawer the person made, as its list (any filed stub not in `order`,
    /// such as one whose year is not showing, keeps its place at the back); for the drawer of every stub, as each stub's
    /// place in its year. Only what changed is written, so a sync carries only the stubs that moved. Returns how many changed.
    @discardableResult
    static func commit(_ order: [UUID], stubs: [Stub], in drawer: StubDrawer?, calendar: Calendar = .current) -> Int {
        if let drawer {
            let shown = Set(order)
            let next = order + drawer.stubIDs.filter { !shown.contains($0) }
            guard next != drawer.stubIDs else { return 0 }
            drawer.stubIDs = next
            return 1
        }
        let byID = Dictionary(stubs.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var index: [Int: Int] = [:]
        var changed = 0
        for id in order {
            guard let stub = byID[id] else { continue }
            let y = year(of: stub, calendar: calendar)
            let place = Double(index[y, default: 0])
            index[y, default: 0] += 1
            if stub.handOrder != place { stub.handOrder = place; changed += 1 }
        }
        return changed
    }

    /// Files a stub in a drawer, where its night puts it among the stubs already there (the person can move it after).
    /// Filing a stub that is already there changes nothing.
    static func file(_ stub: Stub, in drawer: StubDrawer, among stubs: [Stub]) {
        guard !drawer.stubIDs.contains(stub.id) else { return }
        let night = stub.screenedAt ?? stub.createdAt
        let byID = Dictionary(stubs.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let at = drawer.stubIDs.firstIndex { id in
            guard let other = byID[id] else { return false }
            return (other.screenedAt ?? other.createdAt) < night
        }
        drawer.stubIDs.insert(stub.id, at: at ?? drawer.stubIDs.count)
    }

    /// Takes a stub out of a drawer the person made. It stays in the drawer of every stub.
    static func takeOut(_ id: UUID, of drawer: StubDrawer) {
        drawer.stubIDs.removeAll { $0 == id }
    }

    /// Where a new drawer goes: after the last.
    static func nextPosition(after drawers: [StubDrawer]) -> Double {
        (drawers.map(\.position).max() ?? 0) + 1
    }

    /// A drawer's name as it is typed on its card: trimmed, and never empty.
    static func name(_ typed: String) -> String? {
        let name = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : String(name.prefix(32))
    }
}
