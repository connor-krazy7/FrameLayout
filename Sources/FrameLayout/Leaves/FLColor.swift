import UIKit

public struct FLColorLayout: FLLayout {
    public let size: CGSize
}

public struct FLColor: FLNode {
    public typealias View = FLColorView

    public static var typeIdentifier: String { "color" }

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
