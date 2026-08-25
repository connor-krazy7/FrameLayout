import Testing
import UIKit
@testable import FrameLayout

@Suite("Composed node identity")
struct FLComposedIdentityTests {
    private struct Counted: FLView {
        let width: CGFloat

        var body: some FLNode {
            FLColor(.red).frame(width: width, height: 10)
        }
    }

    @Test("the body is stored, so repeated layout passes reuse it")
    func bodyIsStored() {
        let node = Counted(width: 40).node

        // same value used across passes; each `layout` reads the stored body
        #expect(node.layout(in: FLContext(width: 300)).size.width == 40)
        #expect(node.layout(in: FLContext(width: 300)).size.width == 40)
        #expect(node.body.layout(in: FLContext(width: 300)).size.width == 40)
    }

    @Test("equality ignores the body and compares only the composite")
    func equalityUsesComposite() {
        #expect(Counted(width: 40).node == Counted(width: 40).node)
        #expect(Counted(width: 40).node != Counted(width: 41).node)
    }

    @Test("hashing matches equality")
    func hashingMatchesEquality() {
        var hashes = Set<Int>()
        hashes.insert(Counted(width: 40).node.hashValue)
        hashes.insert(Counted(width: 40).node.hashValue)
        #expect(hashes.count == 1)

        hashes.insert(Counted(width: 41).node.hashValue)
        #expect(hashes.count == 2)
    }
}
