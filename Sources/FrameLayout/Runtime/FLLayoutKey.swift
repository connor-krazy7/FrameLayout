import UIKit

/// What to key a layout cache on: two keys match when their node and context produce the same geometry,
/// not when they are the same values.
public struct FLLayoutKey<Node: FLNode>: Hashable {
    public let node: Node
    public let context: FLContext

    public init(node: Node, context: FLContext) {
        self.node = node
        self.context = context
    }

    public static func == (lhs: FLLayoutKey<Node>, rhs: FLLayoutKey<Node>) -> Bool {
        lhs.node.isLayoutEquivalent(to: rhs.node) && lhs.context.isLayoutEquivalent(to: rhs.context)
    }

    public func hash(into hasher: inout Hasher) {
        node.hashLayoutIdentity(into: &hasher)
        context.hashLayoutIdentity(into: &hasher)
    }
}
