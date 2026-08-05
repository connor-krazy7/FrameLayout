import UIKit

public struct FLDisabledLayout<WrappedLayout: FLLayout>: FLLayout {
    public let wrapped: WrappedLayout

    public var size: CGSize { wrapped.size }
}

public struct FLDisabled<Wrapped: FLNode>: FLNode {
    public typealias View = FLDisabledView<Wrapped>

    public static var typeIdentifier: String { "disabled(\(Wrapped.typeIdentifier))" }

    public let isDisabled: Bool
    public let wrapped: Wrapped

    public var isSpacer: Bool { wrapped.isSpacer }

    public func layout(in context: FLContext) -> FLDisabledLayout<Wrapped.Layout> {
        FLDisabledLayout(wrapped: wrapped.layout(in: context))
    }
}

public final class FLDisabledView<Wrapped: FLNode>: FLStructuralView, FLNodeView {
    public typealias Node = FLDisabled<Wrapped>

    private let wrappedView = Wrapped.View()

    public override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(wrappedView)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    public func update(node: Node, layout: FLDisabledLayout<Wrapped.Layout>, context: FLRenderContext) {
        let childContext = context.disabled(node.isDisabled)

        wrappedView.flSetFrame(CGRect(origin: .zero, size: layout.size), in: childContext)
        wrappedView.update(node: node.wrapped, layout: layout.wrapped, context: childContext)
    }
}

public extension FLNodeProviding {
    func disabled(_ isDisabled: Bool = true) -> FLDisabled<ProvidedNode> {
        FLDisabled(isDisabled: isDisabled, wrapped: flNode)
    }
}
