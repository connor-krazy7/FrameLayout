import Testing
import UIKit
@testable import CellSystem

private struct Card: FLView {
    let title: String
    var inset: CGFloat = 10

    var body: some FLNode {
        FLColor(.red)
            .frame(width: 40, height: 20)
            .padding(inset)
    }
}

private struct Nested: FLView {
    let leading: String
    let trailing: String

    var body: some FLNode {
        FLHStack(spacing: 8) {
            Card(title: leading)
            FLSpacer()
            Card(title: trailing)
        }
    }
}

@Suite("Composed views")
struct FLViewTests {
    @Test("a composite lays out as its body does")
    func matchesBody() {
        let card = Card(title: "x")
        let direct = FLColor(.red).frame(width: 40, height: 20).padding(10)

        #expect(card.layout(in: FLContext(width: 300)).size == direct.layout(in: FLContext(width: 300)).size)
        #expect(card.node.layout(in: FLContext(width: 300)).size == CGSize(width: 60, height: 40))
    }

    @Test("stored properties drive the layout")
    func storedPropertiesMatter() {
        #expect(Card(title: "x", inset: 0).node.layout(in: FLContext(width: 300)).size == CGSize(width: 40, height: 20))
        #expect(Card(title: "x", inset: 20).node.layout(in: FLContext(width: 300)).size == CGSize(width: 80, height: 60))
    }

    // The cache key is the composite's stored properties, not the expanded tree — cheaper to hash
    // and it still distinguishes different content.
    @Test("equality and hashing come from the stored properties")
    func identityFromStoredProperties() {
        #expect(Card(title: "a") == Card(title: "a"))
        #expect(Card(title: "a") != Card(title: "b"))
        #expect(Card(title: "a", inset: 4) != Card(title: "a", inset: 8))
        #expect(Card(title: "a").node == Card(title: "a").node)
    }

    @Test("the type identifier names the composite, not its body")
    func typeIdentifierNamesComposite() {
        #expect(FLComposed<Card>.typeIdentifier.contains("Card"))
        #expect(FLComposed<Card>.typeIdentifier != FLComposed<Nested>.typeIdentifier)
    }

    // A composite's Layout is opaque, so only `size` is observable from outside — its internal
    // frames are deliberately unreachable. Assertions about inner geometry belong to the pieces the
    // body is built from, which the other suites cover directly.
    @Test("composites nest inside a builder without spelling .node")
    func nestingInBuilders() {
        let nested = Nested(leading: "a", trailing: "b")

        // two 60x40 cards with a spacer between them, in a bounded 300
        #expect(nested.layout(in: FLContext(width: 300)).size == CGSize(width: 300, height: 40))
    }

    @Test("a nested composite collapses to its content when unbounded")
    func nestingUnbounded() {
        let nested = Nested(leading: "a", trailing: "b")

        #expect(nested.layout(in: FLContext.unspecified).size == CGSize(width: 136, height: 40))
    }

    @Test("a composite works through the layout cache")
    func cacheable() {
        let cache = FLLayoutCache<FLComposed<Card>>()
        let context = FLContext(width: 300)

        _ = cache.layout(for: Card(title: "a").node, in: context)
        _ = cache.layout(for: Card(title: "a").node, in: context)
        #expect(cache.count == 1)

        _ = cache.layout(for: Card(title: "b").node, in: context)
        #expect(cache.count == 2)
    }
}

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
