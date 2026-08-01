import UIKit

struct FLStackGeometry: Sendable, Equatable {
    let size: CGSize
    let childFrames: [CGRect]

    static var empty: FLStackGeometry { FLStackGeometry(size: .zero, childFrames: []) }
}

struct FLStackChild {
    let size: CGSize
    let isSpacer: Bool
    let isEmpty: Bool
}

struct FLStackChildren {
    let children: [FLStackChild]
    let spacing: CGFloat

    var count: Int { children.count }

    /// Spacing is only spent between children that are actually there, so an `if` that produced
    /// nothing does not leave a gap behind.
    var spacingTotal: CGFloat {
        CGFloat(max(0, children.filter { !$0.isEmpty }.count - 1)) * spacing
    }

    var spacerCount: Int { children.filter(\.isSpacer).count }

    /// Extent taken by children that are not spacers, along the stack axis.
    func rigidExtent(_ extent: (CGSize) -> CGFloat) -> CGFloat {
        children.reduce(CGFloat(0)) { $1.isSpacer ? $0 : $0 + extent($1.size) }
    }

    /// Extent the spacers insist on at minimum, along the stack axis.
    func spacerMinimumExtent(_ extent: (CGSize) -> CGFloat) -> CGFloat {
        children.reduce(CGFloat(0)) { $1.isSpacer ? $0 + extent($1.size) : $0 }
    }

    /// Along the stack axis: the container extent, and the extent each spacer absorbs.
    ///
    /// Spacers only absorb leftover space when the axis is bounded. Without a proposal there is no
    /// leftover, so they collapse to their minimum and the stack packs — the same as SwiftUI in an
    /// unbounded context.
    func resolveAxis(proposal: CGFloat?, extent: (CGSize) -> CGFloat) -> (container: CGFloat, perSpacer: CGFloat?) {
        let rigid = rigidExtent(extent)
        let packed = rigid + spacerMinimumExtent(extent) + spacingTotal

        guard spacerCount > 0, let proposal, proposal > packed else {
            return (packed, nil)
        }

        return (proposal, (proposal - rigid - spacingTotal) / CGFloat(spacerCount))
    }
}

/// Divides a bounded extent among children that cannot all have their ideal size.
enum FLStackAllocation {
    static func extents(
        ideals: [CGFloat],
        minimums: [CGFloat],
        isSpacer: [Bool],
        available: CGFloat,
        spacingTotal: CGFloat
    ) -> [CGFloat] {
        let budget = max(0, available - spacingTotal)
        let totalMinimum = minimums.reduce(0, +)

        guard budget > totalMinimum else { return minimums }

        // A spacer never competes for space during a shrink — it holds at its minimum and lets the
        // real content keep what is left.
        let flexibility = ideals.indices.map { index in
            isSpacer[index] ? 0 : max(0, ideals[index] - minimums[index])
        }
        let totalFlexibility = flexibility.reduce(0, +)

        guard totalFlexibility > 0 else { return minimums }

        let slack = budget - totalMinimum

        return ideals.indices.map { index in
            minimums[index] + slack * (flexibility[index] / totalFlexibility)
        }
    }
}

extension FLGroupLayout {
    var stackChildren: [FLStackChild] {
        childSizes.indices.map { index in
            FLStackChild(
                size: childSizes[index],
                isSpacer: childIsSpacer[index],
                isEmpty: childIsEmpty[index]
            )
        }
    }
}

protocol FLStackAxis: Sendable {
    associatedtype Alignment: Sendable, Hashable

    static var typeToken: String { get }
    static var defaultAlignment: Alignment { get }

    /// Whether children compete for a bounded extent along this axis. False for Z, where they overlay.
    static var distributesAlongAxis: Bool { get }

    static func extent(of size: CGSize) -> CGFloat
    static func proposal(in context: FLContext) -> FLProposal
    static func childContext(_ context: FLContext, extent: FLProposal) -> FLContext

    static func resolve(
        children: FLStackChildren,
        alignment: Alignment,
        in context: FLContext
    ) -> FLStackGeometry
}

