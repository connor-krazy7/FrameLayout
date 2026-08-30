import UIKit

// MARK: - Node

public struct FLColor: FLNode {
    public typealias View = FLColorView

    public let color: UIColor

    public init(_ color: UIColor) {
        self.color = color
    }

    public func layout(in context: FLContext) -> FLColorLayout {
        FLColorLayout(
            size: CGSize(
                width: context.width.resolved(ideal: 0),
                height: context.height.resolved(ideal: 0)
            )
        )
    }

}

// MARK: - FLLayoutEquatable

public extension FLColor {
    /// `layout(in:)` reads nothing but the context, so any two colours are layout-equivalent.
    func isLayoutEquivalent(to other: FLColor) -> Bool { true }

    func hashLayoutIdentity(into hasher: inout Hasher) {}
}

// MARK: - Layout

public struct FLColorLayout: FLLayout {
    public let size: CGSize
}

// MARK: - View

public final class FLColorView: UIView, FLNodeView {
    public typealias Node = FLColor

    public override init(frame: CGRect) {
        super.init(frame: frame)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    public func update(node: FLColor, layout: FLColorLayout, context: FLRenderContext) {
        backgroundColor = node.color
    }
}
