import UIKit

public extension FLNodeProviding {
    func environment(_ overrides: FLEnvironmentOverrides) -> FLEnvironmentOverride<ProvidedNode> {
        FLEnvironmentOverride(overrides: overrides, wrapped: flNode)
    }

    func foregroundColor(_ color: UIColor?) -> FLEnvironmentOverride<ProvidedNode> {
        environment(FLEnvironmentOverrides(foregroundColor: color))
    }

    func font(_ font: UIFont?) -> FLEnvironmentOverride<ProvidedNode> {
        environment(FLEnvironmentOverrides(font: font))
    }
}

public extension FLEnvironmentOverride {
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

/// Substitutes environment values for a subtree. Carries values rather than a transform so the node
/// stays `Sendable` and `Hashable`, and so the layout cache can key on it.
public struct FLEnvironmentOverride<Wrapped: FLNode>: FLNode {
    public typealias Layout = Wrapped.Layout
    public typealias View = FLEnvironmentOverrideView<Wrapped>

    public static var typeIdentifier: String { "environment(\(Wrapped.typeIdentifier))" }

    public let overrides: FLEnvironmentOverrides
    public let wrapped: Wrapped

    public func layout(in context: FLContext) -> Wrapped.Layout {
        wrapped.layout(in: context.applying(overrides))
    }
}

public final class FLEnvironmentOverrideView<Wrapped: FLNode>: FLStructuralView, FLNodeView {
    public typealias Node = FLEnvironmentOverride<Wrapped>

    private let wrappedView = Wrapped.View()

    public override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(wrappedView)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    public func update(node: Node, layout: Wrapped.Layout, context: FLRenderContext) {
        wrappedView.flSetFrame(CGRect(origin: .zero, size: layout.size), in: context)
        wrappedView.update(
            node: node.wrapped,
            layout: layout,
            context: context.applying(node.overrides)
        )
    }
}
