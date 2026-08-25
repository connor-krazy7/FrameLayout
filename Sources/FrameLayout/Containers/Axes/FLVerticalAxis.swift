import UIKit

public enum FLVerticalAxis: FLStackAxis {
    public typealias Alignment = FLHorizontalAlignment

    public static var typeToken: String { "vstack" }
    public static var defaultAlignment: FLHorizontalAlignment { .center }
    public static var distributesAlongAxis: Bool { true }

    public static func extent(of size: CGSize) -> CGFloat { size.height }
    public static func proposal(in context: FLContext) -> FLProposal { context.height }

    public static func childContext(_ context: FLContext, extent: FLProposal) -> FLContext {
        context.proposing(width: context.width, height: extent)
    }

    public static func resolve(
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

extension FLVerticalAxis: FLGridAxis {
    public static var gridToken: String { "vgrid" }

    public static func flowExtent(of size: CGSize) -> CGFloat { size.height }
    public static func crossExtent(of size: CGSize) -> CGFloat { size.width }
    public static func crossProposal(in context: FLContext) -> FLProposal { context.width }
    public static func size(flow: CGFloat, cross: CGFloat) -> CGSize { CGSize(width: cross, height: flow) }
    public static func origin(flow: CGFloat, cross: CGFloat) -> CGPoint { CGPoint(x: cross, y: flow) }

    public static func childContext(_ context: FLContext, cross: CGFloat) -> FLContext {
        context.proposing(width: .exact(cross), height: .unspecified)
    }
}
