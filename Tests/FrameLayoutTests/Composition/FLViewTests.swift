import Testing
import UIKit
@testable import FrameLayout

@Suite("Composed views")
struct FLViewTests {
    @Test("a composite lays out as its body does")
    func matchesBody() {
        let card = ComposedCard(title: "x")
        let direct = FLColor(.red).frame(width: 40, height: 20).padding(10)

        #expect(card.layout(in: FLContext(width: 300)).size == direct.layout(in: FLContext(width: 300)).size)
        #expect(card.node.layout(in: FLContext(width: 300)).size == CGSize(width: 60, height: 40))
    }

    @Test("stored properties drive the layout")
    func storedPropertiesMatter() {
        #expect(ComposedCard(title: "x", inset: 0).node.layout(in: FLContext(width: 300)).size == CGSize(width: 40, height: 20))
        #expect(ComposedCard(title: "x", inset: 20).node.layout(in: FLContext(width: 300)).size == CGSize(width: 80, height: 60))
    }

    // The cache key is the composite's stored properties, not the expanded tree — cheaper to hash
    // and it still distinguishes different content.
    @Test("equality and hashing come from the stored properties")
    func identityFromStoredProperties() {
        #expect(ComposedCard(title: "a") == ComposedCard(title: "a"))
        #expect(ComposedCard(title: "a") != ComposedCard(title: "b"))
        #expect(ComposedCard(title: "a", inset: 4) != ComposedCard(title: "a", inset: 8))
        #expect(ComposedCard(title: "a").node == ComposedCard(title: "a").node)
    }

    @Test("the type identifier names the composite, not its body")
    func typeIdentifierNamesComposite() {
        #expect(FLComposed<ComposedCard>.typeIdentifier.contains("ComposedCard"))
        #expect(!FLComposed<ComposedCard>.typeIdentifier.contains("FLComposed"))
        #expect(FLComposed<ComposedCard>.typeIdentifier != FLComposed<ComposedNested>.typeIdentifier)
    }

    // A composite's Layout is opaque, so only `size` is observable from outside — its internal
    // frames are deliberately unreachable. Assertions about inner geometry belong to the pieces the
    // body is built from, which the other suites cover directly.
    @Test("composites nest inside a builder without spelling .node")
    func nestingInBuilders() {
        let nested = ComposedNested(leading: "a", trailing: "b")

        // two 60x40 cards with a spacer between them, in a bounded 300
        #expect(nested.layout(in: FLContext(width: 300)).size == CGSize(width: 300, height: 40))
    }

    @Test("a nested composite collapses to its content when unbounded")
    func nestingUnbounded() {
        let nested = ComposedNested(leading: "a", trailing: "b")

        #expect(nested.layout(in: FLContext.unspecified).size == CGSize(width: 136, height: 40))
    }

    @Test("a composite works through the layout cache")
    func cacheable() {
        let cache = FLLayoutCache<FLComposed<ComposedCard>>()
        let context = FLContext(width: 300)

        _ = cache.layout(for: ComposedCard(title: "a").node, in: context)
        _ = cache.layout(for: ComposedCard(title: "a").node, in: context)
        #expect(cache.count == 1)

        _ = cache.layout(for: ComposedCard(title: "b").node, in: context)
        #expect(cache.count == 2)
    }
}
