import UIKit

/// A node described by composing others, with the composed type hidden behind an opaque `body`.
///
/// Deliberately does **not** refine `FLNode`: satisfying `FLNode`'s associated types through `Body`
/// — itself an `FLNode` — is a circular reference the compiler rejects. `FLComposed` bridges the two.
public protocol FLView: FLNodeProviding, Sendable, Hashable {
    associatedtype Body: FLNode

    @FLNodeBuilder var body: Body { get }
}

public extension FLView {
    var node: FLComposed<Self> { FLComposed(self) }

    var flNode: FLComposed<Self> { node }

    func layout(in context: FLContext) -> Body.Layout {
        body.layout(in: context)
    }
}

public typealias FLHost<Composite: FLView> = FLHostView<FLComposed<Composite>>

public extension FLHostView {
    func apply<Composite: FLView>(
        _ composite: Composite,
        layout: Composite.Body.Layout,
        environment: FLEnvironment = .default
    ) where Node == FLComposed<Composite> {
        apply(node: composite.node, layout: layout, environment: environment)
    }
}
