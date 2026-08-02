import UIKit

enum FLEitherLayout<First: FLLayout, Second: FLLayout>: FLLayout {
    case first(First)
    case second(Second)

    var size: CGSize {
        switch self {
        case let .first(layout): layout.size
        case let .second(layout): layout.size
        }
    }
}

enum FLEither<First: FLNode, Second: FLNode>: FLNode {
    typealias Layout = FLEitherLayout<First.Layout, Second.Layout>
    typealias View = FLEitherView<First, Second>

    case first(First)
    case second(Second)

    static var typeIdentifier: String {
        "either(\(First.typeIdentifier),\(Second.typeIdentifier))"
    }


    var isSpacer: Bool {
        switch self {
        case let .first(node): node.isSpacer
        case let .second(node): node.isSpacer
        }
    }

    func layout(in context: FLContext) -> Layout {
        switch self {
        case let .first(node): .first(node.layout(in: context))
        case let .second(node): .second(node.layout(in: context))
        }
    }
}

struct FLOptionalLayout<WrappedLayout: FLLayout>: FLLayout {
    let wrapped: WrappedLayout?

    var size: CGSize { wrapped.map(\.size).or(.zero) }
}

struct FLOptional<Wrapped: FLNode>: FLNode {
    typealias View = FLOptionalView<Wrapped>

    static var typeIdentifier: String { "optional(\(Wrapped.typeIdentifier))" }

    let wrapped: Wrapped?

    var isSpacer: Bool { wrapped.map(\.isSpacer).or(false) }

    func layout(in context: FLContext) -> FLOptionalLayout<Wrapped.Layout> {
        FLOptionalLayout(wrapped: wrapped.map { $0.layout(in: context) })
    }
}

final class FLEitherView<First: FLNode, Second: FLNode>: FLStructuralView, FLNodeView {
    typealias Node = FLEither<First, Second>

    private var firstView: First.View?
    private var secondView: Second.View?

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func update(node: Node, layout: Node.Layout, context: FLRenderContext) {
        switch (node, layout) {
        case let (.first(childNode), .first(childLayout)):
            secondView?.removeFromSuperview()

            let view = attachedFirstView()
            view.flSetFrame(CGRect(origin: .zero, size: childLayout.size), in: context)
            view.update(node: childNode, layout: childLayout, context: context)

        case let (.second(childNode), .second(childLayout)):
            firstView?.removeFromSuperview()

            let view = attachedSecondView()
            view.flSetFrame(CGRect(origin: .zero, size: childLayout.size), in: context)
            view.update(node: childNode, layout: childLayout, context: context)

        case (.first, .second), (.second, .first):
            break
        }
    }

    private func attachedFirstView() -> First.View {
        let view = firstView.or(First.View())
        firstView = view
        attach(view)

        return view
    }

    private func attachedSecondView() -> Second.View {
        let view = secondView.or(Second.View())
        secondView = view
        attach(view)

        return view
    }

    private func attach(_ view: UIView) {
        guard view.superview !== self else { return }

        addSubview(view)
    }
}

final class FLOptionalView<Wrapped: FLNode>: FLStructuralView, FLNodeView {
    typealias Node = FLOptional<Wrapped>

    private var wrappedView: Wrapped.View?

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func update(node: FLOptional<Wrapped>, layout: FLOptionalLayout<Wrapped.Layout>, context: FLRenderContext) {
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
