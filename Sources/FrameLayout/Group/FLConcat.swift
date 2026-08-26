import UIKit

// MARK: - Group

public struct FLConcat<each Child: FLGroup>: FLGroup {
    public typealias Views = FLConcatViews<repeat each Child>

    public let groups: (repeat each Child)

    public init(_ groups: repeat each Child) {
        self.groups = (repeat each groups)
    }

    public var childCount: Int {
        var total = 0

        for group in repeat each groups {
            total += group.childCount
        }

        return total
    }

    public func layout(in context: FLContext) -> FLGroupChildren {
        var children = FLGroupChildren.empty

        for group in repeat each groups {
            children = children + group.layout(in: context)
        }

        return children
    }

    public func layout(childContexts: ArraySlice<FLContext>) -> FLGroupChildren {
        var children = FLGroupChildren.empty
        var cursor = childContexts.startIndex

        for group in repeat each groups {
            let end = Swift.min(cursor + group.childCount, childContexts.endIndex)
            children = children + group.layout(childContexts: childContexts[cursor..<end])
            cursor = end
        }

        return children
    }

    public static func == (lhs: FLConcat<repeat each Child>, rhs: FLConcat<repeat each Child>) -> Bool {
        var isEqual = true

        for (left, right) in repeat (each lhs.groups, each rhs.groups) {
            isEqual = isEqual && left == right
        }

        return isEqual
    }

    public func hash(into hasher: inout Hasher) {
        for group in repeat each groups {
            hasher.combine(group)
        }
    }
}

// MARK: - Views

@MainActor
public final class FLConcatViews<each Child: FLGroup>: FLGroupViews {
    public typealias Group = FLConcat<repeat each Child>

    private let views: (repeat (each Child).Views)

    public init() {
        views = (repeat (each Child).Views())
    }

    public func update(group: Group, children: FLGroupChildren, context: FLRenderContext) -> [UIView] {
        var updated: [UIView] = []
        var cursor = 0

        for (childViews, childGroup) in repeat (each views, each group.groups) {
            let end = Swift.min(cursor + childGroup.childCount, children.count)

            guard cursor <= end else { break }

            updated += childViews.update(
                group: childGroup,
                children: children.slice(cursor..<end),
                context: context
            )
            cursor = end
        }

        return updated
    }
}
