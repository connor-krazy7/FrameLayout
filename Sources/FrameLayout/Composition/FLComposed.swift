import UIKit

// MARK: - Node

public struct FLComposed<Composite: FLView>: FLNode {
    public typealias Layout = Composite.Body.Layout
    public typealias View = FLComposedView<Composite>

    // The one deliberate override of the `FLNode` default. A consumer's reuse identifier reads
    // better as the composite's own name than as `FLComposed<…>` wrapping it, and the two are in
    // bijection, so naming the composite loses nothing the default guarantees.
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

// MARK: - Hashable

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

// MARK: - FLLayoutEquatable

public extension FLComposed {
    func isLayoutEquivalent(to other: FLComposed<Composite>) -> Bool {
        composite.isLayoutEquivalent(to: other.composite)
    }

    func hashLayoutIdentity(into hasher: inout Hasher) {
        composite.hashLayoutIdentity(into: &hasher)
    }
}

// MARK: - View

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
