import UIKit

public struct FLGroupChildren: Sendable, Equatable {
    public var layouts: [FLAnyLayout]
    public var sizes: [CGSize]
    public var isSpacer: [Bool]

    public static var empty: FLGroupChildren {
        FLGroupChildren(layouts: [], sizes: [], isSpacer: [])
    }

    public var count: Int { sizes.count }

    public static func single(_ layout: some FLLayout, isSpacer: Bool) -> FLGroupChildren {
        FLGroupChildren(layouts: [FLAnyLayout(layout)], sizes: [layout.size], isSpacer: [isSpacer])
    }

    public static func + (lhs: FLGroupChildren, rhs: FLGroupChildren) -> FLGroupChildren {
        FLGroupChildren(
            layouts: lhs.layouts + rhs.layouts,
            sizes: lhs.sizes + rhs.sizes,
            isSpacer: lhs.isSpacer + rhs.isSpacer
        )
    }

    public func slice(_ range: Range<Int>) -> FLGroupChildren {
        FLGroupChildren(
            layouts: Array(layouts[range]),
            sizes: Array(sizes[range]),
            isSpacer: Array(isSpacer[range])
        )
    }
}
