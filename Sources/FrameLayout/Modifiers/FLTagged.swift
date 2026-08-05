import UIKit

public struct FLTaggedLayout<WrappedLayout: FLLayout>: FLLayout {
    public let wrapped: WrappedLayout

    public var size: CGSize { wrapped.size }
}

public struct FLTagged<Wrapped: FLNode, Tag: Hashable & Sendable>: FLNode {
    public typealias View = FLTaggedView<Wrapped, Tag>

    public static var typeIdentifier: String { "tag(\(Wrapped.typeIdentifier))" }

    public let tag: Tag
    public let wrapped: Wrapped

    public var isSpacer: Bool { wrapped.isSpacer }

    public func layout(in context: FLContext) -> FLTaggedLayout<Wrapped.Layout> {
        FLTaggedLayout(wrapped: wrapped.layout(in: context))
    }
}

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

    public func update(node: Node, layout: FLTaggedLayout<Wrapped.Layout>, context: FLRenderContext) {
        context.registry?.registerView(self, withTag: node.tag)

        wrappedView.flSetFrame(CGRect(origin: .zero, size: layout.size), in: context)
        wrappedView.update(node: node.wrapped, layout: layout.wrapped, context: context)
    }
}

public extension FLNodeProviding {
    func tag<Tag: Hashable & Sendable>(_ tag: Tag) -> FLTagged<ProvidedNode, Tag> {
        FLTagged(tag: tag, wrapped: flNode)
    }
}
