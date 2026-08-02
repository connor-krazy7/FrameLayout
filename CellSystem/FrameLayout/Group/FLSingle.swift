import UIKit

struct FLSingle<Node: FLNode>: FLGroup {
    typealias Views = FLSingleViews<Node>

    static var typeIdentifier: String { Node.typeIdentifier }

    let node: Node

    var childCount: Int { 1 }

    func layout(in context: FLContext) -> FLGroupChildren {
        FLGroupChildren.single(node.layout(in: context), isSpacer: node.isSpacer)
    }

    func layout(childContexts: ArraySlice<FLContext>) -> FLGroupChildren {
        layout(in: childContext(childContexts, at: 0))
    }
}

@MainActor
final class FLSingleViews<Node: FLNode>: FLGroupViews {
    typealias Group = FLSingle<Node>

    private let view = Node.View()

    init() {}

    func update(group: Group, children: FLGroupChildren, context: FLRenderContext) -> [UIView] {
        guard let layout = children.layouts.first?.unwrap(as: Node.Layout.self) else { return [] }

        view.update(node: group.node, layout: layout, context: context)

        return [view]
    }
}
