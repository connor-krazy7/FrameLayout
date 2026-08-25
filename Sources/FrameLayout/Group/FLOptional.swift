import UIKit

public struct FLOptionalLayout<WrappedLayout: FLLayout>: FLLayout {
    public let wrapped: WrappedLayout?

    public var size: CGSize { wrapped.map(\.size).or(.zero) }
}

public struct FLOptional<Wrapped: FLNode>: FLNode {
    public typealias View = FLOptionalView<Wrapped>

    public static var typeIdentifier: String { "optional(\(Wrapped.typeIdentifier))" }

    public let wrapped: Wrapped?

    public var isSpacer: Bool { wrapped.map(\.isSpacer).or(false) }

    public func layout(in context: FLContext) -> FLOptionalLayout<Wrapped.Layout> {
        FLOptionalLayout(wrapped: wrapped.map { $0.layout(in: context) })
    }
}

public final class FLOptionalView<Wrapped: FLNode>: FLStructuralView, FLNodeView {
    public typealias Node = FLOptional<Wrapped>

    private var wrappedView: Wrapped.View?

    public override init(frame: CGRect) {
        super.init(frame: frame)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    public func update(node: FLOptional<Wrapped>, layout: FLOptionalLayout<Wrapped.Layout>, context: FLRenderContext) {
        guard let childNode = node.wrapped, let childLayout = layout.wrapped else {
            wrappedView?.removeFromSuperview()

            return
        }

        let view = wrappedView.or(Wrapped.View())
        wrappedView = view

        if view.superview !== self {
            addSubview(view)
        }

        view.flSetFrame(CGRect(origin: .zero, size: childLayout.size), in: context)
        view.update(node: childNode, layout: childLayout, context: context)
    }
}
