import UIKit

@MainActor
protocol FLHosting: UIView {
    var contentSize: CGSize { get }
}

@MainActor
final class FLHostView<Node: FLNode>: UIView, FLHosting {
    let registry = FLViewRegistry()

    private let contentView = Node.View()

    private(set) var contentSize: CGSize = .zero

    private var hasApplied = false

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(contentView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var intrinsicContentSize: CGSize { contentSize }

    func apply(node: Node, layout: Node.Layout, environment: FLEnvironment = .default) {
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
