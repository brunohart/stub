import Testing
import Foundation
@testable import Stub

/// The drawer's one count of viewings (docs/decisions/004-budgets.md, the scroll fix) must say exactly what counting card by
/// card said: which viewing of its release each stub was, and of how many.
struct ViewingsTests {
    private func night(_ day: Int) -> Date { Date(timeIntervalSince1970: 1_700_000_000 + Double(day) * 86_400) }

    @Test func oneCountAgreesWithCountingCardByCard() {
        let stubs = [
            Stub(title: "Dune Part Two", screenedAt: night(3)),
            Stub(title: "Anora", screenedAt: night(1)),
            Stub(title: "Dune: Part Two", screenedAt: night(9)),
            Stub(title: "dune part two", screenedAt: nil, createdAt: Date(timeIntervalSince1970: 1_700_000_000 + 20 * 86_400)),
            Stub(title: "Past Lives", screenedAt: night(2)),
            Stub(title: "Anora", screenedAt: night(7)),
        ]
        let counted = Copy.viewings(in: stubs)
        #expect(counted.count == stubs.count)
        for stub in stubs {
            let one = Copy.viewings(of: stub, among: stubs)
            #expect(counted[stub.id]?.viewing == one.viewing, "\(stub.title)")
            #expect(counted[stub.id]?.of == one.of, "\(stub.title)")
        }
    }
}
