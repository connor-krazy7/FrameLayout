import UIKit

public enum FLHorizontalAxis: FLStackAxis {
    public typealias Alignment = FLVerticalAlignment

    public static var defaultAlignment: FLVerticalAlignment { .center }
    public static var distributesAlongAxis: Bool { true }

    public static func extent(of size: CGSize) -> CGFloat { size.width }
    public static func proposal(in context: FLContext) -> FLProposal { context.width }

    public static func childContext(_ context: FLContext, extent: FLProposal) -> FLContext {
        context.proposing(width: extent, height: context.height)
    }

    public static func resolve(
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

extension FLHorizontalAxis: FLGridAxis {
    public static func flowExtent(of size: CGSize) -> CGFloat { size.width }
    public static func crossExtent(of size: CGSize) -> CGFloat { size.height }
    public static func crossProposal(in context: FLContext) -> FLProposal { context.height }
    public static func size(flow: CGFloat, cross: CGFloat) -> CGSize { CGSize(width: flow, height: cross) }
    public static func origin(flow: CGFloat, cross: CGFloat) -> CGPoint { CGPoint(x: flow, y: cross) }

    public static func childContext(_ context: FLContext, cross: CGFloat) -> FLContext {
        context.proposing(width: .unspecified, height: .exact(cross))
    }
}
