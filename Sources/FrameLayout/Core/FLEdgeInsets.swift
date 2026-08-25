import UIKit

public struct FLEdgeInsets: Sendable, Hashable, WithCustomisable {
    public var top: CGFloat = 0
    public var leading: CGFloat = 0
    public var bottom: CGFloat = 0
    public var trailing: CGFloat = 0

    public init(top: CGFloat = 0, leading: CGFloat = 0, bottom: CGFloat = 0, trailing: CGFloat = 0) {
        self.top = top
        self.leading = leading
        self.bottom = bottom
        self.trailing = trailing
    }

    public static var zero: FLEdgeInsets { FLEdgeInsets() }

    public static func all(_ inset: CGFloat) -> FLEdgeInsets {
        FLEdgeInsets(top: inset, leading: inset, bottom: inset, trailing: inset)
    }

    public static func edges(_ edges: FLEdgeSet, _ inset: CGFloat) -> FLEdgeInsets {
        FLEdgeInsets(
            top: edges.contains(.top) ? inset : 0,
            leading: edges.contains(.leading) ? inset : 0,
            bottom: edges.contains(.bottom) ? inset : 0,
            trailing: edges.contains(.trailing) ? inset : 0
        )
    }

    public var horizontal: CGFloat { leading + trailing }
    public var vertical: CGFloat { top + bottom }

    public func left(in direction: FLLayoutDirection) -> CGFloat {
        direction == .leftToRight ? leading : trailing
    }

    public func adding(_ other: FLEdgeInsets) -> FLEdgeInsets {
        FLEdgeInsets(
            top: top + other.top,
            leading: leading + other.leading,
            bottom: bottom + other.bottom,
            trailing: trailing + other.trailing
        )
    }
}