enum FLVerticalAxis: FLStackAxis {
    typealias Alignment = FLHorizontalAlignment

    static var typeToken: String { "vstack" }
    static var defaultAlignment: FLHorizontalAlignment { .center }
    static var distributesAlongAxis: Bool { true }

    static func extent(of size: CGSize) -> CGFloat { size.height }
    static func proposal(in context: FLContext) -> FLProposal { context.height }

    static func childContext(_ context: FLContext, extent: FLProposal) -> FLContext {
        context.proposing(width: context.width, height: extent)
    }

    static func resolve(
        children: FLStackChildren,
        alignment: FLHorizontalAlignment,
        in context: FLContext
    ) -> FLStackGeometry {
        guard children.count > 0 else { return .empty }

        let width = children.children.reduce(CGFloat(0)) { max($0, $1.size.width) }
        let (height, perSpacer) = children.resolveAxis(proposal: context.height.exactValue, extent: \.height)

        var offsetY: CGFloat = 0
        var childFrames: [CGRect] = []
        childFrames.reserveCapacity(children.count)

        for child in children.children {
            guard !child.isEmpty else {
                childFrames.append(.zero)
                continue
            }

            let childSize = child.size
            let childHeight = child.isSpacer
                ? max(childSize.height, perSpacer.or(childSize.height))
                : childSize.height
            let originX = alignment.originX(
                childWidth: childSize.width,
                containerWidth: width,
                direction: context.layoutDirection
            )

            childFrames.append(
                CGRect(x: originX, y: offsetY, width: childSize.width, height: childHeight)
            )
            offsetY += childHeight + children.spacing
        }

        return FLStackGeometry(size: CGSize(width: width, height: height), childFrames: childFrames)
    }
}

enum FLHorizontalAxis: FLStackAxis {
    typealias Alignment = FLVerticalAlignment

    static var typeToken: String { "hstack" }
    static var defaultAlignment: FLVerticalAlignment { .center }
    static var distributesAlongAxis: Bool { true }

    static func extent(of size: CGSize) -> CGFloat { size.width }
    static func proposal(in context: FLContext) -> FLProposal { context.width }

    static func childContext(_ context: FLContext, extent: FLProposal) -> FLContext {
        context.proposing(width: extent, height: context.height)
    }

    static func resolve(
        children: FLStackChildren,
        alignment: FLVerticalAlignment,
        in context: FLContext
    ) -> FLStackGeometry {
        guard children.count > 0 else { return .empty }

        let height = children.children.reduce(CGFloat(0)) { max($0, $1.size.height) }
        let (width, perSpacer) = children.resolveAxis(proposal: context.width.exactValue, extent: \.width)

        var offsetX: CGFloat = 0
        var childFrames: [CGRect] = []
        childFrames.reserveCapacity(children.count)

        for child in children.children {
            guard !child.isEmpty else {
                childFrames.append(.zero)
                continue
            }

            let childSize = child.size
            let childWidth = child.isSpacer
                ? max(childSize.width, perSpacer.or(childSize.width))
                : childSize.width
            let originY = alignment.originY(childHeight: childSize.height, containerHeight: height)
            let resolvedX = if context.layoutDirection == .leftToRight {
                offsetX
            } else {
                width - offsetX - childWidth
            }

            childFrames.append(
                CGRect(x: resolvedX, y: originY, width: childWidth, height: childSize.height)
            )
            offsetX += childWidth + children.spacing
        }

        return FLStackGeometry(size: CGSize(width: width, height: height), childFrames: childFrames)
    }
}

enum FLZAxis: FLStackAxis {
    typealias Alignment = FLAlignment

    static var typeToken: String { "zstack" }
    static var defaultAlignment: FLAlignment { .center }
    static var distributesAlongAxis: Bool { false }

    static func extent(of size: CGSize) -> CGFloat { size.width }
    static func proposal(in context: FLContext) -> FLProposal { .unspecified }

    static func childContext(_ context: FLContext, extent: FLProposal) -> FLContext { context }

