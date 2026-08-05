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

public protocol FLGroup: Sendable, Hashable {
    associatedtype Views: FLGroupViews where Views.Group == Self

    static var typeIdentifier: String { get }

    var childCount: Int { get }

    func layout(in context: FLContext) -> FLGroupChildren

    func layout(childContexts: ArraySlice<FLContext>) -> FLGroupChildren
}

public extension FLGroup {
    func childContext(_ contexts: ArraySlice<FLContext>, at offset: Int) -> FLContext {
        let index = contexts.startIndex + offset

        return index < contexts.endIndex ? contexts[index] : .unspecified
    }
}

@MainActor
public protocol FLGroupViews: AnyObject {
    associatedtype Group: FLGroup

    init()

    func update(group: Group, children: FLGroupChildren, context: FLRenderContext) -> [UIView]
}
