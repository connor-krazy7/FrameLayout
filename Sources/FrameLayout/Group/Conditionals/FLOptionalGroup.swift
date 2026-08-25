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
