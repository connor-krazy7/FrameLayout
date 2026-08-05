import Foundation

public enum FLLayoutComputer {
    public static func layout<Node: FLNode>(
        _ node: Node,
        in context: FLContext
    ) async -> Node.Layout {
        await Task.detached(priority: .userInitiated) {
            precondition(!Thread.isMainThread, "Content layout must be computed off the main thread")
            return node.layout(in: context)
        }.value
    }
}

public final class FLLayoutCache<Node: FLNode>: @unchecked Sendable {
    private struct Key: Hashable {
        let node: Node
        let context: FLContext
    }

    private let lock = NSLock()
    private var contextToLayout: [Key: Node.Layout] = [:]

    public init() {}

    public var count: Int {
        lock.withLock { contextToLayout.count }
    }

    public func layout(for node: Node, in context: FLContext) -> Node.Layout {
        let key = Key(node: node, context: context)

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
