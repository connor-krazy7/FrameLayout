@resultBuilder
enum FLGroupBuilder {
    static func buildExpression<Node: FLNode>(_ node: Node) -> FLSingle<Node> {
        FLSingle(node: node)
    }

    static func buildExpression<Composite: FLView>(_ composite: Composite) -> FLSingle<FLComposed<Composite>> {
        FLSingle(node: composite.node)
    }

    static func buildExpression<Group: FLGroup>(_ group: Group) -> Group {
        group
    }

    static func buildBlock<each Child: FLGroup>(
        _ groups: repeat each Child
    ) -> FLConcat<repeat each Child> {
        FLConcat(repeat each groups)
    }

    static func buildOptional<Wrapped: FLGroup>(_ group: Wrapped?) -> FLOptionalGroup<Wrapped> {
        FLOptionalGroup(wrapped: group)
    }

    static func buildEither<First: FLGroup, Second: FLGroup>(
        first group: First
    ) -> FLEitherGroup<First, Second> {
        .first(group)
    }

    static func buildEither<First: FLGroup, Second: FLGroup>(
        second group: Second
    ) -> FLEitherGroup<First, Second> {
        .second(group)
    }
}

@resultBuilder
enum FLNodeBuilder {
    static func buildExpression<Node: FLNode>(_ node: Node) -> Node {
        node
    }

    static func buildExpression<Composite: FLView>(_ composite: Composite) -> FLComposed<Composite> {
        composite.node
    }

    static func buildBlock<Node: FLNode>(_ node: Node) -> Node {
        node
    }

    static func buildOptional<Node: FLNode>(_ node: Node?) -> FLOptional<Node> {
        FLOptional(wrapped: node)
    }

    static func buildEither<First: FLNode, Second: FLNode>(first node: First) -> FLEither<First, Second> {
        .first(node)
    }

    static func buildEither<First: FLNode, Second: FLNode>(second node: Second) -> FLEither<First, Second> {
        .second(node)
    }
}
