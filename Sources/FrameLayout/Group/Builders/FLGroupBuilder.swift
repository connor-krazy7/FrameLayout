@resultBuilder
public enum FLGroupBuilder {
    public static func buildExpression<Node: FLNode>(_ node: Node) -> FLSingle<Node> {
        FLSingle(node: node)
    }

    public static func buildExpression<Composite: FLView>(_ composite: Composite) -> FLSingle<FLComposed<Composite>> {
        FLSingle(node: composite.node)
    }

    public static func buildExpression<Group: FLGroup>(_ group: Group) -> Group {
        group
    }

    public static func buildBlock<each Child: FLGroup>(
        _ groups: repeat each Child
    ) -> FLConcat<repeat each Child> {
        FLConcat(repeat each groups)
    }

    public static func buildOptional<Wrapped: FLGroup>(_ group: Wrapped?) -> FLOptionalGroup<Wrapped> {
        FLOptionalGroup(wrapped: group)
    }

    public static func buildEither<First: FLGroup, Second: FLGroup>(
        first group: First
    ) -> FLEitherGroup<First, Second> {
        .first(group)
    }

    public static func buildEither<First: FLGroup, Second: FLGroup>(
        second group: Second
    ) -> FLEitherGroup<First, Second> {
        .second(group)
    }
}
