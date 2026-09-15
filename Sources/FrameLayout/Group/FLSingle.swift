import UIKit

// MARK: - Group

public struct FLSingle<Node: FLNode>: FLGroup {
    public typealias Views = FLSingleViews<Node>

    public let node: Node

    public var childCount: Int { node.isAbsent ? 0 : 1 }

    public func layout(in context: FLContext) -> FLGroupChildren {
        guard !node.isAbsent else { return .empty }

        return FLGroupChildren.single(node.layout(in: context), isSpacer: node.isSpacer)
    }

    public func layout(childContexts: ArraySlice<FLContext>) -> FLGroupChildren {
        layout(in: childContext(childContexts, at: 0))
    }
}

// MARK: - Views

@MainActor
public final class FLSingleViews<Node: FLNode>: FLGroupViews {
    public typealias Group = FLSingle<Node>

    private let view = Node.View()

    public init() {}

    public func update(group: Group, children: FLGroupChildren, context: FLRenderContext) -> [UIView] {
        // A group that contributes no child is not handed a frame by its container, so nothing else
        // would take the view back off screen when the node becomes empty.
        guard let layout = children.layouts.first?.unwrap(as: Node.Layout.self) else {
            view.removeFromSuperview()

            return []
        }

        view.update(node: group.node, layout: layout, context: context)

        return [view]
    }
}
