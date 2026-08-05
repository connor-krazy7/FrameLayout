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

public struct FLComposed<Composite: FLView>: FLNode {
    public typealias Layout = Composite.Body.Layout
    public typealias View = FLComposedView<Composite>

    public static var typeIdentifier: String { String(reflecting: Composite.self) }

    public let composite: Composite

    // Built once here rather than on every access. A layout pass can measure the same node several
    // times — a stack that has to redistribute measures three times — and each of those would
    // otherwise rebuild the whole body tree.
    public let body: Composite.Body

    public init(_ composite: Composite) {
        self.composite = composite
        body = composite.body
    }

    public func layout(in context: FLContext) -> Composite.Body.Layout {
        body.layout(in: context)
    }
}

public extension FLComposed {
    // `body` is a pure function of `composite`, so comparing it would be redundant work. This also
    // keeps the layout-cache key down to the composite's own stored properties.
    static func == (lhs: FLComposed<Composite>, rhs: FLComposed<Composite>) -> Bool {
        lhs.composite == rhs.composite
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(composite)
    }
}

public final class FLComposedView<Composite: FLView>: FLStructuralView, FLNodeView {
    public typealias Node = FLComposed<Composite>

    private let bodyView = Composite.Body.View()

    public override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(bodyView)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    public func update(node: FLComposed<Composite>, layout: Composite.Body.Layout, context: FLRenderContext) {
        bodyView.flSetFrame(CGRect(origin: .zero, size: layout.size), in: context)
        bodyView.update(node: node.body, layout: layout, context: context)
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
