import UIKit

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
