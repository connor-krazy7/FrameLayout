import Testing
import UIKit
@testable import FrameLayout

// `typeIdentifier` has no consumer inside the package — `FLNode.View` resolves a view statically, and
// nothing is keyed by the string. It exists for a consumer building `UICollectionView` cells, where the
// only property that matters is the one asserted below: same node type, same identifier; different node
// type, different identifier.
@Suite("Type identifiers")
struct FLTypeIdentifierTests {
    // The identifier of a value's type, spelled the way a cell provider reaches it.
    private func identifier(of node: some FLNode) -> String {
        type(of: node).typeIdentifier
    }

    @Test("the default names the node type and its parameters")
    func defaultReflectsTheType() {
        let padded = FLPadded<FLText>.typeIdentifier

        #expect(padded.contains("FLPadded"))
        #expect(padded.contains("FLText"))
    }

    @Test("same node type, different content, same identifier")
    func stableAcrossContent() {
        let short = FLText("a").padding(8)
        let long = FLText("a much longer string").padding(24)

        #expect(identifier(of: short) == identifier(of: long))
    }

    @Test("a different tree gives a different identifier")
    func distinctPerTree() {
        let text = FLText("a").padding(8)
        let colour = FLColor(.red).padding(8)
        let wrapped = FLText("a").padding(8).frame(width: 10)

        #expect(identifier(of: text) != identifier(of: colour))
        #expect(identifier(of: text) != identifier(of: wrapped))
    }

    // The hand-written scheme this default replaced spelled both of these `either(text,color)`: two
    // distinct types claiming one identifier, which a consumer would answer by dequeuing a cell built
    // for the other view tree. A reflected name is injective over types by construction, so the
    // node/group boundary is no longer the only thing keeping them apart.
    @Test("a node and a group of the same shape do not collide")
    func nodeAndGroupDiffer() {
        let node = FLEither<FLText, FLColor>.typeIdentifier
        let group = FLEitherGroup<FLSingle<FLText>, FLSingle<FLColor>>.typeIdentifier

        #expect(node != group)
    }

    @Test("a group's identifier names its children")
    func groupsNameTheirChildren() {
        let pair = FLConcat<FLSingle<FLText>, FLSingle<FLColor>>.typeIdentifier

        #expect(pair.contains("FLText"))
        #expect(pair.contains("FLColor"))
        #expect(pair != FLConcat<FLSingle<FLColor>, FLSingle<FLText>>.typeIdentifier)
    }

    // `FLComposed` is the only type that overrides the default; `FLViewTests` pins what it returns.
    @Test("the requirement can still be overridden")
    func overrideWins() {
        #expect(FLComposed<ComposedCard>.typeIdentifier != String(reflecting: FLComposed<ComposedCard>.self))
    }
}
