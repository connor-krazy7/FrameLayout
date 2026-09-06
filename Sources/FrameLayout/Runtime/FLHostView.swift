import UIKit

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

    /// Applies a precomputed layout. A host sized by its `intrinsicContentSize` — a cell, or anything
    /// constraint-driven — only reaches the new size on the next layout pass, so this asks the superview
    /// for one. A host left at a stale size fails silently: nothing clips it, so the content still draws
    /// while UIKit rejects every touch that falls outside the host's own bounds.
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
        let resized = contentSize != layout.size

        registry.removeAll()
        contentSize = layout.size
        contentView.frame = CGRect(origin: .zero, size: layout.size)
        contentView.update(
            node: node,
            layout: layout,
            context: FLRenderContext(environment: environment, registry: registry)
        )

        guard resized else { return }

        invalidateIntrinsicContentSize()
        superview?.setNeedsLayout()
    }

}
