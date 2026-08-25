import UIKit

public struct FLAlignment: Sendable, Hashable {
    public var horizontal: FLHorizontalAlignment
    public var vertical: FLVerticalAlignment

    public init(horizontal: FLHorizontalAlignment, vertical: FLVerticalAlignment) {
        self.horizontal = horizontal
        self.vertical = vertical
    }

    public static var topLeading: FLAlignment { FLAlignment(horizontal: .leading, vertical: .top) }
    public static var top: FLAlignment { FLAlignment(horizontal: .center, vertical: .top) }
    public static var topTrailing: FLAlignment { FLAlignment(horizontal: .trailing, vertical: .top) }
    public static var leading: FLAlignment { FLAlignment(horizontal: .leading, vertical: .center) }
    public static var center: FLAlignment { FLAlignment(horizontal: .center, vertical: .center) }
    public static var trailing: FLAlignment { FLAlignment(horizontal: .trailing, vertical: .center) }
    public static var bottomLeading: FLAlignment { FLAlignment(horizontal: .leading, vertical: .bottom) }
    public static var bottom: FLAlignment { FLAlignment(horizontal: .center, vertical: .bottom) }
    public static var bottomTrailing: FLAlignment { FLAlignment(horizontal: .trailing, vertical: .bottom) }

    public func origin(
        childSize: CGSize,
        containerSize: CGSize,
        direction: FLLayoutDirection
    ) -> CGPoint {
        CGPoint(
            x: horizontal.originX(
                childWidth: childSize.width,
                containerWidth: containerSize.width,
                direction: direction
            ),
            y: vertical.originY(
                childHeight: childSize.height,
                containerHeight: containerSize.height
            )
        )
    }
}

