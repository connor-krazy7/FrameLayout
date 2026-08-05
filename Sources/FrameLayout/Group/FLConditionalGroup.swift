import UIKit

public struct FLOptionalGroup<Wrapped: FLGroup>: FLGroup {
    public typealias Views = FLOptionalGroupViews<Wrapped>

    public static var typeIdentifier: String { "optional(\(Wrapped.typeIdentifier))" }

    public let wrapped: Wrapped?

    public var childCount: Int { wrapped?.childCount ?? 0 }

    public func layout(in context: FLContext) -> FLGroupChildren {
        wrapped?.layout(in: context) ?? .empty
    }

    public func layout(childContexts: ArraySlice<FLContext>) -> FLGroupChildren {
        wrapped?.layout(childContexts: childContexts) ?? .empty
    }
}

@MainActor
public final class FLOptionalGroupViews<Wrapped: FLGroup>: FLGroupViews {
    public typealias Group = FLOptionalGroup<Wrapped>

    private var wrappedViews: Wrapped.Views?
    private var attached: [UIView] = []

    public init() {}

    public func update(group: Group, children: FLGroupChildren, context: FLRenderContext) -> [UIView] {
        guard let wrapped = group.wrapped else {
            attached.forEach { $0.removeFromSuperview() }
            attached = []

            return []
        }

        let views = wrappedViews.or(Wrapped.Views())
        wrappedViews = views
        attached = views.update(group: wrapped, children: children, context: context)

        return attached
    }
}

public enum FLEitherGroup<First: FLGroup, Second: FLGroup>: FLGroup {
    public typealias Views = FLEitherGroupViews<First, Second>

    case first(First)
    case second(Second)

    public static var typeIdentifier: String {
        "either(\(First.typeIdentifier),\(Second.typeIdentifier))"
    }

    public var childCount: Int {
        switch self {
        case let .first(group): group.childCount
        case let .second(group): group.childCount
        }
    }

    public func layout(in context: FLContext) -> FLGroupChildren {
        switch self {
        case let .first(group): group.layout(in: context)
        case let .second(group): group.layout(in: context)
        }
    }

    public func layout(childContexts: ArraySlice<FLContext>) -> FLGroupChildren {
        switch self {
        case let .first(group): group.layout(childContexts: childContexts)
        case let .second(group): group.layout(childContexts: childContexts)
        }
    }
}

@MainActor
public final class FLEitherGroupViews<First: FLGroup, Second: FLGroup>: FLGroupViews {
    public typealias Group = FLEitherGroup<First, Second>

    private var firstViews: First.Views?
    private var secondViews: Second.Views?
    private var attached: [UIView] = []

    public init() {}

    public func update(group: Group, children: FLGroupChildren, context: FLRenderContext) -> [UIView] {
        attached.forEach { $0.removeFromSuperview() }

        switch group {
        case let .first(branch):
            let views = firstViews.or(First.Views())
            firstViews = views
            attached = views.update(group: branch, children: children, context: context)

        case let .second(branch):
            let views = secondViews.or(Second.Views())
            secondViews = views
            attached = views.update(group: branch, children: children, context: context)
        }

        return attached
    }
}
