import UIKit

@MainActor
public protocol FLHosting: UIView {
    var contentSize: CGSize { get }
}

@MainActor
public final class FLHostView<Node: FLNode>: UIView, FLHosting {
    public let registry = FLViewRegistry()

    private let contentView = Node.View()

    public private(set) var contentSize: CGSize = .zero

    private var hasApplied = false

    public override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(contentView)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    public override var intrinsicContentSize: CGSize { contentSize }

    public func apply(node: Node, layout: Node.Layout, environment: FLEnvironment = .default) {
        guard hasApplied else {
            UIView.performWithoutAnimation {
                applyContent(node: node, layout: layout, environment: environment)
            }
            hasApplied = true

            return
        }

        applyContent(node: node, layout: layout, environment: environment)
    }

    private func applyContent(node: Node, layout: Node.Layout, environment: FLEnvironment) {
        registry.removeAll()
        contentSize = layout.size
        contentView.frame = CGRect(origin: .zero, size: layout.size)
        contentView.update(
            node: node,
            layout: layout,
            context: FLRenderContext(environment: environment, registry: registry)
        )
        invalidateIntrinsicContentSize()
    }
}
