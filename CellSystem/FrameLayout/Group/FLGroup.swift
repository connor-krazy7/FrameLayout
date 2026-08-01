import UIKit

protocol FLGroupLayout: Sendable, Equatable {
    var childSizes: [CGSize] { get }
    var childIsSpacer: [Bool] { get }
    var childIsEmpty: [Bool] { get }
}

protocol FLGroup: Sendable, Hashable {
    associatedtype Layout: FLGroupLayout
    associatedtype Views: FLGroupViews where Views.Group == Self

    static var typeIdentifier: String { get }

    func layout(in context: FLContext) -> Layout

    /// Lays out each child in its own context, by index. This is the placement half of the two-phase
    /// split: a container measures once to learn ideals, then re-proposes per child.
    func layout(childContexts: [FLContext]) -> Layout
}

@MainActor
protocol FLGroupViews: AnyObject {
    associatedtype Group: FLGroup

    init()

    func update(group: Group, layout: Group.Layout, context: FLRenderContext) -> [UIView]
}
