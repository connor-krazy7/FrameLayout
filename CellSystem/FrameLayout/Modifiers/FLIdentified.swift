import UIKit

struct FLIdentifiedLayout<WrappedLayout: FLLayout>: FLLayout {
    let wrapped: WrappedLayout

    var size: CGSize { wrapped.size }
}

struct FLIdentified<Wrapped: FLNode, ID: Hashable & Sendable>: FLNode {
    typealias View = FLIdentifiedView<Wrapped, ID>

    static var typeIdentifier: String { "id(\(Wrapped.typeIdentifier))" }

    let id: ID
    let wrapped: Wrapped

    var isEmpty: Bool { wrapped.isEmpty }
    var isSpacer: Bool { wrapped.isSpacer }

    func layout(in context: FLContext) -> FLIdentifiedLayout<Wrapped.Layout> {
        FLIdentifiedLayout(wrapped: wrapped.layout(in: context))
    }
}

final class FLIdentifiedView<Wrapped: FLNode, ID: Hashable & Sendable>: FLStructuralView, FLNodeView {
    typealias Node = FLIdentified<Wrapped, ID>

    private let wrappedView = Wrapped.View()

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(wrappedView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func update(node: Node, layout: FLIdentifiedLayout<Wrapped.Layout>, context: FLRenderContext) {
        context.registry?.register(self, as: node.id)

        wrappedView.flSetFrame(CGRect(origin: .zero, size: layout.size), in: context)
        wrappedView.update(node: node.wrapped, layout: layout.wrapped, context: context)
    }
}

extension FLNode {
    func id<ID: Hashable & Sendable>(_ id: ID) -> FLIdentified<Self, ID> {
        FLIdentified(id: id, wrapped: self)
    }
}
