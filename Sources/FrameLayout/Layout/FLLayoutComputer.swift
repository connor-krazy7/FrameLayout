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
