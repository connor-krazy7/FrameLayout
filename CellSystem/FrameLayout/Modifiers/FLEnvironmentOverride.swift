import UIKit

/// Substitutes environment values for a subtree. Carries values rather than a transform so the node
/// stays `Sendable` and `Hashable`, and so the layout cache can key on it.
struct FLEnvironmentOverride<Wrapped: FLNode>: FLNode {
    typealias Layout = Wrapped.Layout
    typealias View = FLEnvironmentOverrideView<Wrapped>

    static var typeIdentifier: String { "environment(\(Wrapped.typeIdentifier))" }

    let overrides: FLEnvironmentOverrides
    let wrapped: Wrapped

    func layout(in context: FLContext) -> Wrapped.Layout {
        wrapped.layout(in: context.applying(overrides))
    }
}

final class FLEnvironmentOverrideView<Wrapped: FLNode>: FLStructuralView, FLNodeView {
    typealias Node = FLEnvironmentOverride<Wrapped>

    private let wrappedView = Wrapped.View()

    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(wrappedView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func update(node: Node, layout: Wrapped.Layout, context: FLRenderContext) {
        wrappedView.frame = CGRect(origin: .zero, size: layout.size)
        wrappedView.update(
            node: node.wrapped,
            layout: layout,
            context: context.applying(node.overrides)
        )
    }
}

extension FLNode {
    func environment(_ overrides: FLEnvironmentOverrides) -> FLEnvironmentOverride<Self> {
        FLEnvironmentOverride(overrides: overrides, wrapped: self)
    }

    func foregroundColor(_ color: UIColor?) -> FLEnvironmentOverride<Self> {
        environment(FLEnvironmentOverrides(foregroundColor: color))
    }

    func font(_ font: UIFont?) -> FLEnvironmentOverride<Self> {
        environment(FLEnvironmentOverrides(font: font))
    }
}

extension FLEnvironmentOverride {
    // Chained overrides collapse into one node, the same way padding and decoration do.
    func environment(_ other: FLEnvironmentOverrides) -> FLEnvironmentOverride<Wrapped> {
        FLEnvironmentOverride(overrides: overrides.merging(other), wrapped: wrapped)
    }

    func foregroundColor(_ color: UIColor?) -> FLEnvironmentOverride<Wrapped> {
        environment(FLEnvironmentOverrides(foregroundColor: color))
    }

    func font(_ font: UIFont?) -> FLEnvironmentOverride<Wrapped> {
        environment(FLEnvironmentOverrides(font: font))
    }
}
