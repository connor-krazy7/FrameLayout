import UIKit

@resultBuilder
public enum FLNodeBuilder {
    public static func buildExpression<Node: FLNode>(_ node: Node) -> Node {
        node
    }

    public static func buildExpression<Composite: FLView>(_ composite: Composite) -> FLComposed<Composite> {
        composite.node
    }

    public static func buildBlock<Node: FLNode>(_ node: Node) -> Node {
        node
    }

    public static func buildOptional<Node: FLNode>(_ node: Node?) -> FLOptional<Node> {
        FLOptional(wrapped: node)
    }

    public static func buildEither<First: FLNode, Second: FLNode>(first node: First) -> FLEither<First, Second> {
        .first(node)
    }

    public static func buildEither<First: FLNode, Second: FLNode>(second node: Second) -> FLEither<First, Second> {
        .second(node)
    }
}
