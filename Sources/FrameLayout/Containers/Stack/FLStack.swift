import UIKit

// MARK: - Node

public struct FLStack<Axis: FLStackAxis, Group: FLGroup>: FLNode {
    public typealias View = FLStackView<Axis, Group>

    public let alignment: Axis.Alignment
    public let spacing: CGFloat
    public let group: Group

    public init(
        alignment: Axis.Alignment? = nil,
        spacing: CGFloat = 0,
        @FLGroupBuilder content: () -> Group
    ) {
        self.alignment = alignment.or(Axis.defaultAlignment)
        self.spacing = spacing
        group = content()
    }

    public func layout(in context: FLContext) -> FLStackLayout {
        // Phase one: measure every child at the container's own proposal to learn its ideal.
        let idealChildren = group.layout(in: context)

        // Phase two: only when the ideals do not fit does anyone get re-proposed. The common case
        // costs nothing extra.
        let children = redistributedChildren(from: idealChildren, in: context).or(idealChildren)

        let geometry = Axis.resolve(
            children: FLStackChildren(children: children.stackChildren, spacing: spacing),
            alignment: alignment,
            in: context
        )

        return FLStackLayout(
            children: children,
            childFrames: geometry.childFrames,
            size: geometry.size
        )
    }

    private func redistributedChildren(
        from ideal: FLGroupChildren,
        in context: FLContext
    ) -> FLGroupChildren? {
        guard Axis.distributesAlongAxis, let available = Axis.proposal(in: context).exactValue else {
            return nil
        }

        let ideals = ideal.sizes.map(Axis.extent(of:))
        let spacingTotal = CGFloat(max(0, ideals.count - 1)) * spacing

        guard ideals.reduce(0, +) + spacingTotal > available else { return nil }

        let minimums = group.layout(
            childContexts: ideals.map { _ in Axis.childContext(context, extent: .minimum) }[...]
        )
        let extents = FLStackAllocation.extents(
            ideals: ideals,
            minimums: minimums.sizes.map(Axis.extent(of:)),
            isSpacer: ideal.isSpacer,
            available: available,
            spacingTotal: spacingTotal
        )

        return group.layout(
            childContexts: extents.map { Axis.childContext(context, extent: .exact($0)) }[...]
        )
    }
}

// MARK: - Layout

public struct FLStackLayout: FLLayout {
    public let children: FLGroupChildren
    public let childFrames: [CGRect]
    public let size: CGSize
}

public typealias FLVStack<Group: FLGroup> = FLStack<FLVerticalAxis, Group>
public typealias FLHStack<Group: FLGroup> = FLStack<FLHorizontalAxis, Group>
public typealias FLZStack<Group: FLGroup> = FLStack<FLZAxis, Group>

// MARK: - View

public final class FLStackView<Axis: FLStackAxis, Group: FLGroup>: FLStructuralView, FLNodeView {
    public typealias Node = FLStack<Axis, Group>

    private let groupViews = Group.Views()

    public override init(frame: CGRect) {
        super.init(frame: frame)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    public func update(node: FLStack<Axis, Group>, layout: FLStackLayout, context: FLRenderContext) {
        let childViews = groupViews.update(group: node.group, children: layout.children, context: context)

        for (childView, childFrame) in zip(childViews, layout.childFrames) {
            if childView.superview !== self {
                addSubview(childView)
            }
            childView.flSetFrame(childFrame, in: context)
        }
    }
}
