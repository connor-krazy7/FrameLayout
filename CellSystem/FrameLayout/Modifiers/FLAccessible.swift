import UIKit

struct FLAccessibleLayout<WrappedLayout: FLLayout>: FLLayout {
    let wrapped: WrappedLayout

    var size: CGSize { wrapped.size }
}

struct FLAccessible<Wrapped: FLNode>: FLNode {
    typealias View = FLAccessibleView<Wrapped>

    static var typeIdentifier: String { "accessible(\(Wrapped.typeIdentifier))" }

    let label: String?
    let wrapped: Wrapped

    var isSpacer: Bool { wrapped.isSpacer }

    func layout(in context: FLContext) -> FLAccessibleLayout<Wrapped.Layout> {
        FLAccessibleLayout(wrapped: wrapped.layout(in: context))
    }
}

final class FLAccessibleView<Wrapped: FLNode>: FLStructuralView, FLNodeView {
    typealias Node = FLAccessible<Wrapped>

    private let wrappedView = Wrapped.View()

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(wrappedView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func update(node: Node, layout: FLAccessibleLayout<Wrapped.Layout>, context: FLRenderContext) {
        let childContext = context.accessibilityLabel(node.label)

        wrappedView.flSetFrame(CGRect(origin: .zero, size: layout.size), in: childContext)
        wrappedView.update(node: node.wrapped, layout: layout.wrapped, context: childContext)
    }
}

extension FLNode {
    func accessibilityLabel(_ label: String?) -> FLAccessible<Self> {
        FLAccessible(label: label, wrapped: self)
    }
}
