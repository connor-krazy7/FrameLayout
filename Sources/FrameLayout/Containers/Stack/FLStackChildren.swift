import UIKit

public struct FLStackChild {
    public let size: CGSize
    public let isSpacer: Bool
}

public struct FLStackChildren {
    public let children: [FLStackChild]
    public let spacing: CGFloat

    public var count: Int { children.count }

    public var spacingTotal: CGFloat { CGFloat(max(0, count - 1)) * spacing }

    public var spacerCount: Int { children.filter(\.isSpacer).count }

    /// Extent taken by children that are not spacers, along the stack axis.
    public func rigidExtent(_ extent: (CGSize) -> CGFloat) -> CGFloat {
        children.reduce(CGFloat(0)) { $1.isSpacer ? $0 : $0 + extent($1.size) }
    }

    /// Extent the spacers insist on at minimum, along the stack axis.
    public func spacerMinimumExtent(_ extent: (CGSize) -> CGFloat) -> CGFloat {
        children.reduce(CGFloat(0)) { $1.isSpacer ? $0 + extent($1.size) : $0 }
    }

    /// Along the stack axis: the container extent, and the extent each spacer absorbs.
    ///
    /// Spacers only absorb leftover space when the axis is bounded. Without a proposal there is no
    /// leftover, so they collapse to their minimum and the stack packs — the same as SwiftUI in an
    /// unbounded context.
    public func resolveAxis(proposal: CGFloat?, extent: (CGSize) -> CGFloat) -> (container: CGFloat, perSpacer: CGFloat?) {
        let rigid = rigidExtent(extent)
        let packed = rigid + spacerMinimumExtent(extent) + spacingTotal

        guard spacerCount > 0, let proposal, proposal > packed else {
            return (packed, nil)
        }

        return (proposal, (proposal - rigid - spacingTotal) / CGFloat(spacerCount))
    }
}

public extension FLGroupChildren {
    var stackChildren: [FLStackChild] {
        sizes.indices.map { index in
            FLStackChild(size: sizes[index], isSpacer: isSpacer[index])
        }
    }
}
