import UIKit

/// Memoises `node.layout(in:)` on `(node, context)`, which is sound because a node is `Hashable`
/// and its layout is a pure function of that pair. See the node-equality rule for why `==` and
/// `hash(into:)` are always synthesised — they are what decides a hit here.
///
/// Two limits, both deliberate for now and both things a caller has to plan around:
///
/// - **Unbounded.** No eviction and no cost accounting; `removeAll()` is the only way out. A feed
///   that scrolls through distinct content grows this dictionary for the lifetime of the screen, so
///   clear it on a data reload rather than letting it accumulate.
/// - **One cache per node type.** `Node` is a single concrete type, so a screen with six cell kinds
///   needs six caches. That is what keeps the key `Hashable` without boxing; a heterogeneous cache
///   would need an existential key and a hand-written comparator.
///
/// It is also only ever keyed at the root a caller hands it. Nothing memoises below that point, so a
/// subtree shared between two roots is measured once per root.
public final class FLLayoutCache<Node: FLNode>: @unchecked Sendable {
    private let lock = NSLock()
    private var contextToLayout: [FLLayoutKey<Node>: Node.Layout] = [:]

    public init() {}

    public var count: Int {
        lock.withLock { contextToLayout.count }
    }

    public func layout(for node: Node, in context: FLContext) -> Node.Layout {
        let key = FLLayoutKey(node: node, context: context)

        if let cached = lock.withLock({ contextToLayout[key] }) {
            return cached
        }

        let layout = node.layout(in: context)
        lock.withLock { contextToLayout[key] = layout }

        return layout
    }

    public func removeAll() {
        lock.withLock { contextToLayout.removeAll() }
    }
}
