import UIKit

// MARK: - Modifiers

public extension FLNodeProviding {
    func accessibilityLabel(_ label: String?) -> FLAccessible<ProvidedNode> {
        FLAccessible(label: label, wrapped: flNode)
    }
}

// MARK: - Node

public struct FLAccessible<Wrapped: FLNode>: FLNode {
    public typealias View = FLAccessibleView<Wrapped>

    public static var typeIdentifier: String { "accessible(\(Wrapped.typeIdentifier))" }

    public let label: String?
    public let wrapped: Wrapped

    public var isSpacer: Bool { wrapped.isSpacer }

    public func layout(in context: FLContext) -> FLAccessibleLayout<Wrapped.Layout> {
        FLAccessibleLayout(wrapped: wrapped.layout(in: context))
    }
}

// MARK: - Layout

public struct FLAccessibleLayout<WrappedLayout: FLLayout>: FLLayout {
    public let wrapped: WrappedLayout

    public var size: CGSize { wrapped.size }
}

// MARK: - View

public final class FLAccessibleView<Wrapped: FLNode>: FLStructuralView, FLNodeView {
    public typealias Node = FLAccessible<Wrapped>

    private let wrappedView = Wrapped.View()

    public override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(wrappedView)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    public func update(node: Node, layout: FLAccessibleLayout<Wrapped.Layout>, context: FLRenderContext) {
        let childContext = context.accessibilityLabel(node.label)

        wrappedView.flSetFrame(CGRect(origin: .zero, size: layout.size), in: childContext)
        wrappedView.update(node: node.wrapped, layout: layout.wrapped, context: childContext)
    }
}
