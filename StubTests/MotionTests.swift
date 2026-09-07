import Testing
import Foundation
@testable import Stub

/// The authored imperfection has rules: a stub never sits level, and never past a degree and a half.
struct TiltTests {
    @Test func tiltIsNeverLevel() {
        for _ in 0..<200 {
            let t = Stub.randomTilt()
            #expect(t != 0)
            #expect(abs(t) <= 1.5)
            #expect(abs(t) >= 0.4)
        }
    }

    @Test func tiltIsFixedAtCreation() {
        let stub = Stub(title: "Past Lives")
        let first = stub.tilt
        #expect(stub.tilt == first)
        #expect(first != 0)
    }
}
