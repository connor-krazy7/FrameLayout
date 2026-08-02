import UIKit

struct FLDisabledLayout<WrappedLayout: FLLayout>: FLLayout {
    let wrapped: WrappedLayout

    var size: CGSize { wrapped.size }
}

struct FLDisabled<Wrapped: FLNode>: FLNode {
    typealias View = FLDisabledView<Wrapped>

    static var typeIdentifier: String { "disabled(\(Wrapped.typeIdentifier))" }

    let isDisabled: Bool
    let wrapped: Wrapped

    var isSpacer: Bool { wrapped.isSpacer }

    func layout(in context: FLContext) -> FLDisabledLayout<Wrapped.Layout> {
        FLDisabledLayout(wrapped: wrapped.layout(in: context))
    }
}

final class FLDisabledView<Wrapped: FLNode>: FLStructuralView, FLNodeView {
    typealias Node = FLDisabled<Wrapped>

    private let wrappedView = Wrapped.View()

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(wrappedView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func update(node: Node, layout: FLDisabledLayout<Wrapped.Layout>, context: FLRenderContext) {
        let childContext = context.disabled(node.isDisabled)

        wrappedView.flSetFrame(CGRect(origin: .zero, size: layout.size), in: childContext)
        wrappedView.update(node: node.wrapped, layout: layout.wrapped, context: childContext)
    }
}

extension FLNodeProviding {
    func disabled(_ isDisabled: Bool = true) -> FLDisabled<ProvidedNode> {
        FLDisabled(isDisabled: isDisabled, wrapped: flNode)
    }
}
