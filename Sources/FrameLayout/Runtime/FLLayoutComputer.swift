import Foundation

/// Runs a measurement off the main thread and asserts that it got there.
///
/// A convenience, not a requirement: `FLNode` is `Sendable` and `layout(in:)` is `nonisolated`, so a
/// caller with its own queue or prefetch strategy should measure directly rather than spend a
/// detached task per node.
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
