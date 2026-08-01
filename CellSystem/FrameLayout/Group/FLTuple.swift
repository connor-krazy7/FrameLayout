import UIKit

struct FLAnyLayout: FLLayout {
    let size: CGSize

    private let base: any FLLayout
    private let isEqual: @Sendable (any FLLayout) -> Bool

    init<Wrapped: FLLayout>(_ layout: Wrapped) {
        size = layout.size
        base = layout
        isEqual = { other in
            guard let other = other as? Wrapped else { return false }
            return other == layout
        }
    }

    func unwrap<Wrapped: FLLayout>(as type: Wrapped.Type) -> Wrapped? {
        base as? Wrapped
    }

    static func == (lhs: FLAnyLayout, rhs: FLAnyLayout) -> Bool {
        lhs.isEqual(rhs.base)
    }
}

struct FLTupleLayout: FLGroupLayout {
    let childLayouts: [FLAnyLayout]
    let childSizes: [CGSize]
    let childIsSpacer: [Bool]
    let childIsEmpty: [Bool]
}

struct FLTuple<each Child: FLNode>: FLGroup {
    typealias Layout = FLTupleLayout
    typealias Views = FLTupleViews<repeat each Child>

    static var typeIdentifier: String {
        var identifiers: [String] = []
        for identifier in repeat (each Child).typeIdentifier {
            identifiers.append(identifier)
        }
        return identifiers.joined(separator: ",")
    }

    let children: (repeat each Child)

    init(_ children: repeat each Child) {
        self.children = (repeat each children)
    }

    func layout(in context: FLContext) -> FLTupleLayout {
        layout { _ in context }
    }

    func layout(childContexts: [FLContext]) -> FLTupleLayout {
        layout { index in
            index < childContexts.count ? childContexts[index] : .unspecified
        }
    }

    private func layout(context: (Int) -> FLContext) -> FLTupleLayout {
        var childLayouts: [FLAnyLayout] = []
        var childSizes: [CGSize] = []
        var childIsSpacer: [Bool] = []
        var childIsEmpty: [Bool] = []
        var index = 0

        for child in repeat each children {
            let childLayout = child.layout(in: context(index))
            childLayouts.append(FLAnyLayout(childLayout))
            childSizes.append(childLayout.size)
            childIsSpacer.append(child.isSpacer)
            childIsEmpty.append(child.isEmpty)
            index += 1
        }

        return FLTupleLayout(
            childLayouts: childLayouts,
            childSizes: childSizes,
            childIsSpacer: childIsSpacer,
            childIsEmpty: childIsEmpty
        )
    }

    static func == (lhs: FLTuple<repeat each Child>, rhs: FLTuple<repeat each Child>) -> Bool {
        var isEqual = true
        for (left, right) in repeat (each lhs.children, each rhs.children) {
            isEqual = isEqual && left == right
        }
        return isEqual
    }

    func hash(into hasher: inout Hasher) {
        for child in repeat each children {
            hasher.combine(child)
        }
    }
}

@MainActor
final class FLTupleViews<each Child: FLNode>: FLGroupViews {
    typealias Group = FLTuple<repeat each Child>

    private let views: (repeat (each Child).View)

    init() {
        views = (repeat (each Child).View())
    }

    func update(group: Group, layout: FLTupleLayout, context: FLRenderContext) -> [UIView] {
        var updatedViews: [UIView] = []
        var index = 0

        for (view, child) in repeat (each views, each group.children) {
            guard index < layout.childLayouts.count else { break }

            Self.apply(view: view, node: child, erased: layout.childLayouts[index], context: context)
            updatedViews.append(view)
            index += 1
        }

        return updatedViews
    }

    private static func apply<Node: FLNode>(
        view: Node.View,
        node: Node,
        erased: FLAnyLayout,
        context: FLRenderContext
    ) {
        guard let childLayout = erased.unwrap(as: Node.Layout.self) else { return }
        view.update(node: node, layout: childLayout, context: context)
    }
}

@resultBuilder
enum FLGroupBuilder {
    static func buildExpression<Node: FLNode>(_ node: Node) -> Node {
        node
    }

    static func buildExpression<Composite: FLView>(_ composite: Composite) -> FLComposed<Composite> {
        composite.node
    }

    static func buildBlock<each Child: FLNode>(
        _ children: repeat each Child
    ) -> FLTuple<repeat each Child> {
        FLTuple(repeat each children)
    }

    static func buildOptional<Child: FLNode>(_ group: FLTuple<Child>?) -> FLOptional<Child> {
        FLOptional(wrapped: group.map(\.children))
    }

    static func buildEither<First: FLNode, Second: FLNode>(
        first group: FLTuple<First>
    ) -> FLEither<First, Second> {
        .first(group.children)
    }

    static func buildEither<First: FLNode, Second: FLNode>(
        second group: FLTuple<Second>
    ) -> FLEither<First, Second> {
        .second(group.children)
    }

    static func buildEither<First: FLNode, Second: FLNode>(first node: First) -> FLEither<First, Second> {
        .first(node)
    }

    static func buildEither<First: FLNode, Second: FLNode>(second node: Second) -> FLEither<First, Second> {
        .second(node)
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
