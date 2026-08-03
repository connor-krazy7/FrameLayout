import UIKit

struct FLColorLayout: FLLayout {
    let size: CGSize
}

struct FLColor: FLNode {
    typealias View = FLColorView

    static var typeIdentifier: String { "color" }

    let color: UIColor

    init(_ color: UIColor) {
        self.color = color
    }

    func layout(in context: FLContext) -> FLColorLayout {
        FLColorLayout(
            size: CGSize(
                width: context.width.resolved(ideal: 0),
                height: context.height.resolved(ideal: 0)
            )
        )
    }

}

final class FLColorView: UIView, FLNodeView {
    typealias Node = FLColor

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func update(node: FLColor, layout: FLColorLayout, context: FLRenderContext) {
        backgroundColor = node.color
    }
}