    static func resolve(
        children: FLStackChildren,
        alignment: FLAlignment,
        in context: FLContext
    ) -> FLStackGeometry {
        guard children.count > 0 else { return .empty }

        let size = children.children.reduce(CGSize.zero) {
            CGSize(width: Swift.max($0.width, $1.size.width), height: Swift.max($0.height, $1.size.height))
        }
        let childFrames = children.children.map { child in
            CGRect(
                origin: alignment.origin(
                    childSize: child.size,
                    containerSize: size,
                    direction: context.layoutDirection
                ),
                size: child.size
            )
        }

        return FLStackGeometry(size: size, childFrames: childFrames)
    }
}

struct FLStackLayout<GroupLayout: FLGroupLayout>: FLLayout {
    let group: GroupLayout
    let childFrames: [CGRect]
    let size: CGSize
}

struct FLStack<Axis: FLStackAxis, Group: FLGroup>: FLNode {
    typealias View = FLStackView<Axis, Group>

    static var typeIdentifier: String { "\(Axis.typeToken)(\(Group.typeIdentifier))" }

    let alignment: Axis.Alignment
    let spacing: CGFloat
    let group: Group

    init(
        alignment: Axis.Alignment? = nil,
        spacing: CGFloat = 0,
        @FLGroupBuilder content: () -> Group
    ) {
        self.alignment = alignment.or(Axis.defaultAlignment)
        self.spacing = spacing
        group = content()
    }

    func layout(in context: FLContext) -> FLStackLayout<Group.Layout> {
        // Phase one: measure every child at the container's own proposal to learn its ideal.
        let idealLayout = group.layout(in: context)

        // Phase two: only when the ideals do not fit does anyone get re-proposed. The common case
        // costs nothing extra.
        let groupLayout = redistributedLayout(from: idealLayout, in: context).or(idealLayout)

        let geometry = Axis.resolve(
            children: FLStackChildren(children: groupLayout.stackChildren, spacing: spacing),
            alignment: alignment,
            in: context
        )

        return FLStackLayout(
            group: groupLayout,
            childFrames: geometry.childFrames,
            size: geometry.size
        )
    }

    private func redistributedLayout(
        from idealLayout: Group.Layout,
        in context: FLContext
    ) -> Group.Layout? {
        guard Axis.distributesAlongAxis, let available = Axis.proposal(in: context).exactValue else {
            return nil
        }

        let ideals = idealLayout.childSizes.map(Axis.extent(of:))
        let spacingTotal = CGFloat(max(0, ideals.count - 1)) * spacing

        guard ideals.reduce(0, +) + spacingTotal > available else { return nil }

        let minimumLayout = group.layout(
            childContexts: ideals.map { _ in Axis.childContext(context, extent: .minimum) }
        )
        let extents = FLStackAllocation.extents(
            ideals: ideals,
            minimums: minimumLayout.childSizes.map(Axis.extent(of:)),
            isSpacer: idealLayout.childIsSpacer,
            available: available,
            spacingTotal: spacingTotal
        )

        return group.layout(
            childContexts: extents.map { Axis.childContext(context, extent: .exact($0)) }
        )
    }
}

typealias FLVStack<Group: FLGroup> = FLStack<FLVerticalAxis, Group>
typealias FLHStack<Group: FLGroup> = FLStack<FLHorizontalAxis, Group>
typealias FLZStack<Group: FLGroup> = FLStack<FLZAxis, Group>

final class FLStackView<Axis: FLStackAxis, Group: FLGroup>: FLStructuralView, FLNodeView {
    typealias Node = FLStack<Axis, Group>

    private let groupViews = Group.Views()

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func update(node: FLStack<Axis, Group>, layout: FLStackLayout<Group.Layout>, context: FLRenderContext) {
        let childViews = groupViews.update(group: node.group, layout: layout.group, context: context)

        for (childView, childFrame) in zip(childViews, layout.childFrames) {
            if childView.superview !== self {
                addSubview(childView)
            }
            childView.frame = childFrame
        }
    }
}
