import UIKit

struct FLTaggedLayout<WrappedLayout: FLLayout>: FLLayout {
    let wrapped: WrappedLayout

    var size: CGSize { wrapped.size }
}

struct FLTagged<Wrapped: FLNode, Tag: Hashable & Sendable>: FLNode {
    typealias View = FLTaggedView<Wrapped, Tag>

    static var typeIdentifier: String { "tag(\(Wrapped.typeIdentifier))" }

    let tag: Tag
    let wrapped: Wrapped

    var isSpacer: Bool { wrapped.isSpacer }

    func layout(in context: FLContext) -> FLTaggedLayout<Wrapped.Layout> {
        FLTaggedLayout(wrapped: wrapped.layout(in: context))
    }
}

final class FLTaggedView<Wrapped: FLNode, Tag: Hashable & Sendable>: FLStructuralView, FLNodeView {
    typealias Node = FLTagged<Wrapped, Tag>

    private let wrappedView = Wrapped.View()

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(wrappedView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func update(node: Node, layout: FLTaggedLayout<Wrapped.Layout>, context: FLRenderContext) {
        context.registry?.registerView(self, withTag: node.tag)

        wrappedView.flSetFrame(CGRect(origin: .zero, size: layout.size), in: context)
        wrappedView.update(node: node.wrapped, layout: layout.wrapped, context: context)
    }
}

extension FLNode {
    func tag<Tag: Hashable & Sendable>(_ tag: Tag) -> FLTagged<Self, Tag> {
        FLTagged(tag: tag, wrapped: self)
    }
}
