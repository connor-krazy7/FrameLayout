import UIKit

// MARK: - Modifiers

public extension FLNodeProviding {
    func tag<Tag: Hashable & Sendable>(_ tag: Tag) -> FLTagged<ProvidedNode, Tag> {
        FLTagged(tag: tag, wrapped: flNode)
    }
}

// MARK: - Node

public struct FLTagged<Wrapped: FLNode, Tag: Hashable & Sendable>: FLNode {
    public typealias Layout = Wrapped.Layout
    public typealias View = FLTaggedView<Wrapped, Tag>

    public let tag: Tag
    public let wrapped: Wrapped

    public var isSpacer: Bool { wrapped.isSpacer }

    public func layout(in context: FLContext) -> Wrapped.Layout {
        wrapped.layout(in: context)
    }
}

// MARK: - FLLayoutEquatable

public extension FLTagged {
    func isLayoutEquivalent(to other: FLTagged<Wrapped, Tag>) -> Bool {
        wrapped.isLayoutEquivalent(to: other.wrapped)
    }

    func hashLayoutIdentity(into hasher: inout Hasher) {
        wrapped.hashLayoutIdentity(into: &hasher)
    }
}

// MARK: - View

public final class FLTaggedView<Wrapped: FLNode, Tag: Hashable & Sendable>: FLStructuralView, FLNodeView {
    public typealias Node = FLTagged<Wrapped, Tag>

    private let wrappedView = Wrapped.View()

    public override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(wrappedView)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    public func update(node: Node, layout: Wrapped.Layout, context: FLRenderContext) {
        context.registry?.registerView(self, withTag: node.tag)

        wrappedView.flSetFrame(CGRect(origin: .zero, size: layout.size), in: context)
        wrappedView.update(node: node.wrapped, layout: layout, context: context)
    }
}
